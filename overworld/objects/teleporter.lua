--- @class ow.Teleporter
ow.Teleporter = meta.class("Teleporter", rt.Drawable)

--- @brief
function ow.Teleporter:instantiate(object, stage, scene)
    meta.assert(object, "ObjectWrapper", stage, "Stage", scene, "OverworldScene")
    assert(object.type == ow.ObjectType.ELLIPSE)
    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.STATIC,
        0, 0,
        object:get_physics_shapes()
    )

    local target = object.properties.target
    assert(target ~= nil, "In ow.Teleporter.instantiate: `target` property of Teleporter class is nil")
    self._target_x, self._target_y = target:get_centroid()

    self._body:set_is_solid(false)
    self._body:set_is_sensor(true)
    self._body:signal_connect("collision_start", function(_, other, x, y, normal_x, normal_y)
        rt.warning("In ow.Teleporter: todo")
    end)

end

--- @brief
function ow.Teleporter:draw()
    self._body:draw()
end