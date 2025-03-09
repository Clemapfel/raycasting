require "common.blend_mode"
require "overworld.object_wrapper"

--- @class ow.Hitbox
ow.Hitbox = meta.class("OverworldHitbox")

--- @brief
function ow.Hitbox:instantiate(object, world)
    meta.assert(object, "ObjectWrapper", world, "PhysicsWorld")

    self._world = world
    self._body = b2.Body(self._world, b2.BodyType.STATIC, 0, 0, object:get_physics_shapes())
end
