--- @class ow.RayReceiver
ow.RayReceiver = meta.class("RayReceiver", rt.Drawable)
meta.add_signals(ow.RayReceiver, "ray_collision_start", "ray_collision_end")

--- @brief
function ow.RayReceiver:instantiate(object, stage, scene)
    meta.assert(object, "ObjectWrapper", stage, "Stage", scene, "OverworldScene")
    self._world = stage:get_physics_world()

    local type = b2.BodyType.KINEMATIC
    if object:get_string("body_type") == b2.BodyType.DYNAMIC then
        type = b2.BodyType.DYNAMIC
    end

    self._body = b2.Body(self._world, type, 0, 0, object:get_physics_shapes())
    self._body:set_user_data(self)

    local group = 0x0
    group = bit.bor(group, ow.RayMaterial.ABSORPTIVE)
    group = bit.bor(group, ow.RayMaterial.RECEIVER)
    self._body:set_collision_group(group)

    self:signal_connect("ray_collision_start", function(self, x, y, nx, ny)
        self._is_active = true
    end)

    self:signal_connect("ray_collision_end", function(self)
        self._is_active = false
    end)

    self._shapes = self._body:get_shapes()
end

--- @brief
function ow.RayReceiver:draw()
    love.graphics.translate(self._body:get_position())

    if self._is_active then
        love.graphics.setColor(1, 0, 1, 1)
    else
        love.graphics.setColor(1, 1, 1, 1)
    end

    for shape in values(self._shapes) do
        shape:draw()
    end
end

--- @brief
function ow.RayReceiver:update(delta)

end