
--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world())
    })

    self._body:set_is_sensor(true)
    self._body:set_collides_with(b2.CollisionGroup.GROUP_16)
    self._body:signal_connect("collision_start", function(self, other, normal_x, normal_y)
        local vx, vy = other:get_linear_velocity()
        other:set_linear_velocity(-vx, math.abs(vy))
    end)
end

--- @brief
function ow.BouncePad:draw()
    self._body:draw()
end