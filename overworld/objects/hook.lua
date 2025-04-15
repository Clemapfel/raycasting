rt.settings.overworld.hook = {
    cooldown = 0.4
}

--- @class ow.Hook
ow.Hook = meta.class("OverworldHook", rt.Drawable)

--- @brief
function ow.Hook:instantiate(object, stage, scene)
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world()),
        _joint = nil,
        _deactivated = false,
        _input = rt.InputSubscriber()
    })

    local hook = self
    self._body:set_is_sensor(true)
    self._body:add_tag("slippery")
    self._body:set_collides_with(bit.bor(
        rt.settings.overworld.player.player_collision_group,
        rt.settings.overworld.player.player_outer_body_collision_group
    ))

    self._body:signal_connect("collision_start", function(self, player_body)
        local player = player_body:get_user_data()

        if hook._joint == nil and not hook._deactivated then

            player:set_jump_allowed(true) -- mid-air jumpt to escape

            local vx, vy = player:get_velocity() -- maintain upwards momentum
            if vy > 0 then vy = 0 end
            player:set_velocity(0, 0)

            player:teleport_to(self:get_center_of_mass())
            scene:get_camera():move_to(self:get_center_of_mass())

            if player._jump_button_is_down ~= true then -- buffered jump: instantly jump again
                stage:get_physics_world():signal_connect("step", function()
                    if not self._deactivated then
                        local self_x, self_y = self:get_center_of_mass()
                        hook._joint = love.physics.newDistanceJoint(
                            self:get_native(),
                            player:get_physics_body():get_native(),
                            self_x, self_y,
                            self_x, self_y
                        )
                        return meta.DISCONNECT_SIGNAL
                    end
                end)

                local player_signal_id
                player_signal_id = player:signal_connect("jump", function()
                    hook:_unhook()
                    player:signal_disconnect("jump", player_signal_id)
                end)
            else
                player:bounce(0, -1)
            end

            hook._deactivated = true
        end
    end)

    self._body:signal_connect("collision_end", function(self, player_body)
        local player = player_body:get_user_data()
        hook._deactivated = false
        player:set_jump_allowed(nil)
    end)

    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputButton.DOWN then
            self:_unhook()
        end
    end)
end

--- @brief
function ow.Hook:_unhook()
    if self._joint ~= nil then
        self._joint:destroy()
        self._joint = nil
    end
end

--- @brief
function ow.Hook:draw()
    rt.Palette.PURPLE:bind()
    self._body:draw()
end
