--- @class rt.RoutineManager
rt.RoutineManager = meta.class("RoutineManager")

--- @brief
function rt.RoutineManager:instantiate()
    self._current_id = 0
    self._id_to_routine = {} -- Table<Number, rt.Routine>, sic, not weak
end

--- @brief
function rt.RoutineManager:_notify_routine_added(routine)
    local id = self._current_id
    self._current_id = self._current_id + 1
    self._id_to_routine[id] = routine
    return id
end

--- @brief
function rt.RoutineManager:_notify_routine_removed(routine)
    self._id_to_routine[routine:get_id()] = nil
end

--- @brief
function rt.RoutineManager:step()
    local to_remove = {}
    for _, routine in pairs(self._id_to_routine) do
        if _G._coroutine.status(routine:get_native()) == "dead" then
            table.insert(to_remove, routine)
        elseif routine:get_should_resume_automatically() then
            self:resume(routine)
        end
    end

    for _, routine in ipairs(to_remove) do
        self:_notify_routine_removed(routine)
    end
end

--- @brief
function rt.RoutineManager:yield(routine, ...)
    if (not meta.isa(routine, rt.Routine)) then
        rt.error("In rt.RoutineManager:yield: argument #1 is not a routine, did you mean to call routine:yield() ?")
    end
    _G._coroutine.yield(routine, ...)
end

local _coroutine_depth = 0
local _error = _G.error
local _traceback = debug.traceback
local _forward_error = function(message)
    if _coroutine_depth > 0 then
        message = tostring(message) .. _traceback("", 2)
        _error(message)
    end
end

--- @brief resume or start a coroutine. Does nothing if routine has already exit
--- @param routine rt.Routine
--- @param varag any forwarded to routine:yield
function rt.RoutineManager:resume(routine, ...)
    meta.assert(routine, mt.Optional(rt.Routine))

    local native = routine:get_native()
    if _G._coroutine.status(native) ~= "dead" then
        _coroutine_depth = _coroutine_depth + 1
        _G.error = _forward_error
        ;(function(success, ...) -- ; sic, necessary too keep anonymous invocation
            _coroutine_depth = _coroutine_depth - 1
            if _coroutine_depth <= 0 then
                _G.error = _error
            end

            if not success then
                local err = ...
                rt.error("\n" .. tostring(err))
            else
                return ...
            end
        end)(_G._coroutine.resume(native, routine, ...))
    end
end

rt.RoutineManager = meta.as_singleton(rt.RoutineManager)