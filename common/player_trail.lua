require "common.interpolation_functions"

rt.settings.player_trail = {
    glow_radius_factor = 4,
    history_n_samples = 100,

    glow_intensity = 0.0,
    boom_intensity = 0.75
}

--- @class rt.PlayerTrail
rt.PlayerTrail = meta.class("PlayerTrail")

local _glow_shader = rt.Shader("common/player_trail_glow.glsl")

--- @brief
function rt.PlayerTrail:instantiate(player)
    meta.assert(player, rt.Player)

    self._player = player
    self._radius = rt.settings.player.radius

    self._glow_intensity = 0
    self._glow_intensity_motion = rt.SmoothedMotion1D(0)
    self._boom_intensity = 0
    self._boom_intensity_motion = rt.SmoothedMotion1D(0)
    self._trail_intensity = 0

    self._trail = {}
    self._trail_mesh = nil
    self._trail_mesh_data = {}

    -- Pre-allocate reusable structures to avoid GC thrashing every frame
    self._vertex_buffer = {}
    self._vertex_colors = {}
    self._strip_bounds = {}
    self._strip_lens = {}
    self._trail_segment_lights = {}

    self._position_history = {}
    self._color_history = {}
    self._is_enabled_history = {}

    self._cache_normal_x = {}
    self._cache_normal_y = {}
    self._cache_limit = {}

    -- init history
    do
        local px, py = self._player:get_position()
        local hue = self._player:get_hue()
        for _ = 1, rt.settings.player_trail.history_n_samples do
            table.insert(self._position_history, px)
            table.insert(self._position_history, py)

            table.insert(self._color_history, 1)
            table.insert(self._color_history, 1)
            table.insert(self._color_history, 1)

            table.insert(self._is_enabled_history, false)

            table.insert(self._cache_normal_x, 0)
            table.insert(self._cache_normal_y, 0)
            table.insert(self._cache_limit, math.huge)
        end
        self:update(0) -- init trail mesh
    end

    -- boom geometry
    do
        local x_radius = 2.1 * self._radius -- width
        local y_radius = 2 * self._radius   -- stretch
        local y_offset = y_radius - 1.6 * self._radius -- to account for body

        local _boom_shape = function(x)
            return math.sqrt(1 - x^2)
        end

        local data = {{ 0, x_radius, 0, 0, 1, 1, 1, 0 }}
        local n_vertices = 16
        local i = 1
        for v = -1, 1, 2 / (2 * n_vertices) do
            local a = 1
            if i <= n_vertices then
                a = (i - 1) / n_vertices
            elseif i >= n_vertices then
                a = 1 - (i - n_vertices - 1) / n_vertices
            end

            table.insert(data, {
                v * x_radius,
                -1 * _boom_shape(v) * y_radius + y_offset,
                0, 0, 1, 1, 1, a * 2
            })

            i = i + 1
        end

        self._boom_mesh = rt.Mesh(data)
    end

    -- precompute glow texture
    do
        local glow_radius = self._radius * rt.settings.player_trail.glow_radius_factor
        local padding = 10
        local width = 2 * glow_radius + 2 * padding
        local height = width

        love.graphics.push("all")

        love.graphics.reset()
        self._glow_texture = rt.RenderTexture(width, height)
        self._glow_texture:bind()

        love.graphics.push()
        love.graphics.origin()
        _glow_shader:bind()
        love.graphics.rectangle("fill", 0, 0, width, height)
        _glow_shader:unbind()
        love.graphics.pop()

        self._glow_texture:unbind()

        love.graphics.pop()
    end
end

--- @brief
function rt.PlayerTrail:set_glow_intensity(t)
    self._glow_intensity = t
    self._glow_intensity_motion:set_target_value(t)
end

--- @brief
function rt.PlayerTrail:set_boom_intensity(t)
    self._boom_intensity = t
    self._boom_intensity_motion:set_target_value(t)
end

--- @brief
function rt.PlayerTrail:set_trail_intensity(t)
    self._trail_intensity = t
end

--- @brief
function rt.PlayerTrail:set_is_enabled(b)
    self._is_enabled = b
end

