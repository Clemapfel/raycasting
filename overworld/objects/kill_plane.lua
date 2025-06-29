rt.settings.overworld.kill_plane = {
    max_respawn_duration = 2
}

--- @class ow.KillPlane
ow.KillPlane = meta.class("KillPlane")

--- @class ow.KillPlaneTarget
ow.KillPlaneTarget = meta.class("KillPlaneTarget") -- dummy

local _shader

-- shape mesh data members
local _origin_x_index = 1
local _origin_y_index = 2
local _dx_index = 3
local _dy_index = 4
local _magnitude_index = 5

--- @brief
function ow.KillPlane:instantiate(object, stage, scene)
    if _shader == nil then _shader = rt.Shader("overworld/objects/kill_plane.glsl") end
    self._scene = scene
    self._stage = stage
    self._world = stage:get_physics_world()

    -- collision
    self._body = object:create_physics_body(self._world)
    self._body:set_is_sensor(true)

    local bounce_group = rt.settings.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._blocked = false
    self._body:signal_connect("collision_start", function(_, other_body)
        self._body:signal_set_is_blocked("collision_start", true)
        self._world:signal_connect("step", function()
            self._body:signal_set_is_blocked("collision_start", false)
            return meta.DISCONNECT_SIGNAL
        end)
        self._stage:get_active_checkpoint():spawn()
    end)

    -- visual
    local points = object:create_contour()
    points = rt.subdivide_contour(points, 10)
    table.insert(points, points[1])
    table.insert(points, points[2])

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

    local triangulation = rt.DelaunayTriangulation(points, points):get_triangle_vertex_map()

    local shape_mesh_format = {
        { location = 0, name = "origin", format = "floatvec2" }, -- absolute xy
        { location = 1, name = "contour_vector", format = "floatvec3" } -- normalized xy, magnitude
    }

    local shape_mesh_data = {}

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

        table.insert(shape_mesh_data, {
            [_origin_x_index] = origin_x,
            [_origin_y_index] = origin_y,
            [_dx_index] = dx,
            [_dy_index] = dy,
            [_magnitude_index] = magnitude
        })
    end

    self._contour_center_x, self._contour_center_y = center_x, center_y

    self._mesh = rt.Mesh(
        shape_mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        shape_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )
    self._mesh:set_vertex_map(triangulation)

    self._outline_color = rt.Palette.KILL_PLANE:clone()
    self._base_color = rt.Palette.KILL_PLANE:darken(0.9)

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            _shader:recompile()
        end
    end)
end

--- @brief
function ow.KillPlane:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    _shader:bind()
    _shader:send("elapsed", rt.SceneManager:get_elapsed())

    self._base_color:bind()
    love.graphics.draw(self._mesh:get_native())

    self._outline_color:bind()
    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(4)
    love.graphics.line(self._contour)

    _shader:unbind()
end