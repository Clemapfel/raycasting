require "common.contour"

rt.settings.overworld.kill_plane = {
    spike_width = 20, -- px
}

--- @class ow.KillPlane
ow.KillPlane = meta.class("KillPlane")

local _inner_shader, _outer_shader

local _mesh_format = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.TEXTURE_COORDINATES, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.COLOR, name = rt.VertexAttribute.COLOR, format = "floatvec4" },
}

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

local first = true -- TODO

--- @brief
function ow.KillPlane:instantiate(object, stage, scene)
    if _inner_shader == nil then _inner_shader = rt.Shader("overworld/objects/kill_plane.glsl", { MODE = 0 }) end
    if _outer_shader == nil then _outer_shader = rt.Shader("overworld/objects/kill_plane.glsl", { MODE = 1 }) end

    if first then
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "c" then
                _inner_shader:recompile()
                _outer_shader:recompile()
            end
        end)
        first = false
    end

    self._scene = scene
    self._stage = stage

    self._is_visible = object:get_boolean("is_visible", false)
    if self._is_visible == nil then self._is_visible = true end

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

    if self._is_visible == false then return end

    -- compute center and mesh data
    self._contour = object:create_contour()
    local center_x, center_y, n = 0, 0, 0
    for i = 1, #self._contour, 2 do
        local x, y = self._contour[i], self._contour[i+1]
        center_x = center_x + x
        center_y = center_y + y
        n = n + 1
    end

    center_x = center_x / n
    center_y = center_y / n
    self._contour_center_x, self._contour_center_y = center_x, center_y

    table.insert(self._contour, self._contour[1])
    table.insert(self._contour, self._contour[2])

    local inner_mesh_data = {}

    if rt.is_contour_convex(self._contour) then
        local vertex_map = {}
        inner_mesh_data = {
            { self._contour_center_x, self._contour_center_y, 0, 0, 1, 1, 1, 1 }
        }

        local vertex_i = 1
        for i = 1, #self._contour, 2 do
            table.insert(inner_mesh_data, {
                self._contour[i+0], self._contour[i+1], 1, 1, 1, 1, 1, 1
            })
        end

        self._inner_mesh = rt.Mesh(
            inner_mesh_data,
            rt.MeshDrawMode.TRIANGLE_FAN,
            _mesh_format,
            rt.GraphicsBufferUsage.STATIC
        )
    else
        local temp = table.deepcopy(self._contour)
        table.insert(temp, 1, self._contour_center_y)
        table.insert(temp, 1, self._contour_center_x)

        local triangulation = rt.DelaunayTriangulation(temp, temp)

        for tri in values(triangulation:get_triangles()) do
            for i = 1, #tri, 2 do
                local x, y = tri[i+0], tri[i+1]

                local data
                if math.equals(x, self._contour_center_x, math.eps) and
                    math.equals(y, self._contour_center_y, math.eps)
                then
                    data = {
                        x, y, 0, 0, 1, 1, 1, 1
                    }
                else
                    data = {
                        x, y, 1, 1, 1, 1, 1, 1
                    }
                end

                table.insert(inner_mesh_data, data)
            end
        end

        self._inner_mesh = rt.Mesh(
            inner_mesh_data,
            rt.MeshDrawMode.TRIANGLES,
            _mesh_format,
            rt.GraphicsBufferUsage.STATIC
        )
    end

    -- outer mesh
    local outer_mesh_data = {}
    local vertex_map = {}
    local border_w = rt.settings.overworld.kill_plane.spike_width

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

    self._dbg = {}

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


        table.insert(outer_mesh_data, {
            current[_contour_x1], current[_contour_y1], 0, 0, 1, 1, 1, 1
        })

        table.insert(outer_mesh_data, {
            current[_contour_x2], current[_contour_y2], 1, 0, 1, 1, 1, 1
        })

        table.insert(outer_mesh_data, {
            current[_outer_x1], current[_outer_y1], 0, 1, 0, 0, 0, 1
        })

        table.insert(outer_mesh_data, {
            current[_outer_x2], current[_outer_y2], 1, 1, 0, 0, 0, 1
        })

        for j in range(
            vertex_i + 0, vertex_i + 1, vertex_i + 2,
            vertex_i + 1, vertex_i + 2, vertex_i + 3
        ) do
            table.insert(vertex_map, j)
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
            table.insert(vertex_map, j)
        end
    end

    for j in range(
        vertex_i - 4 + 1,
        vertex_i - 4 + 3,
        3
    ) do
        table.insert(vertex_map, j)
    end

    self._outer_mesh = rt.Mesh(
        outer_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        _mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )
    self._outer_mesh:set_vertex_map(vertex_map)
end

--- @brief
function ow.KillPlane:draw()
    if not self._is_visible or not self._scene:get_is_body_visible(self._body) then return end
    love.graphics.setColor(1, 1, 1, 1)

    _inner_shader:bind()
    _inner_shader:send("elapsed", rt.SceneManager:get_elapsed()) -- synched along all kill planes
    _inner_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _inner_shader:send("camera_scale", self._scene:get_camera():get_final_scale())
    self._inner_mesh:draw()
    _inner_shader:unbind()

    _outer_shader:bind()
    _outer_shader:send("elapsed", rt.SceneManager:get_elapsed())
    _outer_shader:send("camera_offset", { self._scene:get_camera():get_offset() })
    _outer_shader:send("camera_scale", self._scene:get_camera():get_final_scale())
    self._outer_mesh:draw()
    _outer_shader:unbind()
end