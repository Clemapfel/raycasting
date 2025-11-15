require "common.interpolation_functions"

rt.settings.impulse_manager = {
    bpm = 120,

    pulse_duration = 1 / 2, -- fraction of bpm
    pulse_attack = 0.25, -- fraction
    pulse_decay = 0.25,

    beat_duration = 1 / 8, -- fraction of bpm
    beat_attack = 0.05, -- fraction of total duration
    beat_decay = 0,
    
    max_brightness_factor = 1.4
}

--- @class rt.ImpulseManager
rt.ImpulseManager = meta.class("ImpulseManager")

--- @class rt.ImpulseSubscriber
rt.ImpulseSubscriber = meta.class("ImpulseSubscriber")
meta.add_signals(rt.ImpulseSubscriber,
    "beat",
    "pulse"
)

--- @brief
function rt.ImpulseManager:instantiate()
    self._subscribers = meta.make_weak({})
    self._elapsed = 0
end

--- @brief
function rt.ImpulseManager:beat()
    dbg("beat")
    local timestamp = love.timer.getTime()
    for subscriber in values(self._subscribers) do
        subscriber._beat_start = timestamp
        subscriber:signal_emit("beat")
    end
end

--- @brief
function rt.ImpulseManager:pulse()
    dbg("pulse")
    dbg(#self._subscribers)
    local timestamp = love.timer.getTime()
    for subscriber in values(self._subscribers) do
        subscriber._pulse_start = timestamp
        subscriber:signal_emit("pulse")
    end
end

rt.ImpulseManager = rt.ImpulseManager() -- singleton instance

-- ###

local _settings = rt.settings.impulse_manager

--- @brief
function rt.ImpulseSubscriber:instantiate()
    table.insert(rt.ImpulseManager._subscribers, self)

    self._pulse_start = math.huge
    self._beat_start = math.huge
end

local _bpm_fraction_to_seconds = function(t)
    return t / _settings.bpm * 60
end

--- @brief
function rt.ImpulseSubscriber:get_pulse()
    local delta = love.timer.getTime() - self._pulse_start
    return rt.InterpolationFunctions.ENVELOPE(
        delta / _bpm_fraction_to_seconds(_settings.pulse_duration),
        _settings.pulse_attack,
        _settings.pulse_decay
    )
end

--- @brief
function rt.ImpulseSubscriber:get_beat()
    local delta = love.timer.getTime() - self._beat_start
    return rt.InterpolationFunctions.ENVELOPE(
        delta / _bpm_fraction_to_seconds(_settings.beat_duration),
        _settings.beat_attack,
        _settings.beat_decay
    )
end