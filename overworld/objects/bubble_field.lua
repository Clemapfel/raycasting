rt.settings.overworld.bubble_field = {
    segment_length = 10,
    thickness = 2,
    n_smoothing_iterations = 5,
    alpha = 1
}

--- @class ow.BubbleField
ow.BubbleField = meta.class("BubbleField")

local _outline_shader, _body_shader

--- @brief
function ow.BubbleField:instantiate(object, stage, scene)
    self._scene = scene
    self._world = stage:get_physics_world()
    self._elapsed = 0

    self._camera_offset = {0, 0}
    self._camera_scale = 1

    if _body_shader == nil then _body_shader = rt.Shader("overworld/objects/bubble_field.glsl", { APPLY_FRAGMENT_SHADER = true }) end
    if _outline_shader == nil then _outline_shader = rt.Shader("overworld/objects/bubble_field.glsl", nil) end

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            _body_shader:recompile()
        end
    end)

    -- collision
    self._body = object:create_physics_body(self._world)
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)

    self._body:signal_connect("collision_start", function()
        local player = scene:get_player()
        if player:get_is_bubble() == false and not self._blocked then
            self:_block_signals()

            player:set_is_bubble(true)
        end
    end)

    self._body:signal_connect("collision_end", function()
        local player = scene:get_player()
        if player:get_is_bubble() == true and not self._blocked then
            self:_block_signals()

            -- check if player is actually outside body, in case of exiting one shape of self but entering another
            if self._body:test_point(player:get_physics_body():get_position()) then
                return
            end

            player:set_is_bubble(false)
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
    local segment_length = rt.settings.overworld.bubble_field.segment_length
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

    local first_segment = subdivided_contour[1]
    local last_segment = subdivided_contour[#subdivided_contour]
    table.insert(subdivided_contour, {
        last_segment[3], last_segment[4], -- End of the last segment
        first_segment[1], first_segment[2] -- Start of the first segment
    })

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

    local flat = {}
    for segment in values(subdivided_contour) do
        for x in values(segment) do
            table.insert(flat, x)
        end
    end

    -- construct filled mesh
    local success, solid_tris = pcall(love.math.triangulate, flat)
    if not success then
        success, solid_tris = pcall(slick.triangulate, { flat })
    end

    if success then
        local solid_data = {}
        for tri in values(solid_tris) do
            for i = 1, 6, 2 do
                table.insert(solid_data, {
                    tri[i+0], tri[i+1], 0, 0, 1, 1, 1, 1
                })
            end
        end

        self._solid_mesh = rt.Mesh(solid_data, rt.MeshDrawMode.TRIANGLES):get_native()
    else
        self._solid_mesh = nil
    end

    -- construct line mesh with bezels
    local mesh_data = {}
    local vertex_map = {}
    local half_thickness = rt.settings.overworld.bubble_field.thickness / 2

    local vertex_index = 1
    for i = 1, #subdivided_contour do
        local segment1 = subdivided_contour[i]
        local segment2 = subdivided_contour[(i % #subdivided_contour) + 1]

        local x1, y1, x2, y2 = segment1[1], segment1[2], segment1[3], segment1[4]
        local x3, y3, x4, y4 = segment2[1], segment2[2], segment2[3], segment2[4]

        if not is_equal(x2, x3) or not is_equal(y2, y3) then
            goto continue
        end

        local dx1, dy1 = x2 - x1, y2 - y1
        local length1 = math.sqrt(dx1 * dx1 + dy1 * dy1)
        local nx1, ny1 = -dy1 / length1, dx1 / length1

        local dx2, dy2 = x4 - x3, y4 - y3
        local length2 = math.sqrt(dx2 * dx2 + dy2 * dy2)
        local nx2, ny2 = -dy2 / length2, dx2 / length2

        -- line quads
        table.insert(mesh_data, { x1 + nx1 * half_thickness, y1 + ny1 * half_thickness, 0, 0, 1, 1, 1, 1 })
        table.insert(mesh_data, { x1 - nx1 * half_thickness, y1 - ny1 * half_thickness, 0, 1, 1, 1, 1, 1 })
        table.insert(mesh_data, { x2 + nx1 * half_thickness, y2 + ny1 * half_thickness, 1, 0, 1, 1, 1, 1 })
        table.insert(mesh_data, { x2 - nx1 * half_thickness, y2 - ny1 * half_thickness, 1, 1, 1, 1, 1, 1 })

        table.insert(vertex_map, vertex_index + 0)
        table.insert(vertex_map, vertex_index + 1)
        table.insert(vertex_map, vertex_index + 2)

        table.insert(vertex_map, vertex_index + 2)
        table.insert(vertex_map, vertex_index + 1)
        table.insert(vertex_map, vertex_index + 3)

        vertex_index = vertex_index + 4

        -- bezels
        table.insert(mesh_data, { x2 + nx1 * half_thickness, y2 + ny1 * half_thickness, 0, 0, 1, 1, 1, 1 })
        table.insert(mesh_data, { x2 - nx1 * half_thickness, y2 - ny1 * half_thickness, 0, 1, 1, 1, 1, 1 })
        table.insert(mesh_data, { x3 + nx2 * half_thickness, y3 + ny2 * half_thickness, 1, 0, 1, 1, 1, 1 })

        table.insert(mesh_data, { x2 + nx1 * half_thickness, y2 + ny1 * half_thickness, 0, 0, 1, 1, 1, 1 })
        table.insert(mesh_data, { x2 - nx1 * half_thickness, y2 - ny1 * half_thickness, 0, 1, 1, 1, 1, 1 })
        table.insert(mesh_data, { x3 - nx2 * half_thickness, y3 - ny2 * half_thickness, 1, 1, 1, 1, 1, 1 })

        table.insert(vertex_map, vertex_index + 0)
        table.insert(vertex_map, vertex_index + 1)
        table.insert(vertex_map, vertex_index + 2)

        table.insert(vertex_map, vertex_index + 3)
        table.insert(vertex_map, vertex_index + 4)
        table.insert(vertex_map, vertex_index + 5)

        vertex_index = vertex_index + 6

        ::continue::
    end

    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)
    self._n_vertices = table.sizeof(mesh_data)
    self._mesh:set_vertex_map(vertex_map)
    self._mesh = self._mesh:get_native()

    self._contour = {}
    for segment in values(subdivided_contour) do
        for x in values(segment) do
            table.insert(self._contour, x)
        end
    end
end

--- @brief
function ow.BubbleField:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end

    self._elapsed = self._elapsed + delta
    self._camera_offset = { self._scene:get_camera():get_offset() }
    self._camera_scale = self._scene:get_camera():get_scale()
end

--- @brief
function ow.BubbleField:draw()
    if not self._scene:get_is_body_visible(self._body) then return end
    local r, g, b, a = rt.Palette.BUBBLE_FIELD:unpack()

    if self._solid_mesh ~= nil then
        love.graphics.setColor(r, g, b, a * rt.settings.overworld.bubble_field.alpha)
        _body_shader:bind()
        _body_shader:send("n_vertices", self._n_vertices)
        _body_shader:send("elapsed", self._elapsed)
        _body_shader:send("camera_offset", self._camera_offset)
        _body_shader:send("camera_scale", self._camera_scale)
        love.graphics.draw(self._solid_mesh)
        _body_shader:unbind()
    end

    love.graphics.setColor(r, g, b, a)
    _outline_shader:bind()
    _outline_shader:send("n_vertices", self._n_vertices)
    _outline_shader:send("elapsed", self._elapsed)
    love.graphics.draw(self._mesh)
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
    return math.huge
end