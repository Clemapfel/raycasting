require "common.interpolation_functions"

--- @class rt.TimedAnimation
--- @param duration
--- @param start_value
--- @param end_value
--- @param interpolation_function
rt.TimedAnimation = meta.class("TimedAnimation")
meta.add_signals(rt.TimedAnimation, "done")

function rt.TimedAnimation:instantiate(duration, start_value, end_value, interpolation_function, ...)
    if start_value == nil then start_value = 0 end
    if end_value == nil then end_value = 1 end
    if interpolation_function == nil then interpolation_function = rt.InterpolationFunctions.LINEAR end
    meta.assert(duration, "Number", start_value, "Number", end_value, "Number", interpolation_function, "Function")
    meta.install(self, {
        _lower = start_value,
        _upper = end_value,
        _duration = duration,
        _f = interpolation_function,
        _args = {...},
        _should_loop = false,
        _is_reversed = false,
        _direction = ternary(start_value <= end_value, 1, -1),
        _elapsed = 0
    })
end

--- @brief
function rt.TimedAnimation:set_lower(lower)
    self._lower = lower
end

--- @brief
function rt.TimedAnimation:set_upper(upper)
    self._upper = upper
end

--- @brief
function rt.TimedAnimation:set_direction(reversed)
    self._is_reversed = reversed
end

--- @brief
function rt.TimedAnimation:set_duration(duration)
    self._duration = duration
end

--- @brief
function rt.TimedAnimation:set_should_loop(b)
    self._should_loop = b
end

--- @brief
function rt.TimedAnimation:update(delta)
    local before = self._elapsed
    self._elapsed = self._elapsed + delta
    if before < self._duration and self._elapsed > self._duration then
        self:signal_emit("done")
    end

    return self:get_is_done()
end

--- @brief
function rt.TimedAnimation:get_value()
    local x = self._elapsed / self._duration
    if self._should_loop then x = math.fmod(x, 1) end
    local y = self._f(x, table.unpack(self._args))

    local lower, upper = self._lower, self._upper
    if self._is_reversed then
        lower, upper = self._upper, self._lower
    end

    return lower + y * self._direction * math.abs(upper - lower)
end

--- @brief
function rt.TimedAnimation:get_fraction()
    local x = self._elapsed / self._duration
    if self._should_loop then x = math.fmod(x, 1) end
    return self._f(x, table.unpack(self._args))
end

--- @brief
function rt.TimedAnimation:get_is_done()
    return self._elapsed >= self._duration
end

--- @brief
function rt.TimedAnimation:get_elapsed()
    return math.clamp(self._elapsed, 0, self._duration)
end

--- @brief
function rt.TimedAnimation:get_duration()
    return self._duration
end

--- @brief
function rt.TimedAnimation:reset()
    self._elapsed = 0
end

--- @brief
function rt.TimedAnimation:skip()
    self._elapsed = self._duration
    self:signal_emit("done")
end

--- @brief
function rt.TimedAnimation:set_elapsed(elapsed)
    self._elapsed = elapsed
end

--- @brief
function rt.TimedAnimation:set_fraction(f)
    self._elapsed = f * self._duration
end
