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
    self._world = stage:get_physics_world()
    self._body = object:create_physics_body(self._world)
    self._body:set_is_sensor(true)

    local bounce_group = rt.settings.player.bounce_collision_group
    self._body:set_collides_with(bounce_group)
    self._body:set_collision_group(bounce_group)

    self._blocked = false
    self._body:signal_connect("collision_start", function(_, other_body)
        dbg("called")
        self._body:signal_set_is_blocked("collision_start", true)
        self._world:signal_connect("step", function()
            self._body:signal_set_is_blocked("collision_start", false)
            return meta.DISCONNECT_SIGNAL
        end)
        self._stage:get_active_checkpoint():spawn()
    end)
end

--- @brief
function ow.KillPlane:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    rt.Palette.RED:bind()
    self._body:draw()
end