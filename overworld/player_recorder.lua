require "common.player"
require "common.input_manager"
require "common.spline"
require "common.path"

require "overworld.player_recorder_body"

rt.settings.overworld.player_recorder = {
    snapshot_frequency = 60, -- n per second
    spline_quantization_max_n_steps = 10e5
}

--- @class ow.PlayerRecorder
ow.PlayerRecorder = meta.class("PlayerRecorder")

local _STATE_IDLE = "idle"
local _STATE_RECORDING = "recording"
local _STATE_PLAYBACK = "playback"

--- @brief
function ow.PlayerRecorder:instantiate(stage, scene)
    meta.assert(stage, ow.Stage, scene, ow.OverworldScene)

    self._stage = stage
    self._scene = scene
    self._player = scene:get_player()

    self._position_data = {}
    self._input_data = {}

    self._input = rt.InputSubscriber()
    self._update_elapsed = 0

    self._path_duration = 0
    self._path_elapsed = 0
    self._path_n_snapshots = 0

    self._position_interpolation = nil -- rt.Spline

    self._state = _STATE_IDLE

    self._body = ow.PlayerRecorderBody(self, self._stage, self._scene)
end


--- @brief
function ow.PlayerRecorder:_snapshot(step)
    local px, py = self._player:get_physics_body():get_position()
    for x in range(px, py) do
        table.insert(self._position_data, x)
    end

    for x in range(
        self._input:get_is_down(rt.InputAction.UP),
        self._input:get_is_down(rt.InputAction.RIGHT),
        self._input:get_is_down(rt.InputAction.DOWN),
        self._input:get_is_down(rt.InputAction.LEFT),
        self._input:get_is_down(rt.InputAction.SPRINT),
        self._input:get_is_down(rt.InputAction.JUMP),
        self._player:get_is_bubble()
    ) do
        table.insert(self._input_data, x)
    end

    self._path_duration = self._path_duration + step
    self._path_n_snapshots = self._path_n_snapshots + 1
end

--- @brief
function ow.PlayerRecorder:record()
    if self._state == _STATE_RECORDING then return end
    self._state = _STATE_RECORDING
    self:clear()
end

--- @brief
function ow.PlayerRecorder:clear()
    require "table.clear"
    self._path_duration = 0
    table.clear(self._position_data)
    table.clear(self._input_data)
end

--- @brief
function ow.PlayerRecorder:play()
    self:_snapshot(0)

    if self._state ~= _STATE_PLAYBACK then
        self._position_interpolation = rt.Spline(self._position_data)
        self._to_render = {}

        local step = 2 * 1 / rt.settings.overworld.player_recorder.snapshot_frequency

        -- downsample if necessary
        local n_steps = math.ceil(self._path_duration / step)
        while n_steps > rt.settings.overworld.player_recorder.spline_quantization_max_n_steps do
            step = step * 0.95
            n_steps = math.ceil(self._path_duration / step)
        end

        for i = 1, n_steps do
            local t = (i - 1) / n_steps
            local x, y = self._position_interpolation:at(t)
            table.insert(self._to_render, x)
            table.insert(self._to_render, y)
        end
    end

    self._state = _STATE_PLAYBACK
    self._path_elapsed = 0
    self._path_x, self._path_y = self._position_interpolation:at(0)
    self._body:initialize(self._path_x, self._path_y)
    self._body:relax()
end

--- @brief
function ow.PlayerRecorder:update(delta)
    local step = 1 / rt.settings.overworld.player_recorder.snapshot_frequency
    if self._state == _STATE_RECORDING then
        self._update_elapsed = self._update_elapsed + delta
        while self._update_elapsed >= step do
            self:_snapshot(step)
            self._update_elapsed = self._update_elapsed - step
        end
    elseif self._state == _STATE_PLAYBACK then
        self._path_elapsed = self._path_elapsed + delta

        -- get numerical derivative, more stable than analytical because
        -- of fixed timestep used in physics sim
        local t_now = self._path_elapsed / self._path_duration
        local t_next = (self._path_elapsed + delta) / self._path_duration
        local x1, y1 = self._position_interpolation:at(t_now)
        local x2, y2 = self._position_interpolation:at(math.min(1, t_next))

        -- safety check for numerical error accumulating
        local px, py = self._body:get_position()
        if math.distance(px, py, x1, y1) > 0.5 * rt.settings.player.radius then
            self._body:set_position(x1, y1)
        end

        self._body:set_velocity(
            (x2 - x1) / delta,
            (y2 - y1) / delta
        )

        if t_now >= 1 then
            self._path_elapsed = 0
            self._body:set_position(self._position_interpolation:at(0))
            self._state = _STATE_PLAYBACK
        end

        local i = 7 * math.round(math.mix(0, self._path_n_snapshots - 1, t_now)) + 1

        self._body:update_input(
            self._input_data[i+0], -- up
            self._input_data[i+1], -- right
            self._input_data[i+2], -- down
            self._input_data[i+3], -- left
            self._input_data[i+4], -- sprint
            self._input_data[i+5]  -- jump
        )
        self._body:update(delta)
    end
end

--- @brief
function ow.PlayerRecorder:draw()
    if self._state == _STATE_PLAYBACK then
        love.graphics.setColor(0.5, 0.5, 0.5, 1)
        love.graphics.line(self._to_render)

        love.graphics.setColor(1, 1, 1, 1)
        self._body:draw()
    end
end
