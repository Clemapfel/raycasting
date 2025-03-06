require "common.input_subscriber"
require "physics.physics"

rt.settings.overworld.player = {
    radius = 10,
    max_velocity = 150, -- px / s
}

--- @class
ow.Player = meta.class("OverworldPlayer")

--- @brief
function ow.Player:instantiate(stage)
    meta.assert(stage, ow.Stage)
    local world = stage:get_physics_world()
    local player_x, player_y = stage:get_player_spawn()
    meta.install(self, {
        _world = world,
        _body = b2.Body(
            world, b2.BodyType.KINEMATIC,
            player_x, player_y,
            b2.Circle(0, 0, rt.settings.overworld.player.radius)
        ),
        _input = rt.InputSubscriber(),
        _velocity_angle = 0,
        _velocity_magnitue = 0,

        _up_pressed = false,
        _down_pressed = false,
        _left_pressed = false,
        _right_pressed = false
    })

    self._input:signal_connect("pressed", function(_, which)
        self:_handle_button(which, true)
    end)

    self._input:signal_connect("released", function(_, which)
        self:_handle_button(which, false)
    end)
end

--- @brief
function ow.Player:draw()
    self._body:draw()

    local r = rt.settings.overworld.player.radius
    local x, y = self._body:get_position()

    love.graphics.setPointSize(5)
    if self._up_pressed then
        love.graphics.points(x, y - r)
    end

    if self._right_pressed then
        love.graphics.points(x + r, y)
    end

    if self._down_pressed then
        love.graphics.points(x, y + r)
    end

    if self._left_pressed then
        love.graphics.points(x - r, y)
    end
end

--- @brief
function ow.Player:update(delta)
    self._world._native:push(self._body, self._body:get_position())
end

--- @brief
function ow.Player:_handle_button(which, pressed_or_released)
    local max_velocity = rt.settings.overworld.player.max_velocity

    local vx, vy = self._body:get_velocity()
    if which == rt.InputButton.LEFT then
        if pressed_or_released then
            vx = -1 * max_velocity
        else
            vx = 0
        end

        self._left_pressed = pressed_or_released
    end

    if which == rt.InputButton.RIGHT then
        if pressed_or_released then
            vx = 1 * max_velocity
        else
            vx = 0
        end

        self._right_pressed = pressed_or_released
    end

    if which == rt.InputButton.UP then
        if pressed_or_released then
            vy = -1 * max_velocity
        else
            vy = 0
        end

        self._up_pressed = pressed_or_released
    end

    if which == rt.InputButton.DOWN then
        if pressed_or_released then
            vy = 1 * max_velocity
        else
            vy = 0
        end

        self._down_pressed = pressed_or_released
    end

    self._body:set_velocity(vx, vy)
end
