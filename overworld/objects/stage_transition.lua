--- @class ow.StageTransition
ow.StageTransition = meta.class("StageTransition")

--- @brief
function ow.StageTransition:instantiate(object, world)
    meta.assert(object, "ObjectWrapper", world, "PhysicsWorld")
    assert(object.type == ow.ObjectType.RECTANGLE)
    self._body = b2.Body(world, b2.BodyType.STATIC, 0, 0, object:get_physics_shapes())
end