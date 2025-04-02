--- @class ow.Hook
ow.Hook = meta.class("OverworldHook", rt.Drawable)

--- @brief
function ow.Hook:instantiate(object, stage, scene)
    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world()),
        _joint = nil,
        _input = rt.InputSubscriber()
    })

    local hook = self
    self._body:set_is_sensor(true)
    self._body:set_collides_with(b2.CollisionGroup.GROUP_16)
    self._body:signal_connect("collision_start", function(self, player)
        if hook._joint == nil then
            local signal_id
            signal_id = stage:get_physics_world():signal_connect("step", function()
                local self_x, self_y = self:get_center_of_mass()
                local player_x, player_y = player:get_position()
                player:set_position(self_x, self_y)
                hook._joint = love.physics.newDistanceJoint(
                    self:get_native(),
                    player:get_native(),
                    self_x, self_y,
                    self_x, self_y
                )
                stage:get_physics_world():signal_disconnect("step", signal_id)
            end)

            self._player = player:get_user_data()
            player:get_user_data():signal_connect("jump", function()
                hook._joint:destroy()
                hook._joint = nil
            end)
            player:get_user_data():set_jump_allowed(true) -- override
        end
    end)
end

--- @brief
function ow.Hook:draw()
    self._body:draw()
end

function ow.Hook:update()
    if self._player ~= nil then
        self._player:set_jump_allowed(true) -- override
    end
end
