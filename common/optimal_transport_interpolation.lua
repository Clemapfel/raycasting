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

    local symbols = { "1", "2" }
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
    for i in range(1) do
        local current = self._frames[i+0]:get_data()
        local next = self._frames[math.wrap(i + 1, n_frames)]:get_data()

        local before = love.timer.getTime()
        local plan = compute_transport_plan(
            current, next,
            canvas_w, canvas_h,
            _get_pixel
        )
        self._transport_plans[i] = plan
        self._particle_systems[i] = precompute_particle_system(plan, canvas_w, canvas_h)
    end


    self._start = love.timer.getTime()
    self._interpolation = rt.Image(canvas_w, canvas_h, rt.TextureFormat.R32F, table.rep(0, canvas_w * canvas_h))
    self._drawing_canvas = canvas

    self._update = function(self)
        local frame_i = 1
        local t = rt.InterpolationFunctions.SINE_WAVE((love.timer.getTime() - self._start) / 5)
        local from = self._frames[1]:get_data()
        local to = self._frames[2]:get_data()

        local data = self._interpolation:get_data()
        local plan = self._transport_plans[frame_i]
        local field = self._particle_systems[frame_i]
        for y = 1, canvas_h do
            for x = 1, canvas_w do
                local value = interpolate_pixel(from, to, field, x, y, t, canvas_w, canvas_w, _get_pixel)
                _set_pixel(data, x, y, value)
            end
        end
    end
end

--- @brief
function rt.OptimalTransportInterpolation:draw()
    local current_x, current_y = 50, 50
    love.graphics.setColor(1, 1, 1, 1)

    self:_update()
    for frame in values(self._frames) do
        draw_shader:bind()
        love.graphics.scale(3, 3)
        self._drawing_canvas:replace_data(self._interpolation)
        self._drawing_canvas:draw(current_x, current_y)
        draw_shader:unbind()
        current_x = current_x + self._drawing_canvas:get_width()
    end
end

function compute_transport_plan(image1, image2, canvas_w, canvas_h, get_pixel)
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

    -- Extract non-zero pixels and their masses
    local source_pixels = {}
    local target_pixels = {}
    local source_masses = {}
    local target_masses = {}

    -- Collect source pixels
    for y = 1, canvas_h do
        for x = 1, canvas_w do
            local val = get_pixel(image1, x, y)
            if val > 1e-8 then
                table.insert(source_pixels, {x, y})
                table.insert(source_masses, val)
            end
        end
    end

    -- Collect target pixels
    for y = 1, canvas_h do
        for x = 1, canvas_w do
            local val = get_pixel(image2, x, y)
            if val > 1e-8 then
                table.insert(target_pixels, {x, y})
                table.insert(target_masses, val)
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

function precompute_particle_system(transport_plan, canvas_w, canvas_h)
    -- Convert flat index back to 2D coordinates
    local function from_flat(idx)
        local x = ((idx - 1) % canvas_w) + 1
        local y = math.floor((idx - 1) / canvas_w) + 1
        return x, y
    end

    -- Create list of all particles (mass movements)
    local particles = {}

    for source_idx, targets in pairs(transport_plan) do
        local sx, sy = from_flat(source_idx)

        for target_idx, mass in pairs(targets) do
            local tx, ty = from_flat(target_idx)

            table.insert(particles, {
                sx = sx, sy = sy,    -- Source position
                tx = tx, ty = ty,    -- Target position
                mass = mass,         -- Mass amount
                value = nil          -- Will be filled during interpolation
            })
        end
    end

    return particles
end

function interpolate_pixel_particles(image1, image2, particles, x, y, t, canvas_w, canvas_h, get_pixel)
    if t == 0 then
        return get_pixel(image1, x, y)
    elseif t == 1 then
        return get_pixel(image2, x, y)
    end

    local interpolated_value = 0
    local total_weight = 0
    local sigma = 1.5  -- Kernel width

    -- Check contribution from each particle
    for _, particle in ipairs(particles) do
        -- Get particle position at time t
        local px = particle.sx + t * (particle.tx - particle.sx)
        local py = particle.sy + t * (particle.ty - particle.sy)

        -- Distance-based kernel weight
        local dx = px - x
        local dy = py - y
        local dist_sq = dx * dx + dy * dy
        local weight = math.exp(-dist_sq / (2 * sigma * sigma))

        if weight > 1e-6 then
            -- Get source value (cache it if not already cached)
            if not particle.value then
                particle.value = get_pixel(image1, particle.sx, particle.sy)
            end

            local contribution = particle.mass * particle.value * weight
            interpolated_value = interpolated_value + contribution
            total_weight = total_weight + particle.mass * weight
        end
    end

    -- Normalize or fallback
    if total_weight > 1e-8 then
        return interpolated_value / total_weight
    else
        -- Fallback: linear interpolation
        local val1 = get_pixel(image1, x, y)
        local val2 = get_pixel(image2, x, y)
        return (1 - t) * val1 + t * val2
    end
end

interpolate_pixel = interpolate_pixel_particles