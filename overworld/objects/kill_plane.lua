require "common.contour"

rt.settings.overworld.kill_plane = {
    spike_width = 20, -- px
}

--- @class ow.KillPlane
ow.KillPlane = meta.class("KillPlane")

local _shader

local _mesh_format = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.COLOR, name = rt.VertexAttribute.COLOR, format = "floatvec4" },
}

local function _line_intersection(x1, y1, dx1, dy1, x2, y2, dx2, dy2)
    local det = dx1 * dy2 - dy1 * dx2
    if math.abs(det) < 1e-10 then
        return nil -- Lines are parallel
    end

    local t = ((x2 - x1) * dy2 - (y2 - y1) * dx2) / det
    return x1 + t * dx1, y1 + t * dy1
end

local function _is_concave_corner(prev_dx, prev_dy, curr_dx, curr_dy)
    local cross = prev_dx * curr_dy - prev_dy * curr_dx
    return cross < 0
end

--- @brief
function ow.KillPlane:instantiate(object, stage, scene)
    if _shader == nil then _shader = rt.Shader("overworld/objects/kill_plane.glsl") end
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
            { self._contour_center_x, self._contour_center_y, 1, 1, 1, 1 }
        }

        local vertex_i = 1
        for i = 1, #self._contour, 2 do
            table.insert(inner_mesh_data, {
                self._contour[i+0], self._contour[i+1], 0, 0, 0, 1
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
                        x, y, 1, 1, 1, 1
                    }
                else
                    data = {
                        x, y, 0, 0, 0, 1
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

    local vertex_i = 1
    for i = 1, #self._contour - 2, 2 do
        local contour_x1, contour_y1 = self._contour[i+0], self._contour[i+1]
        local contour_x2, contour_y2 = self._contour[i+2], self._contour[i+3]

        -- get rect that extends the outer contour
        local side = math.cross(contour_x1, contour_y1, contour_x2, contour_y2)

        local dx, dy = math.normalize(contour_x2 - contour_x1, contour_y2 - contour_y1)
        dx, dy = math.turn_right(dx, dy)

        local x1, y1 = contour_x1 + dx * border_w, contour_y1 + dy * border_w
        local x2, y2 = contour_x2 + dx * border_w, contour_y2 + dy * border_w

        for x in range(x1, y1, x2, y2) do
            table.insert(self._dbg, x)
        end

        table.insert(outer_mesh_data, {
            contour_x1, contour_y1, 1, 1, 1, 1
        })

        table.insert(outer_mesh_data, {
            contour_x2, contour_y2, 1, 1, 1, 1
        })

        table.insert(outer_mesh_data, {
            x1, y1, 0, 0, 0, 1
        })

        table.insert(outer_mesh_data, {
            x2, y2, 0, 0, 0, 1
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
    self._inner_mesh:draw()
    self._outer_mesh:draw()

    --[[
    love.graphics.line(self._contour)
    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    love.graphics.line(self._dbg)
    ]]--
end