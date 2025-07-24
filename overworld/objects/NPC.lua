require "common.delaunay_triangulation"
require "overworld.deformable_mesh"
require "overworld.blood_drop"

rt.settings.overworld.npc = {
    segment_length = 10,
    buffer_depth = rt.settings.player.radius,
    blood_drop_velocity = 300,
    blood_drop_gravity = 300
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

    self._deformable_mesh = ow.DeformableMesh(self._world, contour) -- has inner hard shell
    self._deformable_mesh:get_body():add_tag("stencil")

    self._mesh = object:create_mesh()

    table.insert(contour, contour[1])
    table.insert(contour, contour[2])
    self._contour = contour

    self._deformable_mesh_center_x, self._deformable_mesh_center_y = self._deformable_mesh:get_center()

    self._sensor = object:create_physics_body(self._world)
    self._sensor:set_is_sensor(true)
    self._sensor:set_collides_with(rt.settings.player.bounce_collision_group)
    self._sensor:set_collision_group(rt.settings.player.bounce_collision_group)

    self._blood_drops = {}

    self._is_active = false
    self._sensor:signal_connect("collision_start", function(_, normal_x, normal_y, x, y)
        self._is_active = true

        --[[
        -- spawn blood drops
        local x, y = self._scene:get_player():get_position()
        local up = 3 / 4 * 2 * math.pi
        for i = 1, rt.random.integer(10, 30) do
            local angle = rt.random.number(up - 0.5 * math.pi, up + 0.5 * math.pi)
            local magnitude = rt.settings.overworld.npc.blood_drop_velocity
            local vx, vy = math.cos(angle) * magnitude, math.sin(angle) * magnitude
            local blood_drop = ow.BloodDrop(
                self._stage,
                x, y,
                rt.random.number(1, 5), -- radius
                vx, vy,
                rt.random.number(0, 1) -- hue
            )

            blood_drop:signal_connect("collision", function()
                local to_remove
                for i, drop in values(self._blood_drops) do
                    if drop == blood_drop then
                        to_remove = i
                    end
                end

                assert(i ~= nil)
                table.remove(self._blood_drops, to_remove)
                return meta.DISCONNECT_SIGNAL
            end)

            table.insert(self._blood_drops, blood_drop)
        end
        ]]--
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
            self._deformable_mesh:reset()
        end

        return
    end

    love.graphics.setColor(0.5, 0.5, 0.5, 1)
    self._deformable_mesh:draw_base()
    self._deformable_mesh:draw_body()
    love.graphics.setLineWidth(8)
    rt.Palette.BLACK:bind()
    self._deformable_mesh:draw_outline()

    love.graphics.setLineWidth(5)
    rt.Palette.WHITE:bind()
    self._deformable_mesh:draw_outline()

    --self._deformable_mesh:get_body():draw()
    --self._sensor:draw()

    for drop in values(self._blood_drops) do
        drop:draw()
    end
end

--- @brief
function ow.NPC:update(delta)
    --if not self._scene:get_is_body_visible(self._sensor) then return end

    for drop in values(self._blood_drops) do
        drop:get_body():apply_force(0, rt.settings.overworld.npc.blood_drop_gravity)
    end

    local player = self._scene:get_player()
    local x, y = player:get_position()
    local radius = player:get_radius()
    local force_x, force_y = self._deformable_mesh:step(delta, x, y, radius)

    local player_body = player:get_physics_body()
    local vx, vy = player_body:get_velocity()
    local mesh_x, mesh_y = self._deformable_mesh:get_center()
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