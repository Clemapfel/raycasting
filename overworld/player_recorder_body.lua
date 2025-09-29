require "common.smoothed_motion_1d"

rt.settings.overworld.player_recorder_body = {
    input_motion_speed = 3
}

--- @class ow.PlayerRecorderBody
ow.PlayerRecorderBody = meta.class("PlayerRecorderBody")

local _NOT_PRESSED = 0
local _PRESSED = 1

--- @brief
function ow.PlayerRecorderBody:instantiate(player_recorder, stage, scene)
    meta.assert(
        player_recorder, ow.PlayerRecorder,
        stage, ow.Stage,
        scene, ow.OverworldScene
    )

    self._recorder = player_recorder
    self._stage = stage
    self._scene = scene

    self._radius = rt.settings.player.radius

    local speed = rt.settings.overworld.player_recorder_body.input_motion_speed
    self._up_pressed_motion = rt.SmoothedMotion1D(_NOT_PRESSED, speed)
    self._right_pressed_motion = rt.SmoothedMotion1D(_NOT_PRESSED, speed)
    self._down_pressed_motion = rt.SmoothedMotion1D(_NOT_PRESSED, speed)
    self._left_pressed_motion = rt.SmoothedMotion1D(_NOT_PRESSED, speed)
end

--- @brief
function ow.PlayerRecorderBody:initialize(x, y)
    if self._body == nil then
        self._body = b2.Body(
            self._stage:get_physics_world(),
            b2.BodyType.DYNAMIC,
            x, y,
            b2.Circle(0, 0, self._radius)
        )

        local player_settings = rt.settings.player
        self._body:set_collides_with(bit.bnot(bit.bor(
            player_settings.player_collision_group,
            player_settings.player_outer_body_collision_group,
            player_settings.bounce_collision_group,
            player_settings.ghost_collision_group
        )))
        self._body:set_collision_group(player_settings.exempt_collision_group)
        self._body:signal_connect("collision_start", function(_, other_body, normal_x, normal_y, x1, y1, x2, y2)
            if x1 ~= nil then
                self._stage:get_blood_splatter():add(x1, y1, self._radius, 0, 0)
            end
        end)
    else
        self:set_position(x, y)
    end
end

--- @brief
function ow.PlayerRecorderBody:update_input(
    up_pressed,
    right_pressed,
    down_pressed,
    left_pressed,
    sprint_pressed,
    jump_pressed
)
    if up_pressed then
        self._up_pressed_motion:set_target_value(_PRESSED)
    else
        self._up_pressed_motion:set_target_value(_NOT_PRESSED)
    end

    if right_pressed then
        self._right_pressed_motion:set_target_value(_PRESSED)
    else
        self._right_pressed_motion:set_target_value(_NOT_PRESSED)
    end

    if down_pressed then
        self._down_pressed_motion:set_target_value(_PRESSED)
    else
        self._down_pressed_motion:set_target_value(_NOT_PRESSED)
    end

    if left_pressed then
        self._left_pressed_motion:set_target_value(_PRESSED)
    else
        self._left_pressed_motion:set_target_value(_NOT_PRESSED)
    end
end

--- @brief
function ow.PlayerRecorderBody:update(delta)
    for to_update in range(
        self._up_pressed_motion,
        self._right_pressed_motion,
        self._down_pressed_motion,
        self._left_pressed_motion
    ) do
        to_update:update(delta)
    end
end

--- @brief
function ow.PlayerRecorderBody:relax()
    for motion in range(
        self._up_pressed_motion,
        self._right_pressed_motion,
        self._down_pressed_motion,
        self._left_pressed_motion
    ) do
        motion:set_value(_NOT_PRESSED)
        motion:set_target_value(_NOT_PRESSED)
    end
end

--- @brief
function ow.PlayerRecorderBody:set_position(x, y)
    self._body:set_position(x, y)
end

--- @brief
function ow.PlayerRecorderBody:get_position()
    return self._body:get_position()
end

--- @brief
function ow.PlayerRecorderBody:set_velocity(dx, dy)
    self._body:set_velocity(dx, dy)
end

--- @brief
function ow.PlayerRecorderBody:draw()

    love.graphics.setLineWidth(2)
    love.graphics.setColor(1, 1, 1, 1)
    local r = 2 * self._radius
    local x, y = self._body:get_position()

    for motion_nx_ny in range(
        { self._up_pressed_motion, 0, -1 },
        { self._right_pressed_motion, 1, 0 },
        { self._down_pressed_motion, 0, 1 },
        { self._left_pressed_motion, -1, 0 }
    ) do
        local motion, nx, ny = table.unpack(motion_nx_ny)
        local v = motion:get_value()
        love.graphics.line(
            x,
            y,
            x + nx * r * v,
            y + ny * r * v
        )
    end

    self._body:draw()
end