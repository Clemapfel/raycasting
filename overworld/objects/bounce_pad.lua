
--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world())
    })

    self._body:set_restitution(0) -- handled in player update
    --self._body:add_tag("unjumpable")
    self._body:add_tag("bouncy")

    self._body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y, contact)
        local player = other_body:get_user_data()
        normal_x, normal_y = -normal_x, -normal_y
        local self_velocity_x, self_velocity_y = player:get_physics_body():get_linear_velocity()
        local dot_product = math.dot(normal_x, normal_y, self_velocity_x, self_velocity_y)

        local direction_x = self_velocity_x - 2 * dot_product * normal_x
        local direction_y = self_velocity_y - 2 * dot_product * normal_y

        local restitution = 1.1
        local velocity_magnitude = math.magnitude(self_velocity_x, self_velocity_y)
        player._bounce_impulse_x = -normal_x * dot_product
        player._bounce_impulse_y = -normal_y * dot_product
        player._should_apply_bounce_impulse = true
    end)

    self._body:signal_connect("collision_end", function(self_body, other_body, normal_x, normal_y, contact)
        local player = other_body:get_user_data()
        normal_x, normal_y = -normal_x, -normal_y
        player._should_apply_bounce_impulse = false
    end)
end

--- @brief
function ow.BouncePad:draw()
    rt.Palette.PINK:bind()
    self._body:draw()
end