--- @brief
function rt.PlayerTrail:update(delta)
    local player = self._player
    do
        local value = math.clamp(player:get_flow(), 0, 1)

        self._glow_intensity = value
        self._glow_intensity_motion:set_target_value(value)

        self._trail_intensity = value

        local boom_value
        if player:get_is_ghost() or player:get_is_disabled() then
            boom_value = 0
        else
            local boom = value * math.min(math.magnitude(player:get_velocity()) / rt.settings.player.boom_intensity_reference_velocity, 1)
            boom_value = rt.InterpolationFunctions.SQUARE_ACCELERATION(boom)
        end

        self._boom_intensity = boom_value
        self._boom_intensity_motion:set_target_value(boom_value)
    end

    self._glow_intensity_motion:update(delta)
    self._boom_intensity_motion:update(delta)

    local px, py = player:get_position()
    local vx, vy = player:get_velocity()

    table.remove(self._position_history, 1)
    table.remove(self._position_history, 1)
    table.insert(self._position_history, px)
    table.insert(self._position_history, py)

    do
        local r, g, b, _ = rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1)
        for x in range(r, g, b) do
            table.remove(self._color_history, 1)
            table.insert(self._color_history, x)
        end
    end

    table.remove(self._is_enabled_history, 1)
    table.insert(self._is_enabled_history, player:get_is_trail_enabled())

    table.remove(self._cache_normal_x, 1)
    table.remove(self._cache_normal_y, 1)
    table.insert(self._cache_normal_x, 0)
    table.insert(self._cache_normal_y, 0)

    table.remove(self._cache_limit, 1)
    table.insert(self._cache_limit, math.huge)

    local n_samples = rt.settings.player_trail.history_n_samples

    local function get_position(history, i)
        return history[i * 2 - 1], history[i * 2]
    end

    -- points stay at the same position once recorded, so computing the
    -- miter joints and normals is only necessary for the second newest point (n_samples - 1)
    local i = n_samples - 1
    local px_previous, py_previous = get_position(self._position_history, i - 1)
    local px_current, py_current = get_position(self._position_history, i)
    local px_next, py_next = get_position(self._position_history, i + 1)

    local dx1, dy1 = math.subtract(px_current, py_current, px_previous, py_previous)
    local d1 = math.magnitude(dx1, dy1)
    local dx2, dy2 = math.subtract(px_next, py_next, px_current, py_current)
    local d2 = math.magnitude(dx2, dy2)

    local nx, ny = 0, 0
    local limit = math.huge

    if d1 > 0 and d2 > 0 then
        local v1x, v1y = math.normalize(dx1, dy1)
        local v2x, v2y = math.normalize(dx2, dy2)
        local n1x, n1y = math.turn_right(v1x, v1y)
        local n2x, n2y = math.turn_right(v2x, v2y)
        local dot = math.dot(n1x, n1y, n2x, n2y)

        if dot < -1 + math.eps then
            nx, ny = n1x, n1y
        else
            local factor = 1.0 / (1.0 + dot)
            local sum_nx, sum_ny = math.add(n1x, n1y, n2x, n2y)
            nx, ny = math.multiply(sum_nx, sum_ny, factor)

            local sin_theta = math.dot(n2x, n2y, v1x, v1y)
            local denom = math.abs(sin_theta * factor)
            if denom > math.eps then
                limit = math.min(d1, d2) / denom
            end
        end
    elseif d1 > 0 then
        local v1x, v1y = math.normalize(dx1, dy1)
        nx, ny = math.turn_right(v1x, v1y)
    elseif d2 > 0 then
        local v2x, v2y = math.normalize(dx2, dy2)
        nx, ny = math.turn_right(v2x, v2y)
    end

    self._cache_normal_x[i] = nx
    self._cache_normal_y[i] = ny
    self._cache_limit[i] = limit

    self:_reformat_trail(delta)
end

--- @brief
function rt.PlayerTrail:draw_below()
    love.graphics.push("all")
    love.graphics.setBlendMode("add", "premultiplied")

    local r, g, b, a = self._player:get_color():unpack()
    if self._trail_mesh ~= nil then
        love.graphics.setColor(r * a, g * a, b * a, a * self._trail_intensity)
        self._trail_mesh:draw()
    end

    love.graphics.pop()
end

--- @brief
function rt.PlayerTrail:draw_above()
    love.graphics.push("all")
    love.graphics.setBlendMode("add")

    local px, py = self._player:get_position()
    local r, g, b, opacity = self._player:get_color():unpack()

    local glow_alpha = self._glow_intensity_motion:get_value() * rt.settings.player_trail.glow_intensity
    if glow_alpha > math.eps then
        local w, h = self._glow_texture:get_size()
        local a = glow_alpha * opacity
        love.graphics.setColor(a * r, a * g, a * b, a)
        love.graphics.draw(self._glow_texture:get_native(), px - 0.5 * w, py - 0.5 * h)
    end

    local boom_alpha = self._boom_intensity_motion:get_value() * rt.settings.player_trail.boom_intensity
    if boom_alpha > math.eps then
        local a = boom_alpha * opacity
        love.graphics.setColor(a * r, a * g, a * b, a)
        love.graphics.push()
        love.graphics.translate(px, py)
        love.graphics.rotate(math.angle(self._player:get_velocity()) + math.pi / 2)
        love.graphics.translate(-px, -py)
        love.graphics.draw(self._boom_mesh:get_native(), px, py)
        love.graphics.pop()
    end

    love.graphics.pop()
