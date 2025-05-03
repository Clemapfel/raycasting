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
    self._elapsed = math.huge

    self._state = _state_inactive

    self._body:signal_connect("collision_start", function(_, other_body)
        assert(other_body:has_tag("player"))

        if self._state ~= _state_inactive then return end

        -- freeze camera and player
        local camera = self._scene:get_camera()
        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        camera:move_to(camera:get_position())

        local player = self._scene:get_player()
        player.do_not_update_trail = true
        local vx, vy = player:get_velocity()
        player:set_gravity(1)
        player:set_velocity(0, 0)
        player:reset_flow(0)
        player:disable()

        self._player = player
        self._state = _state_waiting_for_leave_bottom
        self._elapsed = 0
    end)
end

--- @brief
function ow.KillPlane:update(delta)
    if self._state == _state_inactive then
        return
    elseif self._state == _state_waiting_for_leave_bottom then
        self._elapsed = self._elapsed + delta

        local player = self._scene:get_player()
        local camera = self._scene:get_camera()
        local player_x, player_y = camera:world_xy_to_screen_xy(player:get_position())
        local camera_w, camera_h = camera:get_size()

        if player_y > camera_h or self._elapsed > rt.settings.overworld.kill_plane.max_respawn_duration then -- player left screen
            self._stage:get_active_checkpoint():spawn()
            self._state = _state_inactive
        end
    end
end

--- @brief
function ow.KillPlane:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    rt.Palette.RED:bind()
    self._body:draw()
end