--- @class rt.Future
rt.Future = meta.class("Future")

--- @enum rt.FutureResult
rt.FutureResult = {
    IS_DONE = true,
    IS_NOT_DONE = false
}
rt.FutureResult = meta.class(rt.FutureResult)

local _noop = function() return rt.FutureResult.IS_DONE end
local IDLE = 0
local STARTED = 1
local DONE = 2

--- @brief
function rt.Future:instantiate(routine, 
    update_function,
    start_function,
    end_function
)
    start_function = start_function or _noop
    update_function = update_function or _noop
    end_function = end_function or _noop

    meta.assert(routine, rt.Routine,
        update_function, mt.Function,
        start_function, mt.Function,
        end_function, mt.Function
    )
    
    self._owner = routine
end

--- @brief
function rt.Future:should_yield()
    local should_yield = self._should_yield_function()
    if not meta.is_boolean(should_yield) then
        rt.error("In rt.Future: yield function does not return a boolean")
    end
    return should_yield
end

