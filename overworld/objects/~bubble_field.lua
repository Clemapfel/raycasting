rt.settings.overworld.bubble_field = {
    segment_length = 13,
    thickness = 3,
    n_smoothing_iterations = 2,
    alpha = 1,
    wave_deactivation_threshold = 1 / 1000,
    message_tick = 4 / 60,
}

--- @class ow.BubbleField
ow.BubbleField = meta.class("BubbleField")

local _outline_shader, _base_shader

local _vertex_format = {
    { location = 0, name = "VertexPosition", format = "floatvec2" }
}

local _bubblefield_worker_code

--- @brief
function ow.BubbleField:instantiate(object, stage, scene)
    self._scene = scene
    self._world = stage:get_physics_world()
    self._elapsed = 0
    self._hue = 0
    self._is_active = false
    self._should_excite = false
    self._excite_x, self._excite_y, self._excite_sign = 0, 0, 0
    self._message_elapsed = 0
    self._camera_offset = {0, 0}
    self._camera_scale = 1

    if _outline_shader == nil then _outline_shader = rt.Shader("overworld/objects/bubble_field.glsl", { MODE = 1 }) end
    if _base_shader == nil then _base_shader = rt.Shader("overworld/objects/bubble_field.glsl", { MODE = 0 }) end

    -- collision
    self._body = object:create_physics_body(self._world)
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)

    self._thread = love.thread.newThread(_bubblefield_worker_code)
    self._main_to_worker = love.thread.newChannel()
    self._worker_to_main = love.thread.newChannel()

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

    -- calculate contour
    local segments = {}
    local mesh, tris = object:create_mesh()
    for tri in values(tris) do
        for segment in range(
            {tri[1], tri[2], tri[3], tri[4]},
            {tri[3], tri[4], tri[5], tri[6]},
            {tri[1], tri[2], tri[5], tri[6]}
        ) do
            table.insert(segments, segment)
        end
    end

    local _hashed = {}
    local _hash = function(points)
        local x1, y1, x2, y2 = math.floor(points[1]), math.floor(points[2]), math.floor(points[3]), math.floor(points[4])
        if x1 < x2 or (x1 == x2 and y1 < y2) then -- swap so point order does not matter
            x1, y1, x2, y2 = x2, y2, x1, y1
        end
        local hash = tostring(x1) .. "," .. tostring(y1) .. "," .. tostring(x2) .. "," .. tostring(y2)
        _hashed[hash] = { x1, y1, x2, y2 }
        return hash
    end

    local _unhash = function(hash)
        return _hashed[hash]
    end

    local tuples = {}
    local n_total = 0
    for segment in values(segments) do
        local hash = _hash(segment)
        local current = tuples[hash]
        if current == nil then
            tuples[hash] = 1
        else
            tuples[hash] = current + 1
        end
        n_total = n_total + 1
    end

    local contour = {}
    for hash, count in pairs(tuples) do
        if count == 1 then
            local segment = _unhash(hash)
            table.insert(contour, segment)
        end
    end

    -- form continuous path
    local linked_contour = {}
    local current_segment = table.remove(contour, 1)
    table.insert(linked_contour, current_segment)

    local is_equal = function(a, b)
        return math.abs(a - b) == 0
    end

    -- link into connect line
    while #contour > 0 do
        for i, segment in ipairs(contour) do
            if is_equal(current_segment[3], segment[1]) and is_equal(current_segment[4], segment[2]) then
                current_segment = table.remove(contour, i)
                table.insert(linked_contour, current_segment)
                break
            elseif is_equal(current_segment[3], segment[3]) and is_equal(current_segment[4], segment[4]) then
                current_segment = {segment[3], segment[4], segment[1], segment[2]}
                table.remove(contour, i)
                table.insert(linked_contour, current_segment)
                break
            end
        end
    end

    -- subdivide
    local segment_length = rt.settings.overworld.bubble_field.segment_length * rt.get_pixel_scale()
    local subdivided_contour = {}
    for segment in values(linked_contour) do
        local x1, y1, x2, y2 = segment[1], segment[2], segment[3], segment[4]
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local n_segments = math.ceil(length / segment_length)
        local adjusted_length = length / n_segments
        local step_x, step_y = dx / length * adjusted_length, dy / length * adjusted_length

        for i = 0, n_segments - 1 do
            local start_x = x1 + step_x * i
            local start_y = y1 + step_y * i
            local end_x = x1 + step_x * (i + 1)
            local end_y = y1 + step_y * (i + 1)

            table.insert(subdivided_contour, { start_x, start_y, end_x, end_y })
        end
    end

    -- laplacian smooth
    local smoothing_iterations = rt.settings.overworld.bubble_field.n_smoothing_iterations
    for smoothing_i = 1, smoothing_iterations do
        local smoothed = {}
        for i = 1, #subdivided_contour do
            -- Wrap around indices for the loop
            local prev = subdivided_contour[(i - 2) % #subdivided_contour + 1]
            local curr = subdivided_contour[i]
            local next = subdivided_contour[i % #subdivided_contour + 1]

            local smoothed_x1 = (prev[1] + curr[1] + next[1]) / 3
            local smoothed_y1 = (prev[2] + curr[2] + next[2]) / 3
            local smoothed_x2 = (prev[3] + curr[3] + next[3]) / 3
            local smoothed_y2 = (prev[4] + curr[4] + next[4]) / 3

            table.insert(smoothed, { smoothed_x1, smoothed_y1, smoothed_x2, smoothed_y2 })
        end
        subdivided_contour = smoothed
    end

    -- construct filled mesh
    local flat = {}
    for segment in values(subdivided_contour) do
        for x in values(segment) do
            table.insert(flat, x)
        end
    end

    local solid_tris = rt.DelaunayTriangulation(flat, flat):get_triangles()
    if #solid_tris > 0 then
        local solid_data = {}
        for tri in values(solid_tris) do
            for i = 1, 6, 2 do
                table.insert(solid_data, {
                    tri[i+0], tri[i+1]
                })
            end
        end

        self._solid_mesh = rt.Mesh(solid_data, rt.MeshDrawMode.TRIANGLES, _vertex_format):get_native()
        self._solid_backup_mesh = self._solid_mesh
    end

    self._contour = {}
    local center_x, center_y, n = 0, 0, 0
    for segment in values(subdivided_contour) do
        for x in values(segment) do
            table.insert(self._contour, x)
        end

        center_x = center_x + segment[1] + segment[3]
        center_y = center_y + segment[2] + segment[4]
        n = n + 2
    end

    center_x = center_x / n
    center_y = center_y / n

    -- close loop
    for i in range(1, 2) do
        table.insert(self._contour, self._contour[i])
    end

    self._contour_vectors = {}
    for i = 1, #self._contour, 2 do
        local dx = self._contour[i+0] - center_x
        local dy = self._contour[i+1] - center_y
        local magnitude = math.magnitude(dx, dy)
        dx, dy = math.normalize(dx, dy)

        table.insert(self._contour_vectors, {
            dx = dx,
            dy = dy,
            magnitude = magnitude
        })
    end

    self._contour_center_x, self._contour_center_y = center_x, center_y
    self._polygon_positions = self._contour
    self._outline_positions = self._contour

    self._n_points = math.floor(#self._contour / 2)
    self._wave = {
        previous = table.rep(0, self._n_points),
        current = table.rep(0, self._n_points),
        next = {}
    }
end

local _dx = 0.1
local _dt = 0.05
local _damping = 0.99
local _courant = _dt / _dx
local _amplitude = 0.01

local _handler_id = "overworld.bubble_field"
local _pack_message = function(self)
    local out = {
        wave = self._wave,
        n_points = self._n_points,
        contour_vectors = self._contour_vectors,
        contour_center_x = self._contour_center_x,
        contour_center_y = self._contour_center_y,
        polygon_positions = {},
        outline_positions = {},
        mesh_data = nil,
        wave_deactivation_threshold = rt.settings.overworld.bubble_field.wave_deactivation_threshold,
        is_active = true,
        damping = _damping,
        courant = _courant,
        amplitude = _amplitude,
        should_excite = self._should_excite,
        excite_x = self._excite_x,
        excite_y = self._excite_y,
        excite_sign = self._excite_sign
    }

    self._should_excite = false
    return out
end

--- @brief
function ow.BubbleField:update(delta)
    self._hue = self._hue + delta / 20 -- always update so color stays synched across stage

    if not self._scene:get_is_body_visible(self._body) then return end
    self._elapsed = self._elapsed + delta
    self._camera_offset = { self._scene:get_camera():get_offset() }
    self._camera_scale = self._scene:get_camera():get_scale()
    self._message_elapsed = self._message_elapsed + delta

    if self._is_active then
        local messages, n_messages = {}, 0
        while self._worker_to_main:getCount() > 0 do
            table.insert(messages, self._worker_to_main:pop())
            n_messages = n_messages + 1
        end

        -- prioritze excitation
        local to_handle = {}
        for message in values(messages) do
            if message.is_excitation then
                table.insert(to_handle, message)
            end
        end

        if #to_handle == 0 then to_handle = { messages[n_messages] } end

        if n_messages > 0 then
            for data in values(to_handle) do
                if not data.is_excite_sentinel then
                    self._wave = data.wave
                    if data.mesh_data ~= nil then
                        self._solid_mesh = rt.Mesh(data.mesh_data, rt.MeshDrawMode.TRIANGLES, _vertex_format):get_native()
                    end

                    self._is_active = data.is_active
                    self._outline_positions = data.outline_positions
                end
            end
        end

        if not rt.GameState:get_is_performance_mode_enabled() and (self._should_excite or n_messages > 0) then
            self._main_to_worker:push(_pack_message(self))
        end
    end
end

--- @brief
function ow.BubbleField:_excite_wave(player_x, player_y, sign)
    if rt.GameState:get_is_performance_mode_enabled() then return end

    self._is_active = true
    self._should_excite = true
    self._excite_x, self._excite_y = player_x, player_y
    self._excite_sign = sign

    if self._thread:isRunning() == false then
        self._thread:start(self._main_to_worker, self._worker_to_main)
    end
end

--- @brief
function ow.BubbleField:draw()
    if not self._scene:get_is_body_visible(self._body) then return end
    local r, g, b, a = rt.Palette.BUBBLE_FIELD:unpack()

    love.graphics.setColor(r, g, b, 0.8)
    _base_shader:bind()
    _base_shader:send("n_vertices", self._n_points)
    _base_shader:send("elapsed", self._elapsed)
    _base_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _base_shader:send("camera_scale", self._scene:get_camera():get_scale())
    _base_shader:send("hue", self._hue)
    if self._solid_mesh ~= nil then
        love.graphics.setWireframe(true)
        love.graphics.draw(self._solid_mesh)
    elseif self._solid_backup_mesh ~= nil then -- use backup if love.math fails to triangulate
        love.graphics.draw(self._solid_backup_mesh)
    end
    _base_shader:unbind()

    love.graphics.setColor(r, g, b, 1)
    love.graphics.setLineWidth(3)
    love.graphics.setLineJoin("none")
    _outline_shader:bind()
    _outline_shader:send("n_vertices", self._n_points)
    _outline_shader:send("elapsed", self._elapsed)
    _outline_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _outline_shader:send("camera_scale", self._scene:get_camera():get_scale())
    _outline_shader:send("hue", self._hue)
    love.graphics.line(self._outline_positions)
    _outline_shader:unbind()
end

--- @brief
function ow.BubbleField:_block_signals()
    -- block signals until next step to avoid infinite loops
    -- because set_is_bubble can teleport
    self._body:signal_set_is_blocked("collision_start", true)
    self._body:signal_set_is_blocked("collision_end", true)

    self._world:signal_connect("step", function()
        self._body:signal_set_is_blocked("collision_start", false)
        self._body:signal_set_is_blocked("collision_end", false)
        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.BubbleField:get_render_priority()
    return -1
end

--_bubblefield_worker_code = -[[
rt = {}

require "common.common"
meta = require "common.meta"
require "love.timer"
require "love.math"
require "common.delaunay_triangulation"

local main_to_worker, worker_to_main = ...

local _handler = function(data)
    -- Localize math functions for speed
    local abs, max, mix2 = math.abs, math.max, math.mix2

    -- Unpack data fields for faster access
    local n_points = data.n_points
    local courant2 = data.courant^2
    local damping = data.damping
    local wave = data.wave
    local contour_vectors = data.contour_vectors
    local center_x, center_y = data.contour_center_x, data.contour_center_y

    -- Reuse or clear polygon_positions and outline_positions arrays
    local polygon_positions = data.polygon_positions
    local outline_positions = data.outline_positions
    for i = 1, #polygon_positions do polygon_positions[i] = nil end
    for i = 1, #outline_positions do outline_positions[i] = nil end

    -- excitation
    if data.should_excite then
        local min_distance, min_i = math.huge, nil
        for i = 1, data.n_points do
            local vector = data.contour_vectors[i]
            local vx = data.contour_center_x + vector.dx * vector.magnitude
            local vy = data.contour_center_y + vector.dy * vector.magnitude
            local distance = math.distance(data.excite_x, data.excite_y, vx, vy)
            if distance < min_distance then
                min_distance = distance
                min_i = i
            end
        end

        local center_index, amplitude, width = min_i, data.excite_sign * data.amplitude, 5
        for i = 1, data.n_points do
            local distance = math.abs(i - center_index)
            distance = math.min(distance, data.n_points - distance)
            data.wave.current[i] = data.wave.current[i] + amplitude * math.exp(-((distance / width) ^ 2))
        end
    end

    -- Wave equation solver
    local offset_sum, offset_max = 0, -math.huge
    local prev, curr, nextw = wave.previous, wave.current, wave.next

    for i = 1, n_points do
        local left = (i == 1) and n_points or (i - 1)
        local right = (i == n_points) and 1 or (i + 1)

        local new = 2 * curr[i] - prev[i] + courant2 * (curr[left] - 2 * curr[i] + curr[right])
        new = new * damping
        nextw[i] = new

        local abs_new = abs(new)
        offset_sum = offset_sum + abs_new
        offset_max = max(offset_max, abs_new)

        local entry = contour_vectors[i]

        local idx = (i - 1) * 2
        polygon_positions[idx + 1] = center_x + entry.dx * (1 + new) * entry.magnitude
        polygon_positions[idx + 2] = center_y + entry.dy * (1 + new) * entry.magnitude
    end

    -- Rotate wave buffers
    wave.previous, wave.current, wave.next = wave.current, wave.next, wave.previous

    if offset_max < data.wave_deactivation_threshold then
        data.is_active = false
    end

    -- Outline positions: lerp between polygon points
    local poly_len = #polygon_positions
    for i = 1, poly_len - 2, 2 do
        local x1, y1 = polygon_positions[i], polygon_positions[i+1]
        local x2, y2 = polygon_positions[i+2], polygon_positions[i+3]
        local x, y = mix2(x1, y1, x2, y2, 0.5)
        outline_positions[i+0] = x
        outline_positions[i+1] = y
    end

    outline_positions[1] = polygon_positions[#polygon_positions-1]
    outline_positions[2] = polygon_positions[#polygon_positions-0]

    -- triangulation
    if _bubble_field_triangulator == nil then
        _bubble_field_triangulator = rt.DelaunayTriangulation()
    end

    local success, solid_tris = pcall(love.math.triangulate, polygon_positions)
    if not success then
        _bubble_field_triangulator:triangulate(polygon_positions, polygon_positions)
        solid_tris = _bubble_field_triangulator:get_triangles()
    end

    -- Build mesh data
    if #solid_tris > 0 then
        local solid_data = data.mesh_data or {}
        for i = 1, #solid_data do solid_data[i] = nil end -- clear previous mesh_data

        local idx = 1
        for tri in values(solid_tris) do
            for j = 1, 6, 2 do
                solid_data[idx] = { tri[j], tri[j+1] }
                idx = idx + 1
            end
        end
        data.mesh_data = solid_data
    else
        data.mesh_data = nil
    end

    return {
        wave = data.wave,
        mesh_data = data.mesh_data,
        is_active = data.is_active,
        is_excitation = data.should_excite,
        outline_positions = data.outline_positions,
    }
end

while true do
    local message = main_to_worker:demand()
    worker_to_main:push(_handler(message))
end
]]