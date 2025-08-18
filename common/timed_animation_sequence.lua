--- @class rt.TimedAnimationSequence
rt.TimedAnimationSequence = meta.class("TimedAnimationSequence")
meta.add_signals(rt.TimedAnimationSequence, "done", "animation_changed")

function rt.TimedAnimationSequence:instantiate(...)
    for i = 1, select('#', ...) do
        meta.assert_typeof(select(i, ...), "TimedAnimation", i)
    end

    local animations = {...}
    local cumulative_durations = {}
    local total_duration = 0
    for i, animation in ipairs(animations) do
        total_duration = total_duration + animation:get_duration()
        cumulative_durations[i] = total_duration
    end

    meta.install(self, {
        _animations = animations,
        _cumulative_durations = cumulative_durations,
        _total_duration = total_duration,
        _elapsed = 0,
        _current_animation_index = 1,
        _should_loop = false
    })
end

rt.AnimationChain = function(...)
    local n = select("#", ...)
    if n % 4 ~= 0 then
        rt.error("In rt.AnimationChain: number of arguments is not a multiple of four")
    end

    local animations = {}

    local i = 1
    while i < n do
        local duration = select(i + 0, ...)
        meta.assert_typeof(duration, "Number", i + 0)

        local min = select(i + 1, ...)
        meta.assert_typeof(min, "Number", i + 1)

        local max = select(i + 2, ...)
        meta.assert_typeof(max, "Number", i + 2)

        local f = select(i + 3, ...)
        meta.assert_typeof(f, "Function", i + 3)

        table.insert(animations, rt.TimedAnimation(duration, min, max, f))

        i = i + 4
    end

    return rt.TimedAnimationSequence(table.unpack(animations))
end

--- @brief set whether the chain should loop
function rt.TimedAnimationSequence:set_should_loop(b)
    self._should_loop = b
end

--- @brief
function rt.TimedAnimationSequence:update(delta)
    local before_elapsed = self._elapsed
    local before_index = self._current_animation_index

    self._elapsed = self._elapsed + delta

    local effective_elapsed = self._elapsed
    if self._should_loop then
        effective_elapsed = math.fmod(self._elapsed, self._total_duration)
    end

    local new_index = self:_find_current_animation_index(effective_elapsed)

    if new_index ~= before_index then
        self._current_animation_index = new_index
        self:signal_emit("animation_changed", new_index)
    end

    -- update the current animation with its local elapsed time
    if new_index <= #self._animations then
        local animation = self._animations[new_index]
        local local_start_time = new_index == 1 and 0 or self._cumulative_durations[new_index - 1]
        local local_elapsed = effective_elapsed - local_start_time

        animation:set_elapsed(local_elapsed)
    end

    local is_done = self:get_is_done()
    if not self._should_loop and before_elapsed < self._total_duration and self._elapsed >= self._total_duration then
        self:signal_emit("done")
    end

    return is_done
end

--- @brief get the current value from the active animation
function rt.TimedAnimationSequence:get_value()
    if self:get_is_done() and not self._should_loop then
        return self._animations[#self._animations]:get_value()
    end

    local effective_elapsed = self._elapsed
    if self._should_loop then
        effective_elapsed = math.fmod(self._elapsed, self._total_duration)
    end

    local index = self:_find_current_animation_index(effective_elapsed)

    if index > #self._animations then
        return self._animations[#self._animations]:get_value()
    end

    local animation = self._animations[index]
    local local_start_time = index == 1 and 0 or self._cumulative_durations[index - 1]
    local local_elapsed = effective_elapsed - local_start_time

    animation:set_elapsed(local_elapsed)
    return animation:get_value()
end

--- @brief Find which animation index should be active for given elapsed time
function rt.TimedAnimationSequence:_find_current_animation_index(elapsed)
    for i, cumulative_duration in ipairs(self._cumulative_durations) do
        if elapsed <= cumulative_duration then
            return i
        end
    end

    return #self._animations + 1 -- past the end
end

--- @brief Check if the entire chain is done
function rt.TimedAnimationSequence:get_is_done()
    return not self._should_loop and self._elapsed >= self._total_duration
end

--- @brief Get total elapsed time
function rt.TimedAnimationSequence:get_elapsed()
    return math.clamp(self._elapsed, 0, self._total_duration)
end

--- @brief Get total duration of the chain
function rt.TimedAnimationSequence:get_duration()
    return self._total_duration
end

--- @brief Reset the chain to the beginning
function rt.TimedAnimationSequence:reset()
    self._elapsed = 0
    self._current_animation_index = 1
    for _, animation in ipairs(self._animations) do
        animation:reset()
    end
end

--- @brief Skip to the end of the chain
function rt.TimedAnimationSequence:skip()
    self._elapsed = self._total_duration
    self._current_animation_index = #self._animations
    for _, animation in ipairs(self._animations) do
        animation:skip()
    end
    self:signal_emit("done")
end

--- @brief Set elapsed time directly
function rt.TimedAnimationSequence:set_elapsed(elapsed)
    self._elapsed = elapsed
    self._current_animation_index = self:_find_current_animation_index(
        self._should_loop and math.fmod(elapsed, self._total_duration) or elapsed
    )
end

--- @brief Set elapsed time as fraction of total duration
function rt.TimedAnimationSequence:set_fraction(f)
    self:set_elapsed(f * self._total_duration)
end

--- @brief Get the currently active animation
function rt.TimedAnimationSequence:get_animation()
    if self._current_animation_index <= #self._animations then
        return self._animations[self._current_animation_index]
    end
    return nil
end

--- @brief Get the index of the currently active animation
function rt.TimedAnimationSequence:get_animation_index()
    return self._current_animation_index
end

--- @brief Get progress of the current animation as a fraction [0, 1]
function rt.TimedAnimationSequence:get_local_fraction()
    if self:get_is_done() and not self._should_loop then
        return 1.0
    end

    local effective_elapsed = self._elapsed
    if self._should_loop then
        effective_elapsed = math.fmod(self._elapsed, self._total_duration)
    end

    local index = self:_find_current_animation_index(effective_elapsed)

    if index > #self._animations then
        return 1.0
    end

    local animation = self._animations[index]
    local local_start_time = index == 1 and 0 or self._cumulative_durations[index - 1]
    local local_elapsed = effective_elapsed - local_start_time
    local animation_duration = animation:get_duration()

    if animation_duration == 0 then
        return 1.0
    end

    return math.clamp(local_elapsed / animation_duration, 0, 1)
end

--- @brief Get overall progress of the entire sequence as a fraction [0, 1]
function rt.TimedAnimationSequence:get_fraction()
    if self._total_duration == 0 then
        return 1.0
    end

    local effective_elapsed = self._elapsed
    if self._should_loop then
        effective_elapsed = math.fmod(self._elapsed, self._total_duration)
    end

    return math.clamp(effective_elapsed / self._total_duration, 0, 1)
end