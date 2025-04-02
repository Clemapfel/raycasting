
--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world())
    })

    self._body:set_is_sensor(false)
    self._body:set_restitution(2 - rt.settings.overworld.player.restitution)
    self._body:add_tag("slippery")
    --[[
    self._body:signal_connect("collision_start", function(self, other, normal_x, normal_y)
        local dx, dy = other:get_linear_velocity()
        local dot_product = dx * normal_x + dy * normal_y
        dx = dx - 2 * dot_product * normal_x
        dy = dy - 2 * dot_product * normal_y


        other:set_linear_velocity(dx, dy)

    end)
    ]]--
end

--- @brief
function ow.BouncePad:draw()
    self._body:draw()
end