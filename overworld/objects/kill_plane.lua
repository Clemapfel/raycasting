--- @class ow.KillPlane
ow.KillPlane = meta.class("KillPlane")

--- @brief
function ow.KillPlane:instantiate(object, stage, scene)
    local target = object:get_object("target", true)
    local signal_id
    signal_id = stage:signal_connect("initialized", function(stage)
        meta.install(self, {
            _target = target
        })

        self._respawn_x = self._target.x
        self._respawn_y = self._target.y

        stage:signal_disconnect("initialized", signal_id)
    end)

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)
    self._body:signal_connect("collision_start", function(_, other_body)
        local player = other_body:get_user_data()
        player:kill(self._respawn_x, self._respawn_y)
    end)
end

--- @brief
function ow.KillPlane:draw()
    rt.Palette.RED:bind()
    self._body:draw()
end