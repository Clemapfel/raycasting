--- @class rt.Routine
rt.Routine = meta.class("Routine")

--- @enum rt.RoutineStatus
rt.RoutineStatus = {
    IDLE = "IDLE",
    RUNNING = "RUNNING",
    DONE = "DONE"
}
rt.RoutineStatus = meta.enum("RoutineStatus", rt.RoutineStatus)

local _save_resume = function(routine, ...)
    local result = { coroutine.resume(routine, ...) }
    if result[1] ~= true then
        rt.error(result[2])
    else
        table.remove(result, 1)
        return table.unpack(result)
    end
end

local coroutine_depth = 0
local error = _G.error
local traceback = debug.traceback

_G.error = function(...)
    -- forward traceback during error
    if coroutine_depth > 0 then
        error(table.concat({ ... }) .. "\n" .. traceback())
    else
        error(...)
    end
end

--- @brief instantiate and start the subroutine
--- @param f (rt.Routine) -> nil, any...
function rt.Routine:instantiate(...)
    -- use vararg instead of explicit first argument so callstack cannot infer a name and skips this wrapper during traceback

    meta.assert(select(1, ...), mt.Function)
    meta.assert(select(2, ...), mt.Nil)

    self._status = rt.RoutineStatus.IDLE
    self._callback = select(1, ...)
    self._coroutine = coroutine.create(function(...)
        coroutine_depth = coroutine_depth + 1
        self._status = rt.RoutineStatus.RUNNING
        select(1, ...)(self)
        self._status = rt.RoutineStatus.DONE
        coroutine_depth = coroutine_depth - 1
    end)
end

--- @brief
function rt.Routine:start()
    _save_resume(self._coroutine, self._callback) -- automatically sets status
    return self
end

--- @brief
function rt.Routine:yield()
    coroutine.yield()
end

--- @brief
function rt.Routine:resume()
    if self._state ~= rt.RoutineStatus.DONE then
        _save_resume(self._coroutine, self._callback)
    end
    return self
end

--- @brief
function rt.Routine:resume(...)
    _save_resume(self._coroutine, ...)
end

--- @brief
function rt.Routine:get_status()
    return self._status
end