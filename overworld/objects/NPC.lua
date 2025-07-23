require "common.delaunay_triangulation"
require "overworld.deformable_mesh"

rt.settings.overworld.npc = {
    segment_length = 10,
    buffer_depth = rt.settings.player.radius
}

--- @class ow.NPC
ow.NPC = meta.class("NPC")

local _collision_group = b2.CollisionGroup.GROUP_07

local _data_mesh_format = {
    { location = 4, name = "origin", format = "floatvec2" }, -- spring origin
    { location = 5, name = "contour_vector", format = "floatvec3" } -- normalized xy, z is length
}

--- @brief
function ow.NPC:instantiate(object, stage, scene)
    self._velocity_x = 0
    self._velocity_y = 0

    self._scene = scene
    self._stage = stage
    self._world = stage:get_physics_world()

    -- inner, hard-body shell
    local contour = object:create_contour()

    self._mesh = ow.DeformableMesh(self._world, contour) -- has inner hard shell
    self._mesh:get_body():add_tag("stencil")

    self._mesh_center_x, self._mesh_center_y = self._mesh:get_center()

    self._sensor = object:create_physics_body(self._world)
    self._sensor:set_is_sensor(true)
    self._sensor:set_collides_with(rt.settings.player.bounce_collision_group)
    self._sensor:set_collision_group(rt.settings.player.bounce_collision_group)

    self._is_active = false
    self._sensor:signal_connect("collision_start", function()
        self._is_active = true
    end)

    self._sensor:signal_connect("collision_end", function()
        self._is_active = false
        self._last_force_x, self._last_force_y = 0, 0
    end)

    self._is_visible = self._scene:get_is_body_visible(self._sensor)

    self._last_force_x, self._last_force_y = 0, 0
end

--- @brief
function ow.NPC:draw()
    if not self._scene:get_is_body_visible(self._sensor) then
        if self._is_visible then
            self._is_visible = false
            self._mesh:reset()
        end

        return
    end

    self._mesh:draw()
    self._mesh:get_body():draw()
    self._sensor:draw()
end

--- @brief
function ow.NPC:update(delta)
    --if not self._scene:get_is_body_visible(self._sensor) then return end

    local player = self._scene:get_player()
    local x, y = player:get_position()
    local radius = player:get_radius()
    local force_x, force_y = self._mesh:step(delta, x, y, radius)

    local player_body = player:get_physics_body()
    local vx, vy = player_body:get_velocity()
    local mesh_x, mesh_y = self._mesh:get_center()
    local dx, dy = math.normalize(x - mesh_x, y - mesh_y)
    local force = math.magnitude(force_x, force_y)

    player_body:set_velocity(
        vx + force_x, vy + force_y
    )

    self._last_force_x, self._last_force_y = dx * force, dy * force
end

--- @brief
function ow.NPC:get_render_priority()
    return 1
end