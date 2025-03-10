require "common.blend_mode"
require "overworld.object_wrapper"

--- @class ow.Hitbox
ow.Hitbox = meta.class("OverworldHitbox", rt.Drawable)

--- @brief
function ow.Hitbox:instantiate(object, world)
    meta.assert(object, "ObjectWrapper", world, "PhysicsWorld")

    self._world = world
    if object.properties.rotate == true then
        self._body = b2.Body(self._world, b2.BodyType.DYNAMIC, 0, 0, object:get_physics_shapes())
        self._body:set_angular_velocity(0.001 * 2 * math.pi)
    else
        self._body = b2.Body(self._world, b2.BodyType.STATIC, 0, 0, object:get_physics_shapes())
    end
end

--- @brief
function ow.Hitbox:draw()
    self._body:draw()
end
