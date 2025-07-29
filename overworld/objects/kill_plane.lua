require "common.contour"

rt.settings.overworld.kill_plane = {
    border_width = 20
}

--- @class ow.KillPlane
ow.KillPlane = meta.class("KillPlane")

local _inner_shader, _outer_shader

local first = true -- TODO

function ow.KillPlane:instantiate(object, stage, scene)
    if _inner_shader == nil then _inner_shader = rt.Shader("overworld/objects/kill_plane.glsl", { MODE = 0 }) end
    if _outer_shader == nil then _outer_shader = rt.Shader("overworld/objects/kill_plane.glsl", { MODE = 1 }) end

    if first then
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "q" then
                _inner_shader:recompile()
                _outer_shader:recompile()
            end
        end)
    end

    self._scene = scene
    self._stage = stage

    -- collision
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)

    local bounce_group = rt.settings.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._is_blocked = false
    self._body:signal_connect("collision_start", function(_, other_body)
        if self._is_blocked == true then return end
        self._stage:get_active_checkpoint():spawn()
        self._is_blocked = true
        self._stage:get_physics_world():signal_connect("step", function()
            self._is_blocked = false
            return meta.DISCONNECT_SIGNAL
        end)
    end)

    -- visibility : disable mesh
    self._is_visible = object:get_boolean("is_visible", false)
    if self._is_visible == nil then self._is_visible = true end
    if self._is_visible == false then return end

    -- inner mesh solid
    self._contour = object:create_contour()
    self._inner_mesh = object:create_mesh()

    table.insert(self._contour, self._contour[1])
    table.insert(self._contour, self._contour[2])

    -- Calculate arc-length parameterization for texture coordinates
    local arc_lengths = {0} -- cumulative distances
    local total_perimeter = 0

    for i = 1, #self._contour - 2, 2 do
        local x1, y1 = self._contour[i+0], self._contour[i+1]
        local x2, y2 = self._contour[i+2], self._contour[i+3]
        local segment_length = math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
        total_perimeter = total_perimeter + segment_length
        table.insert(arc_lengths, total_perimeter)
    end

    -- outer mesh border

    self._outer_mesh = nil

    local outer_mesh_data = {}
    local outer_mesh_vertex_map = {}

    local border_w = rt.settings.overworld.kill_plane.border_width

    local _contour_x1, _contour_y1, _contour_x2, _contour_y2 = 1, 2, 3, 4
    local _outer_x1, _outer_y1, _outer_x2, _outer_y2 = 5, 6, 7, 8

    local quads = {}
    for i = 1, #self._contour - 2, 2 do
        local contour_x1, contour_y1 = self._contour[i+0], self._contour[i+1]
        local contour_x2, contour_y2 = self._contour[i+2], self._contour[i+3]

        local dx, dy = math.normalize(contour_x2 - contour_x1, contour_y2 - contour_y1)
        dx, dy = math.turn_right(dx, dy)

        local outer_x1, outer_y1 = contour_x1 + dx * border_w, contour_y1 + dy * border_w
        local outer_x2, outer_y2 = contour_x2 + dx * border_w, contour_y2 + dy * border_w

        table.insert(quads, {
            [_contour_x1] = contour_x1,
            [_contour_y1] = contour_y1,
            [_contour_x2] = contour_x2,
            [_contour_y2] = contour_y2,
            [_outer_x1] = outer_x1,
            [_outer_y1] = outer_y1,
            [_outer_x2] = outer_x2,
            [_outer_y2] = outer_y2,
        })
    end

    local function _segment_intersection(x1, y1, x2, y2, x3, y3, x4, y4)
        local denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)

        if denom == 0 then
            return nil
        end

        local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom

        if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
            local px = x1 + t * (x2 - x1)
            local py = y1 + t * (y2 - y1)
            return px, py
        end

        return nil
    end

    local vertex_i = 1
    for quad_i = 1, #quads do
        local current = quads[quad_i+0]
        local next = quads[(quad_i % #quads) + 1]

        local ix, iy = _segment_intersection(
            current[_outer_x1], current[_outer_y1], current[_outer_x2], current[_outer_y2],
            next[_outer_x1], next[_outer_y1], next[_outer_x2], next[_outer_y2]
        )

        if ix ~= nil then -- concave corner, quads would overlap
            current[_outer_x2], current[_outer_y2] = ix, iy
            next[_outer_x1], next[_outer_y1] = ix, iy
        end

        -- Calculate normalized arc-length texture coordinates
        local u1 = arc_lengths[quad_i] / total_perimeter
        local u2 = arc_lengths[quad_i + 1] / total_perimeter

        table.insert(outer_mesh_data, {
            current[_contour_x1], current[_contour_y1], u1, 0, 1, 1, 1, 1
        })

        table.insert(outer_mesh_data, {
            current[_contour_x2], current[_contour_y2], u2, 0, 1, 1, 1, 1
        })

        table.insert(outer_mesh_data, {
            current[_outer_x1], current[_outer_y1], u1, 1, 0, 0, 0, 1
        })

        table.insert(outer_mesh_data, {
            current[_outer_x2], current[_outer_y2], u2, 1, 0, 0, 0, 1
        })

        for j in range(
            vertex_i + 0, vertex_i + 1, vertex_i + 2,
            vertex_i + 1, vertex_i + 2, vertex_i + 3
        ) do
            table.insert(outer_mesh_vertex_map, j)
        end

        vertex_i = vertex_i + 4
    end

    -- fill triangles
    for i = 1, vertex_i - 6, 4 do
        for j in range(
            i + 1, -- contour
            i + 3, -- current outer
            i + 4 + 2 -- next outer
        ) do
            table.insert(outer_mesh_vertex_map, j)
        end
    end

    do -- last triangle needs separate coords, otherwise it would interpolate between uv.x = 0 and uv.y = 1
        local a = table.deepcopy(outer_mesh_data[vertex_i - 4 + 1])
        local b = table.deepcopy(outer_mesh_data[vertex_i - 4 + 3])
        local c = table.deepcopy(outer_mesh_data[3])

        for which in range(a, b, c) do
            which[3] = 1 -- override uv.x
            table.insert(outer_mesh_data, which)

            table.insert(outer_mesh_vertex_map, vertex_i)
            vertex_i = vertex_i + 1
        end
    end

    self._outer_mesh = rt.Mesh(
        outer_mesh_data,
        rt.MeshDrawMode.TRIANGLES
    )
    self._outer_mesh:set_vertex_map(outer_mesh_vertex_map)
end

function ow.KillPlane:draw()
    if not self._is_visible or not self._scene:get_is_body_visible(self._body) then return end

    local camera_offset = { self._scene:get_camera():get_offset() }
    local camera_scale = self._scene:get_camera():get_final_scale()
    local red = { rt.Palette.RED:unpack() }
    love.graphics.setColor(1, 1, 1, 1)

    _inner_shader:bind()
    _inner_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self) * 100)
    _inner_shader:send("camera_offset", camera_offset)
    _inner_shader:send("camera_scale", camera_scale)
    _inner_shader:send("red", red)
    self._inner_mesh:draw()
    _inner_shader:unbind()

    _outer_shader:bind()
    _outer_shader:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self) * 100)
    _outer_shader:send("camera_offset", camera_offset)
    _outer_shader:send("camera_scale", camera_scale)
    _outer_shader:send("red", red)
    self._outer_mesh:draw()
    _outer_shader:unbind()
end