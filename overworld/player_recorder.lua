require "common.player"
require "common.input_manager"
require "common.path"

require "overworld.player_recorder_body"

rt.settings.overworld.player_recorder = {
    delta_time_step_factor = 0.5,
    correction_threshold = 1 / 3 * rt.settings.player.radius, -- pixels
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

    -- recording
    self._position_data = {}
    self._is_bubble_data = {}
    self._path_duration = 0

    -- playback
    self._path_elapsed = 0

    self._state = _STATE_IDLE

    self._body = ow.PlayerRecorderBody(self._stage, self._scene)
    self._body:initialize(self._scene:get_player():get_position())
    self._body:get_physics_body():set_is_enabled(false)
end

--- @brief
function ow.PlayerRecorder:_snapshot(step)
    local px, py = self._player:get_physics_body():get_position()

    for x in range(px, py) do
        table.insert(self._position_data, x)
    end

    table.insert(self._is_bubble_data, self._player:get_is_bubble())
    self._path_duration = self._path_duration + step
end

--- @brief
function ow.PlayerRecorder:record()
    if self._state == _STATE_RECORDING then return end
    self._state = _STATE_RECORDING

    self._path_duration = 0
    self._position_data = {}
    self._recording_elapsed = 0
    self._path = nil
    self._body:get_physics_body():set_is_enabled(false)
end

--- @brief
function ow.PlayerRecorder:play()
    self._state = _STATE_PLAYBACK

    if self._path == nil then
        self._path = rt.Path(self._position_data)
    end

    self._path_elapsed = 0
    self._body:initialize(self._path:at(0))
    self._body:get_physics_body():set_is_enabled(true)
end

--- @brief
function ow.PlayerRecorder:update(delta)
    local step = rt.SceneManager:get_timestep() * rt.settings.overworld.player_recorder.delta_time_step_factor

    if self._state == _STATE_IDLE then return end
        -- noop
    if self._state == _STATE_RECORDING then
        local n_steps = 0

        self._recording_elapsed = self._recording_elapsed + delta
        while self._recording_elapsed > step do
            self:_snapshot(step)
            self._recording_elapsed = self._recording_elapsed - step

            n_steps = n_steps + 1
            if n_steps > 16 then break end -- for safety
        end
    elseif self._state == _STATE_PLAYBACK then
        local t = self._path_elapsed / self._path_duration
        if t == 0 or t >= 1 then
            self._path_elapsed = 0
            self._body:set_position(self._path:at(0))
        end

        local t_next = math.min(1, (self._path_elapsed + delta) / self._path_duration)
        local x1, y1 = self._path:at(t)
        local x2, y2 = self._path:at(t_next)
        self._body:set_velocity(
            (x2 - x1) / delta,
            (y2 - y1) / delta
        )

        local n = #self._is_bubble_data
        local is_bubble = self._is_bubble_data[math.clamp(math.floor(t * n), 1, n)]
        self._body:set_is_bubble(is_bubble)
        self._body:update(delta)

        self._path_elapsed = self._path_elapsed + delta

        -- manually set position to prevent numerical drift from velocity
        if math.distance(x1, y1, self._body:get_physics_body():get_position()) > rt.settings.overworld.player_recorder.correction_threshold then
            self._body:set_position(x1, y1)
        end
    end
end

--- @brief
function ow.PlayerRecorder:draw()
    if self._state == _STATE_PLAYBACK then
        love.graphics.setColor(1, 1, 1, 1)
        self._body:draw()
    end

    if self._path ~= nil then
        love.graphics.line(self._path:get_points())
    end
end
