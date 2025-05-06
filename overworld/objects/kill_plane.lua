rt.settings.overworld.kill_plane = {
    max_respawn_duration = 2
}

--- @class ow.KillPlane
ow.KillPlane = meta.class("KillPlane")

--- @class ow.KillPlaneTarget
ow.KillPlaneTarget = meta.class("KillPlaneTarget") -- dummy

local _state_inactive = 1
local _state_waiting_for_leave_bottom = 2
local _state_waiting_for_enter_top = 3

--- @brief
function ow.KillPlane:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)

    self._body:signal_connect("collision_start", function(_, other_body)
        self._stage:get_active_checkpoint():spawn()
    end)
end

--- @brief
function ow.KillPlane:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    rt.Palette.RED:bind()
    self._body:draw()
end