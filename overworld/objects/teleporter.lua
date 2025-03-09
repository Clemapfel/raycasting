--- @class ow.Teleporter
ow.Teleporter = meta.class("Teleporter")

--- @brief
function ow.Teleporter:instantiate(object, world)
    meta.assert(object, "ObjectWrapper", world, "PhysicsWorld")
    assert(object.type == ow.ObjectType.ELLIPSE)
    self._body = b2.Body(world, b2.BodyType.STATIC, 0, 0, object:get_physics_shapes())
end