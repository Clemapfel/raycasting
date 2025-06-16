require "common.contour"

rt.settings.overworld.bubble_field = {
    segment_length = 10,
    n_smoothing_iterations = 2,
    wave_deactivation_threshold = 1 / 1000,
    excitation_amplitude = 0.03,
    opacity = 0.4
}

--- @class ow.BubbleField
ow.BubbleField = meta.class("BubbleField")

-- shape mesh data members
local _origin_x_index = 1
local _origin_y_index = 2
local _dx_index = 3
local _dy_index = 4
local _magnitude_index = 5

-- data mesh members
local _scale_index = 1

-- shader
local _outline_shader, _base_shader

--- @brief
function ow.BubbleField:instantiate(object, stage, scene)
    if _base_shader == nil then _base_shader = rt.Shader("overworld/objects/bubble_field.glsl", { MODE = 0 }) end
    if _outline_shader == nil then _outline_shader = rt.Shader("overworld/objects/bubble_field.glsl", { MODE = 1 }) end

    -- collision
    self._scene = scene
    self._world = stage:get_physics_world()
    self._body = object:create_physics_body(self._world)
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)

    self._body:signal_connect("collision_start", function()
        local player = scene:get_player()
        if player:get_is_bubble() == false then
            self:_block_signals()
            player:set_is_bubble(true)

            local x, y = player:get_position()
            self:_excite_wave(x, y, -1) -- inwards
            self._is_active = true
        end
    end)

    self._body:signal_connect("collision_end", function()
        local player = scene:get_player()
        if player:get_is_bubble() == true then
            self:_block_signals()

            -- check if player is actually outside body, in case of exiting one shape of self but entering another
            if self._body:test_point(player:get_physics_body():get_position()) then
                return
            end

            player:set_is_bubble(false)
            local x, y = player:get_position()
            self:_excite_wave(x, y, 1) -- outwards
            self._is_active = true
        end
    end)

    -- contour
    local contour = object:create_contour() -- flat array: {x1, y1, x2, y2, ..., xn, yn}

    local segment_length = rt.settings.overworld.bubble_field.segment_length * rt.get_pixel_scale()

    -- subdivide contour
    local subdivided = {}
    for i = 1, #contour, 2 do
        local x1, y1 = contour[i], contour[i+1]
        local next_i = (i + 2 > #contour) and 1 or i + 2
        local x2, y2 = contour[next_i], contour[next_i+1]
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local n_segments = math.ceil(length / segment_length)
        for s = 0, n_segments - 1 do
            local t = s / n_segments
            local sx = x1 + t * dx
            local sy = y1 + t * dy
            table.insert(subdivided, sx)
            table.insert(subdivided, sy)
        end
    end

    -- laplacian smoothing
    local smoothing_iterations = rt.settings.overworld.bubble_field.n_smoothing_iterations
    local points = subdivided
    for smoothing_i = 1, smoothing_iterations do
        local smoothed = {}
        for j = 1, #points, 2 do
            local prev_j = (j - 2 < 1) and (#points - 1) or (j - 2)
            local next_j = (j + 2 > #points) and 1 or (j + 2)
            local x = (points[prev_j] + points[j] + points[next_j]) / 3
            local y = (points[prev_j+1] + points[j+1] + points[next_j+1]) / 3
            table.insert(smoothed, x)
            table.insert(smoothed, y)
        end
        points = smoothed
    end

    -- connect loops that retracted after smoothing
    points[1] = points[#points - 1]
    points[2] = points[#points - 0]

    -- compute center and mesh data
    self._contour = points
    local center_x, center_y, n = 0, 0, 0
    for i = 1, #points, 2 do
        local x, y = points[i], points[i+1]
        center_x = center_x + x
        center_y = center_y + y
        n = n + 1
    end

    center_x = center_x / n
    center_y = center_y / n

    -- meshes
    self._shape_mesh_data = {} -- constant
    self._data_mesh_data = {} -- uploaded each frame

    local triangulation = rt.DelaunayTriangulation(points, points):get_triangle_vertex_map()

    local shape_mesh_format = {
        { location = 0, name = "origin", format = "floatvec2" }, -- absolute xy
        { location = 1, name = "contour_vector", format = "floatvec3" } -- normalized xy, magnitude
    }

    local data_mesh_format = {
        { location = 2, name = "scale", format = "float" }
    }

    -- construct contour vectors
    local target_magnitude = 100
    for i = 1, #self._contour, 2 do
        local x, y = self._contour[i+0], self._contour[i+1]
        local origin_x, origin_y = center_x, center_y
        local dx = x - origin_x
        local dy = y - origin_y

        -- rescale origin such that each point has same magnitude, while
        -- mainting end point x, y
        dx, dy = math.normalize(dx, dy)
        local magnitude = target_magnitude
        origin_x = x - dx * magnitude
        origin_y = y - dy * magnitude

        table.insert(self._shape_mesh_data, {
            [_origin_x_index] = origin_x,
            [_origin_y_index] = origin_y,
            [_dx_index] = dx,
            [_dy_index] = dy,
            [_magnitude_index] = magnitude
        })

        table.insert(self._data_mesh_data, {
            [_scale_index] = 1
        })
    end
    
    self._contour_center_x, self._contour_center_y = center_x, center_y

    self._shape_mesh = rt.Mesh(
        self._shape_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        shape_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )
    self._shape_mesh:set_vertex_map(triangulation)
    
    self._data_mesh = rt.Mesh(
        self._data_mesh_data,
        rt.MeshDrawMode.POINTS,
        data_mesh_format,
        rt.GraphicsBufferUsage.DYNAMIC
    )

    self._shape_mesh:attach_attribute(self._data_mesh, "scale", "pervertex")

    -- wave equation solver
    self._elapsed = 0
    self._n_points = math.floor(#self._contour / 2)
    self._wave = {
        previous = table.rep(0, self._n_points),
        current = table.rep(0, self._n_points),
        next = {}
    }
end

--- @brief
function ow.BubbleField:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.setLineJoin("none")
    love.graphics.line(self._contour)

    local camera_offset = { self._scene:get_camera():get_offset() }
    local camera_scale = self._scene:get_camera():get_scale()
    local hue = self._scene:get_player():get_hue()

    love.graphics.setColor(1, 1, 1, rt.settings.overworld.bubble_field.opacity)
    _base_shader:bind()
    _base_shader:send("elapsed", self._elapsed)
    _base_shader:send("camera_offset", camera_offset)
    _base_shader:send("camera_scale", camera_scale)
    _base_shader:send("hue", hue)
    love.graphics.draw(self._shape_mesh:get_native())
    _base_shader:unbind()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.setLineJoin("none")
    _outline_shader:bind()
    _outline_shader:send("elapsed", self._elapsed)
    _outline_shader:send("camera_offset", camera_offset)
    _outline_shader:send("camera_scale", camera_scale)
    _outline_shader:send("hue", hue)
    love.graphics.line(self._contour)
    _outline_shader:unbind()
end

--- @brief
function ow.BubbleField:_block_signals()
    -- block signals until next step to avoid infinite loops
    -- because set_is_bubble can teleport and trigger multiple starts
    self._body:signal_set_is_blocked("collision_start", true)
    self._body:signal_set_is_blocked("collision_end", true)

    self._world:signal_connect("step", function()
        self._body:signal_set_is_blocked("collision_start", false)
        self._body:signal_set_is_blocked("collision_end", false)
        return meta.DISCONNECT_SIGNAL
    end)
end

local _dx = 0.2
local _dt = 0.05
local _damping = 0.99
local _courant = _dt / _dx

--- @brief
function ow.BubbleField:_excite_wave(x, y, sign)
    local min_distance, min_i = math.huge, nil
    for i = 1, self._n_points do
        local data = self._shape_mesh_data[i]
        local dx, dy, magnitude = data[_dx_index], data[_dy_index], data[_magnitude_index]
        local vx = self._contour_center_x + dx * magnitude
        local vy = self._contour_center_y + dy * magnitude
        local distance = math.distance(x, y, vx, vy)
        if distance < min_distance then
            min_distance = distance
            min_i = i
        end
    end

    local center_index, amplitude, width = min_i, sign * rt.settings.overworld.bubble_field.excitation_amplitude, 5
    for i = 1, self._n_points do
        local distance = math.abs(i - center_index)
        distance = math.min(distance, self._n_points - distance)
        self._wave.current[i] = self._wave.current[i] + amplitude * math.exp(-((distance / width) ^ 2))
    end

    self._is_active = true
end

--- @brief
function ow.BubbleField:update(delta)
    self._elapsed = self._elapsed + delta

    if self._is_active and not rt.GameState:get_is_performance_mode_enabled() then
        local abs, max, mix2 = math.abs, math.max, math.mix2
        local n_points = self._n_points
        local courant2 = _courant^2
        local damping = _damping
        local wave = self._wave
        local shape_data = self._shape_mesh_data
        local center_x, center_y = self._contour_center_x, self._contour_center_y

        local offset_max = 0
        local prev, curr, nextw = wave.previous, wave.current, wave.next

        for i = 1, n_points do
            local left = (i == 1) and n_points or (i - 1)
            local right = (i == n_points) and 1 or (i + 1)

            local new = 2 * curr[i] - prev[i] + courant2 * (curr[left] - 2 * curr[i] + curr[right])
            new = new * damping
            nextw[i] = new

            local abs_new = abs(new)
            offset_max = max(offset_max, abs_new)

            local data = shape_data[i]
            local dx, dy, magnitude = data[_dx_index], data[_dy_index], data[_magnitude_index]
            local origin_x, origin_y = data[_origin_x_index], data[_origin_y_index]
            local idx = (i - 1) * 2
            local scale = 1 + new
            self._contour[idx + 1] = origin_x + scale * dx * magnitude
            self._contour[idx + 2] = origin_y + scale * dy * magnitude
            self._data_mesh_data[i][_scale_index] = scale
        end

        wave.previous, wave.current, wave.next = wave.current, wave.next, wave.previous
        self._data_mesh:replace_data(self._data_mesh_data)

        if offset_max < rt.settings.overworld.bubble_field.wave_deactivation_threshold then
            self._is_active = false
        end
    end
end

