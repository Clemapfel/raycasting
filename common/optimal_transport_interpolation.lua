require "common.font"

rt.OptimalTransportInterpolation = meta.class("OptimalTransportInterpolation", rt.Widget)

local compute_transport_plan = nil -- function
local precompute_particle_system = nil
local interpolate_pixel = nil -- function

local draw_shader = nil

--- @class OptimalTransportInterpolation
function rt.OptimalTransportInterpolation:instantiate()
    if draw_shader == nil then
        draw_shader = rt.Shader("common/optimal_transport_interpolation_draw.glsl")
    end

    self._frames = {}

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then draw_shader:recompile() end
    end)
end

--- @brief
function rt.OptimalTransportInterpolation:realize()
    if self:already_realized() then return end

    love.graphics.push("all")
    love.graphics.origin()

    self._frames = {}
    self._batches = {}

    local font = rt.settings.font.default
    local font_size = rt.FontSize.REGULAR
    local native = font:get_native(font_size, rt.FontStyle.REGULAR, true) -- sdf

    local symbols = { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9 }
    self._index_to_symbol = {}

    local max_w, max_h = -math.huge, -math.huge
    for i, symbol in ipairs(symbols) do
        local str = tostring(symbol)
        local batch = love.graphics.newTextBatch(native, str)
        local w, h = batch:getDimensions()
        max_w, max_h = math.max(max_w, w), math.max(max_h, h)
        self._batches[i] = batch
        self._index_to_symbol[i] = symbol
    end

    local padding = 5
    local canvas_w, canvas_h = max_w + 2 * padding, max_h + 2 * padding

    local canvas = rt.RenderTexture(canvas_w, canvas_h, 0, rt.TextureFormat.R32F, true)

    for i, symbol in ipairs(symbols) do
        local batch = self._batches[i]
        local batch_w, batch_h = batch:getDimensions()
        canvas:bind()
        love.graphics.clear()
        love.graphics.draw(batch, 0.5 * canvas_w - 0.5 * batch_w, 0.5 * canvas_h - 0.5 * batch_h)
        canvas:unbind()
        self._frames[i] = canvas:as_image()
    end

    love.graphics.pop("all")

    -- directly access image data in memory
    -- image is R32F, which is a flat float array in memory
    local _set_pixel = function(data, x, y, value)
        local i = (y - 1) * canvas_w + (x - 1)
        ffi.cast("float*", data)[i] = value
    end

    local _get_pixel = function(data, x, y)
        local i = (y - 1) * canvas_w + (x - 1)
        return ffi.cast("float*", data)[i]
    end

    self._transport_plans = {}
    self._particle_systems = {}

    local n_frames = #self._frames
    for i = 1, n_frames do
        local current = self._frames[i+0]:get_data()
        local next = self._frames[math.wrap(i + 1, n_frames)]:get_data()

        local before = love.timer.getTime()
        local plan = compute_transport_plan(
            current, next,
            canvas_w, canvas_h,
            _get_pixel
        )

        local grid, grid_size = precompute_spatial_grid(plan, canvas_w, canvas_h)
        self._transport_plans[i] = {
            plan = plan,
            grid = grid,
            grid_size = grid_size
        }
    end

    self._start = love.timer.getTime()
    self._interpolation = rt.Image(canvas_w, canvas_h, rt.TextureFormat.R32F, table.rep(0, canvas_w * canvas_h))
    self._drawing_canvas = canvas
    self._frame_i = 1
    self._update = function(self)
        local t = rt.InterpolationFunctions.SIGMOID((love.timer.getTime() - self._start)  / (1 / 10), 25)
        local frame_i = self._frame_i
        local from = self._frames[frame_i]:get_data()
        local to = self._frames[math.wrap(frame_i+1, #self._frames)]:get_data()

        local data = self._interpolation:get_data()
        local plan = self._transport_plans[frame_i]
        local field = self._particle_systems[frame_i]
        for y = 1, canvas_h do
            for x = 1, canvas_w do
                local value = interpolate_pixel_grid(from, to, plan.grid, plan.grid_size, x, y, t, canvas_w, canvas_w, _get_pixel)
                _set_pixel(data, x, y, value)
            end
        end

        if t > 1 - 1 / 120 then
            self._start = love.timer.getTime()
            self._frame_i = math.wrap(frame_i + 1, #self._frames)
        end
    end
end

--- @brief
function rt.OptimalTransportInterpolation:draw()
    local current_x, current_y = 50, 50
    love.graphics.setColor(1, 1, 1, 1)

    self:_update()
    draw_shader:bind()
    self._drawing_canvas:replace_data(self._interpolation)
    love.graphics.draw(self._drawing_canvas:get_native(), current_x, current_y, 0, 3, 3, 0.5 * self._drawing_canvas:get_width(), 0.5 * self._drawing_canvas:get_height())
    draw_shader:unbind()
    current_x = current_x + self._drawing_canvas:get_width()
end

function compute_transport_plan(image1, image2, canvas_w, canvas_h, get_pixel)
    -- SDF threshold for inside/outside
    local sdf_threshold = 0.5  -- Adjust as needed (0 for signed SDF, 0.5 for normalized)

    -- Convert 2D coordinates to flat index
    local function to_flat(x, y)
        return (y - 1) * canvas_w + x
    end

    -- Convert flat index back to 2D coordinates
    local function from_flat(idx)
        local x = ((idx - 1) % canvas_w) + 1
        local y = math.floor((idx - 1) / canvas_w) + 1
        return x, y
    end

    -- Compute Euclidean distance between two pixels
    local function distance(x1, y1, x2, y2)
        return math.sqrt((x1 - x2)^2 + (y1 - y2)^2)
    end

    -- Log-sum-exp for numerical stability
    local function logsumexp(arr)
        if #arr == 0 then return -math.huge end
        local max_val = -math.huge
        for i = 1, #arr do
            if arr[i] > max_val then
                max_val = arr[i]
            end
        end
        if max_val == -math.huge then
            return -math.huge
        end
        local sum_exp = 0
        for i = 1, #arr do
            sum_exp = sum_exp + math.exp(arr[i] - max_val)
        end
        return max_val + math.log(sum_exp)
    end

    -- Extract non-zero pixels and their masses using SDF thresholding
    local source_pixels = {}
    local target_pixels = {}
    local source_masses = {}
    local target_masses = {}

    -- Collect source pixels (inside glyph region)
    for y = 1, canvas_h do
        for x = 1, canvas_w do
            local val = get_pixel(image1, x, y)
            local mass = (val < sdf_threshold) and 1 or 0
            if mass > 0 then
                table.insert(source_pixels, {x, y})
                table.insert(source_masses, mass)
            end
        end
    end

    -- Collect target pixels (inside glyph region)
    for y = 1, canvas_h do
        for x = 1, canvas_w do
            local val = get_pixel(image2, x, y)
            local mass = (val < sdf_threshold) and 1 or 0
            if mass > 0 then
                table.insert(target_pixels, {x, y})
                table.insert(target_masses, mass)
            end
        end
    end

    local n_source = #source_pixels
    local n_target = #target_pixels

    if n_source == 0 or n_target == 0 then
        return {} -- No transport possible
    end

    -- Normalize masses to sum to 1
    local source_sum = 0
    local target_sum = 0

    for i = 1, n_source do
        source_sum = source_sum + source_masses[i]
    end
    for i = 1, n_target do
        target_sum = target_sum + target_masses[i]
    end

    for i = 1, n_source do
        source_masses[i] = source_masses[i] / source_sum
    end
    for i = 1, n_target do
        target_masses[i] = target_masses[i] / target_sum
    end

    -- Compute cost matrix (negative for log domain)
    local neg_cost_matrix = {}
    local epsilon = 0.1  -- Regularization parameter

    for i = 1, n_source do
        neg_cost_matrix[i] = {}
        local sx, sy = source_pixels[i][1], source_pixels[i][2]
        for j = 1, n_target do
            local tx, ty = target_pixels[j][1], target_pixels[j][2]
            local cost = distance(sx, sy, tx, ty)
            neg_cost_matrix[i][j] = -cost / epsilon
        end
    end

    -- Log domain Sinkhorn algorithm
    local max_iter = 100
    local tolerance = 2

    -- Initialize log dual variables
    local log_u = {}
    local log_v = {}
    for i = 1, n_source do
        log_u[i] = 0
    end
    for j = 1, n_target do
        log_v[j] = 0
    end

    -- Convert masses to log domain
    local log_source_masses = {}
    local log_target_masses = {}
    for i = 1, n_source do
        log_source_masses[i] = math.log(source_masses[i])
    end
    for j = 1, n_target do
        log_target_masses[j] = math.log(target_masses[j])
    end

    -- Sinkhorn iterations in log domain
    for iter = 1, max_iter do
        local log_u_old = {}
        for i = 1, n_source do
            log_u_old[i] = log_u[i]
        end

        -- Update log_u
        for i = 1, n_source do
            local terms = {}
            for j = 1, n_target do
                table.insert(terms, log_target_masses[j] + log_v[j] + neg_cost_matrix[i][j])
            end
            log_u[i] = log_source_masses[i] - logsumexp(terms)
        end

        -- Update log_v
        for j = 1, n_target do
            local terms = {}
            for i = 1, n_source do
                table.insert(terms, log_source_masses[i] + log_u[i] + neg_cost_matrix[i][j])
            end
            log_v[j] = log_target_masses[j] - logsumexp(terms)
        end

        -- Check convergence
        local max_change = 0
        for i = 1, n_source do
            local change = math.abs(log_u[i] - log_u_old[i])
            if change > max_change then
                max_change = change
            end
        end

        if max_change < tolerance then
            break
        end
    end

    -- Compute transport matrix from log domain
    local transport_plan = {}
    local threshold = 1 / 256

    for i = 1, n_source do
        local sx, sy = source_pixels[i][1], source_pixels[i][2]
        local source_idx = to_flat(sx, sy)

        for j = 1, n_target do
            -- Compute transport mass in log domain then convert back
            local log_mass = log_source_masses[i] + log_target_masses[j] +
                log_u[i] + log_v[j] + neg_cost_matrix[i][j]
            local mass = math.exp(log_mass)

            if mass > threshold then
                local tx, ty = target_pixels[j][1], target_pixels[j][2]
                local target_idx = to_flat(tx, ty)

                if not transport_plan[source_idx] then
                    transport_plan[source_idx] = {}
                end
                transport_plan[source_idx][target_idx] = mass
            end
        end
    end

    return transport_plan
end

function precompute_spatial_grid(transport_plan, canvas_w, canvas_h, grid_size)
    grid_size = grid_size or 4  -- Grid cell size

    -- Convert flat index back to 2D coordinates
    local function from_flat(idx)
        local x = ((idx - 1) % canvas_w) + 1
        local y = math.floor((idx - 1) / canvas_w) + 1
        return x, y
    end

    local grid_w = math.ceil(canvas_w / grid_size)
    local grid_h = math.ceil(canvas_h / grid_size)

    -- Grid of transport entries
    local spatial_grid = {}
    for gy = 1, grid_h do
        spatial_grid[gy] = {}
        for gx = 1, grid_w do
            spatial_grid[gy][gx] = {}
        end
    end

    -- Populate grid with transport entries
    for source_idx, targets in pairs(transport_plan) do
        local sx, sy = from_flat(source_idx)

        for target_idx, mass in pairs(targets) do
            local tx, ty = from_flat(target_idx)

            -- Determine which grid cells this transport affects
            local min_x = math.min(sx, tx)
            local max_x = math.max(sx, tx)
            local min_y = math.min(sy, ty)
            local max_y = math.max(sy, ty)

            local gx1 = math.max(1, math.floor((min_x - 1) / grid_size) + 1)
            local gx2 = math.min(grid_w, math.floor((max_x - 1) / grid_size) + 1)
            local gy1 = math.max(1, math.floor((min_y - 1) / grid_size) + 1)
            local gy2 = math.min(grid_h, math.floor((max_y - 1) / grid_size) + 1)

            -- Add to relevant grid cells
            for gy = gy1, gy2 do
                for gx = gx1, gx2 do
                    table.insert(spatial_grid[gy][gx], {
                        sx = sx, sy = sy, tx = tx, ty = ty, mass = mass
                    })
                end
            end
        end
    end

    return spatial_grid, grid_size
end

-- Fast interpolation using spatial grid
function interpolate_pixel_grid(image1, image2, spatial_grid, grid_size, x, y, t, canvas_w, canvas_h, get_pixel)
    -- Determine which grid cell contains this pixel
    local gx = math.max(1, math.min(math.ceil(canvas_w / grid_size), math.floor((x - 1) / grid_size) + 1))
    local gy = math.max(1, math.min(math.ceil(canvas_h / grid_size), math.floor((y - 1) / grid_size) + 1))

    local interpolated_value = 0
    local total_weight = 0
    local sigma = 1.0

    -- Only check transport entries in nearby grid cells
    for dy = -1, 1 do
        for dx = -1, 1 do
            local check_gx = gx + dx
            local check_gy = gy + dy

            if check_gx >= 1 and check_gx <= #spatial_grid[1] and
                check_gy >= 1 and check_gy <= #spatial_grid then

                local cell = spatial_grid[check_gy][check_gx]

                for _, entry in ipairs(cell) do
                    local sx, sy = entry.sx, entry.sy
                    local tx, ty = entry.tx, entry.ty
                    local mass = entry.mass

                    -- Compute particle position at time t
                    local particle_x = sx + t * (tx - sx)
                    local particle_y = sy + t * (ty - sy)

                    -- Distance-based weight
                    local dist_sq = (particle_x - x)^2 + (particle_y - y)^2
                    local weight = math.exp(-dist_sq / (2 * sigma * sigma))

                    if weight > 1e-6 then
                        local source_value = get_pixel(image1, sx, sy)
                        interpolated_value = interpolated_value + mass * source_value * weight
                        total_weight = total_weight + mass * weight
                    end
                end
            end
        end
    end

    -- Normalize or fallback
    if total_weight > 1e-8 then
        return interpolated_value / total_weight
    else
        -- Fallback: simple linear interpolation
        local val1 = get_pixel(image1, x, y)
        local val2 = get_pixel(image2, x, y)  -- Assuming access to image2
        return (1 - t) * val1 + t * val2
    end
end
