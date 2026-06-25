--- @class rt.Routine.Future
rt.Routine.Future = meta.class("RoutineFuture")

--- @enum rt.Routine.FutureResult
rt.Routine.FutureResult = {
    IS_DONE = true,
    IS_NOT_DONE = false
}
rt.Routine.FutureResult = meta.enum("RoutineFutureResult", rt.Routine.FutureResult)

local _noop = function(self) return rt.Routine.FutureResult.IS_DONE end
local _noop_return = function(self) return nil end

local _STATE_IDLE = 0
local _STATE_START = 1
local _STATE_UPDATE = 2
local _STATE_END = 3
local _STATE_DONE = 4

rt.Routine.Future.Callbacks = meta.class("RoutineFutureCallbacks")
meta.add_schema(rt.Routine.Future.Callbacks, {
    on_start = mt.Function,
    on_end = mt.Function,
    on_update = mt.Function,
    on_return = mt.Function
})

--- @brief
function rt.Routine.Future:instantiate(
    callbacks
)
    if callbacks == nil then callbacks = {} end
    callbacks.on_start = callbacks.on_start or _noop
    callbacks.on_update = callbacks.on_update or _noop
    callbacks.on_end = callbacks.on_end or _noop
    callbacks.on_return = callbacks.on_return or _noop_return

    meta.validate_schema(rt.Routine.Future.Callbacks(callbacks))

    self._on_start = callbacks.on_start
    self._on_update = callbacks.on_update
    self._on_end = callbacks.on_end
    self._on_return = callbacks.on_return
    self._return_value = nil -- set once

    self._last_timestamp = nil -- set on first _step
    self._state = _STATE_IDLE
end

local _assert_is_result = function(scope, result)
    if not meta.is_enum_value(result, rt.Routine.FutureResult) then
        rt.error("In rt.Routine.Future.step: `", scope, "` callback does return a value of type `rt.Routine.FutureResult`")
    end

    return result
end

--- @brief
function rt.Routine.Future:_step()
    if self._state == _STATE_DONE then return end

    if self._last_timestamp == nil then self._last_timestamp = love.timer.getTime() end

    local now = love.timer.getTime()
    local delta = love.timer.getTime() - self._last_timestamp
    self._last_timestamp = now

    if self._state == _STATE_IDLE then
        self._state = _STATE_START
    end

    if self._state == _STATE_START then
        local is_done = _assert_is_result("on_start",
            self:_on_start()
        )

        if is_done ~= rt.Routine.FutureResult.IS_DONE then return end
        self._state = _STATE_UPDATE
    end

    if self._state == _STATE_UPDATE then
        local is_done = _assert_is_result("on_update",
            self:_on_update(delta)
        )

        if is_done ~= rt.Routine.FutureResult.IS_DONE then return end
        self._state = _STATE_END
    end

    if self._state == _STATE_END then
        local is_done = _assert_is_result("on_end",
            self:_on_end()
        )

        if is_done ~= rt.Routine.FutureResult.IS_DONE then return end
        self._state = _STATE_DONE
        self._return_value = self:_on_return()
    end
end

--- @brief
function rt.Routine.Future:await()
    while self._state ~= _STATE_DONE do
        self:_step()
        rt.Routine.yield()
    end

    return self._return_value
end

--- @class rt.Routine.Timer
rt.Routine.Timer = function(duration)
    local self = rt.Routine.Future({
        on_update = function(self, delta)
            self.elapsed = self.elapsed + delta
            return ternary(
                self.elapsed >= self.duration,
                rt.Routine.FutureResult.IS_DONE,
                rt.Routine.FutureResult.IS_NOT_DONE
            )
        end
    })

    self.elapsed = 0
    self.duration = duration
    return self
end

--- @class rt.Routine.Condition
rt.Routine.Condition = function(condition_callback)
    local self = rt.Routine.Future({
        on_end = function(self)
            local condition = condition_callback()
            if not meta.is_boolean(condition) then
                rt.error("In rt.Routine.Condition: condition callback does not return a boolean")
            end

            return ternary(condition,
                rt.Routine.FutureResult.IS_DONE,
                rt.Routine.FutureResult.IS_NOT_DONE
            )
        end
    })

    return self
end


