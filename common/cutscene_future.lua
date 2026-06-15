--- @class rt.CutsceneFuture
rt.CutsceneFuture = meta.class("CutsceneFuture")

--- @enum rt.CutsceneFutureResult
rt.CutsceneFutureResult = {
    CONTINUE = false,
    EXIT = true
}
rt.CutsceneFutureResult = meta.enum("CutsceneFutureResult", rt.CutsceneFutureResult)

local _noop_update = function() return rt.CutsceneFutureResult.EXIT end
local _noop_exit = function() end

--- @brief
--- @param on_update (Number) -> rt.CutsceneFutureResult
--- @param on_exit () -> ()
function rt.CutsceneFuture:instantiate(cutscene, on_update, on_exit)
    meta.assert(cutscene, rt.Cutscene)
    on_update = on_update or _noop_update
    on_exit = on_exit or _noop_exit
    meta.assert(on_update, mt.Function, on_exit, mt.Function)

    self._cutscene = cutscene
    self._on_update = on_update
    self._on_exit = on_exit
    self._is_done = false
    self._result = nil

    self._cutscene:_notify_future_added(self)
end

--- @brief
function rt.CutsceneFuture:update(delta)
    if self._is_done then return end

    local result = self._on_update(delta)
    if not meta.is_boolean(result) then
        rt.error("In rt.CutsceneFuture: callback does return a value of enum `rt.CutsceneFutureResult`")
    end

    if result == rt.CutsceneFutureResult.EXIT and self._is_done == false then
        self._result = self._on_exit()
        self._is_done = true
    end
end

--- @brief
function rt.CutsceneFuture:get_is_done()
    return self._is_done
end

--- @brief
function rt.CutsceneFuture:get_result()
    return self._is_done and nil or self._result
end

--- @brief
function rt.CutsceneFuture:skip()
    if self._is_done ~= true then
        self._on_exit()
        self._is_done = true
    end
end