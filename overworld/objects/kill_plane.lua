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
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)

    self._state = _state_inactive


    self._body:signal_connect("collision_start", function(_, other_body)
        assert(other_body:has_tag("player"))

        -- freeze camera and player
        local camera = self._scene:get_camera()
        self._scene:set_camera_mode(ow.CameraMode.MANUAL)
        camera:move_to(camera:get_position())

        local player = self._scene:get_player()
        local vx, vy = player:get_velocity()
        player:set_velocity(0, vy)
        player:disable()

        self._player = player
        self._state = _state_waiting_for_leave_bottom
    end)
end

--- @brief
function ow.KillPlane:update()
    if self._state == _state_inactive then
        return
    elseif self._state == _state_waiting_for_leave_bottom then
        local player = self._scene:get_player()
        local camera = self._scene:get_camera()
        local player_x, player_y = camera:world_xy_to_screen_xy(player:get_position())
        local camera_w, camera_h = camera:get_size()

        if player_y > camera_h then -- player left screen
            self._player:get_last_player_spawn():spawn()
            self._state = _state_inactive
        end
    end
end

--- @brief
function ow.KillPlane:draw()
    rt.Palette.RED:bind()
    self._body:draw()
end