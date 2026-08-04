rt.settings.routine = {
    should_resume_automatically = true
}

--- @class rt.Routine
rt.Routine = meta.class("Routine")

require "common.routine_manager"
require "common.routine_future"

_G._coroutine = _G.coroutine

--- @brief instantiate and start the subroutine
--- @param f (rt.Routine) -> nil, any...
function rt.Routine:instantiate(...)
    meta.assert(select(1, ...), mt.Function)
    meta.assert(select(2, ...), mt.Nil)

    self._callback = select(1, ...)
    self._native = _G._coroutine.create(self._callback)

    self._id = rt.RoutineManager:_notify_routine_added(self)
    self._should_resume_automatically = rt.settings.routine.should_resume_automatically
end

--- @brief
function rt.Routine:set_should_resume_automatically(b)
    if b == nil then b = true end
    meta.assert(b, mt.Boolean)
    self._should_resume_automatically = b
    return self
end

--- @brief
function rt.Routine:get_should_resume_automatically()
    return self._should_resume_automatically
end

--- @brief
function rt.Routine:get_id()
    return self._id
end

--- @brief
function rt.Routine:yield()
    meta.assert(self, rt.Routine)
    rt.RoutineManager:yield(self)
    return self
end

--- @brief
function rt.Routine:resume()
    meta.assert(self, rt.Routine)
    rt.RoutineManager:resume(self)
    return self
end

rt.Routine.start = rt.Routine.resume

--- @brief
function rt.Routine:restart()
    self:instantiate(self._callback)
    self:resume()
    return self
end

--- @brief
function rt.Routine:exit()
    rt.RoutineManager:yield(self)
    rt.RoutineManager:_notify_routine_removed(self)
end

--- @brief
function rt.Routine:get_is_done()
    return _G._coroutine.status(self._native) == "dead"
end

--- @brief
function rt.Routine:get_native()
    return self._native
end
