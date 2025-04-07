
--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    meta.install(self, {
        _world = stage:get_physics_world(),
        _body = object:create_physics_body(stage:get_physics_world()),
        _cooldown = false,
    })

    self._body:set_restitution(2)
    local i = 0
    self._body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y, x1, y1, x2, y2, contact)
        local player = other_body:get_user_data()
        if player == nil then return end

        if self._cooldown == false then
            contact:setRestitution(10)
            self._cooldown = true
        else
            player:set_bounce(normal_x, normal_y, 100)
            contact:setRestitution(0)
        end
    end)

    self._body:signal_connect("collision_end", function(self_body, other_body)
        self._cooldown = false
    end)
end

--- @brief
function ow.BouncePad:draw()
    rt.Palette.PINK:bind()
    self._body:draw()
end