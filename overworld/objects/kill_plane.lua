ow.KillPlane = meta.class("KillPlane")

--- @class ow.KillPlaneTarget
ow.KillPlaneTarget = meta.class("KillPlaneTarget") -- dummy

local _state_default = 1
local _state_waiting_for_player = 2
local _state_waiting_for_camera = 3
local _state_waiting_for_center = 4

--- @brief
function ow.KillPlane:instantiate(object, stage, scene)
    self._stage = stage
    self._scene = scene

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)

    local target = object:get_object("target", true)
    self._target_x = target.x
    self._target_y = target.y
    assert(meta.is_number(self._target_x))

    self._state = _state_default
    self._player = nil

    self._body:signal_connect("collision_start", function(_, other_body)
        assert(other_body:has_tag("player"))
        self._state = _state_waiting_for_player
        self._player = other_body:get_user_data()

        -- lock camera and disable player
        self._player:disable()
        local vx, vy = self._player:get_velocity()
        self._player:set_velocity(0, vy)

        self._camera = scene:get_camera()
        self._camera_x, self._camera_y = self._camera:get_position()
    end)
end

--- @brief
function ow.KillPlane:update(delta)
    if self._state == _state_default then return end

    if self._state == _state_waiting_for_player then

        -- freeze camera
        self._camera:set_position(self._camera_x, self._camera_y)

        -- check if player is off screen
        local player_x, player_y = self._player:get_position()
        player_y = player_y - self._player:get_radius()

        local camera_x, camera_y = self._camera:get_position()
        local camera_w, camera_h = self._camera:get_size()

        player_x, player_y = self._camera:world_xy_to_screen_xy(player_x, player_y)

        if player_y > camera_h then
            self._player:teleport_to(self._target_x, self._target_y)
            self._player:set_is_frozen(true)

            self._scene:set_camera_mode(ow.CameraMode.MANUAL)
            self._camera:move_to(self._target_x, self._target_y + 0.5 * camera_h + self._player:get_radius() * 2)
            self._state = _state_waiting_for_camera
        end
    elseif self._state == _state_waiting_for_camera then
        local vx, vy = self._camera:get_velocity()
        if math.magnitude(vx, vy) < 1 then
            self._player:enable()
            self._state = _state_waiting_for_center
        end
    elseif self._state == _state_waiting_for_center then
        local camera_w, camera_h = self._camera:get_size()
        local center_x, center_y = self._camera:screen_xy_to_world_xy(0, 0.5 * camera_h)
        local player_x, player_y = self._player:get_position()

        if player_y >= center_y then
            self._player:set_is_frozen(false)
            self._scene:set_camera_mode(ow.CameraMode.AUTO)
        end

    end
end