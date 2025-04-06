
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
        if player ~= nil and player.bounce ~= nil then
            player:bounce(normal_x, normal_y)
        end
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