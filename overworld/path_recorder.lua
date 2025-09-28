require "common.player"
require "common.input_manager"

rt.settings.overworld.path_recorder = {
    snapshot_frequency = 60, -- n per second
}

--- @class ow.PathRecorder
ow.PathRecorder = meta.class("PathRecorder")

local _position_x = 0
local _position_y = 1
local _up_pressed = 0
local _right_pressed = 1
local _down_pressed = 2
local _left_pressed = 3
local _sprint_pressed = 4
local _jump_pressed = 5

--- @brief
function ow.PathRecorder:instantiate(player)
    meta.assert(player, ow.Player)
    self._player = player
    self._is_recording = false

    self._position_data = {}
    self._input_data = {}

    self._input = rt.InputSubscriber()
    self._elapsed = 0
end

local _input_buffer = {}
local _position_buffer = {}

--- @brief
function ow.PathRecorder:_snapshot()
    _position_buffer[_position_x], _position_buffer[_position_y] = self._player:get_physics_body():get_position()

    _input_buffer[_up_pressed] = self._input:get_is_down(rt.InputAction.UP)
    _input_buffer[_right_pressed] = self._input:get_is_down(rt.InputAction.RIGHT)
    _input_buffer[_down_pressed] = self._input:get_is_down(rt.InputAction.DOWN)
    _input_buffer[_left_pressed] = self._input:get_is_down(rt.InputAction.LEFT)
    _input_buffer[_sprint_pressed] = self._input:get_is_down(rt.InputAction.SPRINT)
    _input_buffer[_jump_pressed] = self._input:get_is_down(rt.InputAction.JUMP)

    for x in values(_position_buffer) do
        table.insert(self._position_data, x)
    end

    for x in values(_input_buffer) do
        table.insert(self._input_data, x)
    end
end

--- @brief
function ow.PathRecorder:set_is_recording(b)
    self._is_recording = b
end

--- @brief
function ow.PathRecorder:get_is_recording()
    return self._is_recording
end

--- @brief
function ow.PathRecorder:clear()
    require "table.clear"
    table.clear(self._position_data)
    table.clear(self._input_data)
end

--- @brief
function ow.PathRecorder:update(delta)
    if self._is_recording then
        self._elapsed = self._elapsed + delta
        local step = 1 / rt.settings.overworld.path_recorder.snapshot_frequency
        while self._elapsed >= step do
            self:_snapshot()
            self._elapsed = self._elapsed - step
        end
    end
end
