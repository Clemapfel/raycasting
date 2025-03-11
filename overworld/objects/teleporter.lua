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

    self._body:set_is_solid(false)
    self._body:set_is_sensor(true)
    self._body:signal_connect("collided", function(self, other, x, y, normal_x, normal_y)
        if other:has_tag(b2.BodyTag.IS_PLAYER) then
            other:set_position(50, 50)
        end
    end)
end

--- @brief
function ow.Teleporter:draw()
    self._body:draw()
end