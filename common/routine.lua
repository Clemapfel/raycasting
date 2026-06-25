--- @class rt.Routine
rt.Routine = meta.class("Routine")

require "common.routine_future"

--- @enum rt.RoutineStatus
rt.RoutineStatus = {
    IDLE = "IDLE",
    RUNNING = "RUNNING",
    DONE = "DONE"
}
rt.RoutineStatus = meta.enum("RoutineStatus", rt.RoutineStatus)

-- override error handler, this is necessary to bubble
-- up traceback when error is thrown mid-routine
local coroutine_depth = 0
local error = _G.error
local traceback = debug.traceback

_G.error = function(...)
    if coroutine_depth > 0 then
        error(table.concat({ ... }) .. traceback())
    else
        error(...)
    end
end

_G._coroutine = _G.coroutine

--- @brief instantiate and start the subroutine
--- @param f (rt.Routine) -> nil, any...
function rt.Routine:instantiate(...)
    -- use vararg instead of explicit first argument so callstack cannot infer a name and skips this wrapper during traceback
    meta.assert(select(1, ...), mt.Function)
    meta.assert(select(2, ...), mt.Nil)

    self._status = rt.RoutineStatus.IDLE
    self._callback = select(1, ...)
    self._coroutine = _G._coroutine.create(function(...)
        local n = select("#", ...)
        coroutine_depth = coroutine_depth + 1
        self._status = rt.RoutineStatus.RUNNING
        if n <= 1 then
            select(1, ...)(self)
        else
            select(1, ...)(self, select(-1 * (n - 1), ...)) -- every vararg except first
        end
        self._status = rt.RoutineStatus.DONE
        coroutine_depth = coroutine_depth - 1
    end)
end

--- @brief
function rt.Routine:_save_resume(routine, ...)
    if _G._coroutine.status(routine) ~= "dead" then
        local result = { _G._coroutine.resume(routine, ...) }
        if result[1] ~= true then
            rt.error("\n", result[2])
        else
            table.remove(result, 1)
            return table.unpack(result)
        end
    end
end

--- @brief
function rt.Routine:start()
    self:_save_resume(self._coroutine, self._callback) -- automatically sets status
    return self
end

--- @brief
function rt.Routine:yield(...)
    _G._coroutine.yield(...)
end

--- @brief
function rt.Routine:resume(...)
    if self._state ~= rt.RoutineStatus.DONE then
        self:_save_resume(self._coroutine, self._callback, ...)
    end
    return self
end

--- @brief
function rt.Routine:barrier(...)
    for i = 1, select("#", ...) do
        local future = select(i, ...)
        meta.assert_typeof(future, rt.Routine.Future, i)
        future:await()
    end
end

--- @brief
function rt.Routine:get_status()
    return self._status
end

if DEBUG then _G.coroutine = nil end
