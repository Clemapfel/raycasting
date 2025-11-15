require "common.interpolation_functions"

rt.settings.overworld.overworld_object = {
    pulse_duration = 1 / 120 * 2,
    pulse_attack = 0.1, -- fraction
    pulse_decay = 0.1,

    beat_duration = 1 / 120,
    beat_attack = 0.05, -- fraction
    beat_decay = 0
}

--- @class ow.ImpulseManager
ow.ImpulseManager = meta.class("ImpulseManager")

--- @class ow.ImpulseSubscriber
ow.ImpulseSubscriber = meta.class("ImpulseSubscriber")
meta.add_signals(ow.ImpulseSubscriber,
    "beat",
    "pulse"
)

--- @brief
function ow.ImpulseManager:instantiate()
    self._subscribers = meta.make_weak({})
end

--- @brief
function ow.ImpulseManager:beat()
    local timestamp = love.timer.getTime()
    for subscriber in values(self._subscribers) do
        subscriber._beat_start = timestamp
        subscriber:signal_emit("beat")
    end
end

--- @brief
function ow.ImpulseManager:pulse()
    local timestamp = love.timer.getTime()
    for subscriber in values(self._subscribers) do
        subscriber._pulse_start = timestamp
        subscriber:signal_emit("pulse")
    end
end

ow.ImpulseManager = ow.ImpulseManager() -- singleton instance

-- ###

local _settings = rt.settings.overworld.overworld_object

--- @brief
function ow.ImpulseSubscriber:instantiate()
    table.insert(ow.ImpulseManager._subscribers, self)

    self._pulse_start = math.huge
    self._beat_start = math.huge
end

--- @brief
function ow.ImpulseSubscriber:get_pulse_value()
    local delta = love.timer.getTime() - self._pulse_start
    return rt.InterpolationFunctions.ENVELOPE(
        delta / _settings.pulse_duration,
        _settings.pulse_attack,
        _settings.pulse_decay
    )
end

--- @brief
function ow.ImpulseSubscriber:get_beat_value()
    local delta = love.timer.getTime() - self._beat_start
    return rt.InterpolationFunctions.ENVELOPE(
        delta / _settings.beat_duration,
        _settings.beat_attack,
        _settings.beat_decay
    )
end