end

--- @brief
function rt.PlayerTrail:draw_bloom()
    -- noop
end

--- @brief
function rt.PlayerTrail:clear()
    local px, py = self._player:get_position()
    local vx, vy = self._player:get_velocity()
    local hue = self._player:get_hue()
    for i = 1, rt.settings.player_trail.history_n_samples do
        self._position_history[i * 2 - 1] = px
        self._position_history[i * 2 - 0] = py

        self._color_history[i * 3 - 2] = 0
        self._color_history[i * 3 - 1] = 0
        self._color_history[i * 3 - 0] = 0

        self._is_enabled_history[i] = false

        self._cache_normal_x[i] = 0
        self._cache_normal_y[i] = 0
        self._cache_limit[i] = math.huge
    end

    self:update(0) -- clear trail mesh
end

--- @brief
function rt.PlayerTrail:collect_point_lights(callback)
    -- noop for now
end

--- @brief
function rt.PlayerTrail:_reformat_trail(delta)
    local position_history = self._position_history
    local color_history = self._color_history
    local enabled_history = self._is_enabled_history
    local n_points_history = rt.settings.player_trail.history_n_samples

    local strip_bounds = self._strip_bounds
    local strip_bounds_i = 1
    local strip_start = nil

    for i = 1, n_points_history do
        if enabled_history[i] then
            if not strip_start then
                strip_start = i
            end
        else
            if strip_start then
                local bound = strip_bounds[strip_bounds_i]
                if not bound then
                    bound = {}
                    strip_bounds[strip_bounds_i] = bound
                end

                bound[1], bound[2] = strip_start, i - 1
                strip_bounds_i = strip_bounds_i + 1
                strip_start = nil
            end
        end
    end

    if strip_start then
        local bound = strip_bounds[strip_bounds_i]
        if not bound then
            bound = {}
            strip_bounds[strip_bounds_i] = bound
        end

        bound[1], bound[2] = strip_start, n_points_history
        strip_bounds_i = strip_bounds_i + 1
    end

    for i = strip_bounds_i, #strip_bounds do strip_bounds[i] = nil end

    local function alpha_at(i)
        return 1 - (i - 1) / n_points_history
    end

    local vertex_data = self._trail_mesh_data
    local vertex_buffer = self._vertex_buffer
    local vertex_data_i = 1
    local vb_i = 1

    local player_a = self._player:get_opacity()
    local half_width = self._radius * 0.75

    local width_easing = function(t)
        return rt.InterpolationFunctions.FRACTIONAL_ROOT_ACCELERATION(t, 0.5)
    end

    local function add_vertex(x, y, hue_i, opacity)
        local a = player_a * opacity
        local entry = vertex_data[vertex_data_i]
        if entry == nil then
            entry = {}
            vertex_data[vertex_data_i] = entry
        end


        local r = self._color_history[hue_i * 3 - 2]
        local g = self._color_history[hue_i * 3 - 1]
        local b = self._color_history[hue_i * 3 - 0]
        entry[1], entry[2], entry[3], entry[4], entry[5], entry[6], entry[7], entry[8] = x, y, 0, 0, a * r, a * g, a * b, a
        vertex_data_i = vertex_data_i + 1
    end

    for bound_idx = 1, strip_bounds_i - 1 do
        local bounds = strip_bounds[bound_idx]
        local start_i, end_i = bounds[1], bounds[2]
        local strip_n = end_i - start_i + 1

        if strip_n >= 2 then
            local base_idx = vertex_data_i

            for offset = 0, strip_n - 1 do
                local original_i = start_i + offset
                local px = position_history[original_i * 2 - 1]
                local py = position_history[original_i * 2]
                local opacity = alpha_at(original_i)
                local hue_i = original_i

                local nx, ny = 0, 0
                local width = half_width * width_easing((original_i - 1) / n_points_history)

                if offset == 0 then
                    local nx_pt = position_history[(original_i + 1) * 2 - 1]
                    local ny_pt = position_history[(original_i + 1) * 2]
                    local dx, dy = math.subtract(nx_pt, ny_pt, px, py)
                    local ndx, ndy = math.normalize(dx, dy)
                    nx, ny = math.turn_right(ndx, ndy)
                elseif offset == strip_n - 1 then
                    local px_previous = position_history[(original_i - 1) * 2 - 1]
                    local py_previous = position_history[(original_i - 1) * 2]
                    local dx, dy = math.subtract(px, py, px_previous, py_previous)
                    local ndx, ndy = math.normalize(dx, dy)
                    nx, ny = math.turn_right(ndx, ndy)
                else
                    nx, ny = self._cache_normal_x[original_i], self._cache_normal_y[original_i]
                    local limit_val = self._cache_limit[original_i]
                    if limit_val and width > limit_val then
                        local scale = limit_val / width
                        nx, ny = math.multiply(nx, ny, scale)
                    end
                end

                local ex, ey = math.multiply(nx, ny, width)
                add_vertex(px + ex, py + ey, hue_i, opacity)
                add_vertex(px - ex, py - ey, hue_i, opacity)
            end

            for i = 1, strip_n - 1 do
                local base = base_idx + (i - 1) * 2
                vertex_buffer[vb_i] = base
                vb_i = vb_i + 1
                vertex_buffer[vb_i] = base + 1
                vb_i = vb_i + 1
                vertex_buffer[vb_i] = base + 2
                vb_i = vb_i + 1

                vertex_buffer[vb_i] = base + 1
                vb_i = vb_i + 1
                vertex_buffer[vb_i] = base + 3
                vb_i = vb_i + 1
                vertex_buffer[vb_i] = base + 2
                vb_i = vb_i + 1
            end
        end
    end

    for i = vb_i, #vertex_buffer do vertex_buffer[i] = nil end


    if #vertex_buffer > 0 then
        if self._trail_mesh == nil then
            local max_vertices = n_points_history * 2
            while #vertex_data < max_vertices do
                local fill_x, fill_y = self._player:get_position()
                local r, g, b = self._player:get_color():unpack()
                vertex_data[#vertex_data + 1] = { fill_x, fill_y, 0, 0, r, g, b, 0 }
            end

            self._trail_mesh = rt.Mesh(vertex_data, rt.MeshDrawMode.TRIANGLES)
            self._trail_mesh:set_vertex_map(vertex_buffer)
        else
            self._trail_mesh:replace_data(self._trail_mesh_data)
            self._trail_mesh:set_vertex_map(vertex_buffer)
        end
    end

    --[[
    local lights = self._trail_segment_lights
    local sl_i = 1
    local strip_lens = self._strip_lens

    for bound_idx = 1, strip_bounds_i - 1 do
        local bounds = strip_bounds[bound_idx]
        local start_i, end_i = bounds[1], bounds[2]
        local strip_n = end_i - start_i + 1

        if strip_n >= 2 then
            local n_segments = 6
            local intensity = 0.5
            local total_len = 0

            for offset = 0, strip_n - 2 do
                local orig_i = start_i + offset
                local p1x, p1y = position_history[orig_i * 2 - 1], position_history[orig_i * 2]
                local p2x, p2y = position_history[(orig_i + 1) * 2 - 1], position_history[(orig_i + 1) * 2]
                local d = math.magnitude(p2x - p1x, p2y - p1y)
                strip_lens[offset + 1] = d
                total_len = total_len + d
            end

            if total_len > 0 then
                for i = 1, n_segments - 1 do
                    local t1 = (i - 1) / n_segments
                    local t2 = (i - 0) / n_segments

                    local function get_pt(t)
                        local target_d = t * total_len
                        local cur_d = 0
                        for offset = 0, strip_n - 2 do
                            local d = strip_lens[offset + 1]
                            if cur_d + d >= target_d - 1e-5 then
                                local frac = (d == 0) and 0 or (target_d - cur_d) / d
                                local orig_i = start_i + offset
                                local px = position_history[orig_i * 2 - 1]
                                local py = position_history[orig_i * 2]
                                local nx_pt = position_history[(orig_i + 1) * 2 - 1]
                                local ny_pt = position_history[(orig_i + 1) * 2]
                                return px + (nx_pt - px) * frac, py + (ny_pt - py) * frac
                            end
                            cur_d = cur_d + d
                        end
                        return position_history[end_i * 2 - 1], position_history[end_i * 2]
                    end

                    local x1, y1 = get_pt(t1)
                    local x2, y2 = get_pt(t2)

                    local hue_idx_local = math.ceil(math.mix(1, strip_n, (t1 + t2) / 2))
                    local hue = hue_history[start_i + hue_idx_local - 1]
                    local r, g, b, a = rt.lcha_to_rgba(0.8, 1, hue, 1)

                    local light = lights[sl_i]
                    if not light then light = {}; lights[sl_i] = light end

                    light[1], light[2], light[3], light[4] = x1, y1, x2, y2
                    light[5], light[6], light[7], light[8] = r, g, b, a * intensity * (1 - t1)
                    sl_i = sl_i + 1
                end
            end
        end
    end

    for i = sl_i, #lights do lights[i] = nil end
    ]]
end

--- @brief
function rt.PlayerTrail:collect_segment_lights(callback)
    if self._trail_segment_lights == nil then return end
    if self._trail_intensity > math.eps then
        for _, segment in ipairs(self._trail_segment_lights) do
            callback(segment[1], segment[2], segment[3], segment[4], segment[5], segment[6], segment[7], segment[8])
        end
    end
end