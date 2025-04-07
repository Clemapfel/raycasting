
--- @class ow.BouncePad
ow.BouncePad = meta.class("BouncePad", rt.Drawable)

--- @brief
function ow.BouncePad:instantiate(object, stage, scene)
    meta.install(self, {
        _world = stage:get_physics_world(),
        _body = object:create_physics_body(stage:get_physics_world()),
        _cooldown = false,
    })


    local blocking_body = nil
    self._body:set_collides_with(b2.CollisionGroup.GROUP_16)
    self._body:signal_connect("collision_start", function(self_body, other_body, normal_x, normal_y, x1, y1, x2, y2, contact)
        local player = other_body:get_user_data()
        if player == nil then return end

        if player:get_is_ragdoll() then
            contact:setRestitution(1)
            return
        end

        blocking_body = other_body
        if self._cooldown == false then
            player:bounce(normal_x, normal_y)
            self._cooldown = true
        end
    end)

    self._world:signal_connect("step", function()
        self._cooldown = false
    end)
end

--- @brief
function ow.BouncePad:draw()
    rt.Palette.PINK:bind()
    self._body:draw()
end