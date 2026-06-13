--- @class rt.CutsceneFuture
rt.CutsceneFuture = meta.class("CutsceneHandlerFuture")

--- @enum rt.CutsceneFutureResult
rt.CutsceneFutureResult = {
    CONTINUE = false,
    EXIT = true
}
rt.CutsceneFutureResult = meta.enum("CutsceneFutureResult", rt.CutsceneFutureResult)

--- @brief
--- @param on_update (Number) -> rt.CutsceneFutureResult
--- @param on_exit () -> ()
function rt.CutsceneFuture:instantiate(on_update, on_exit)
    meta.assert(on_exit, mt.Function, on_exit, mt.Function)
    self._on_update = on_update
    self._on_exit = on_exit
    self._is_done = false
end

--- @brief
function rt.CutsceneFuture.update(delta)
    if self._is_done then return end

    local result = self._on_update(delta)
    if not meta.is_boolean(result) then
        rt.error("In rt.CutsceneFuture: callback does return a value of enum `rt.CutsceneFutureResult`")
    end

    if result == rt.CutsceneFutureResult.EXIT and self._is_done == false then
        self._on_exit()
        self._is_done = true
    end
end

--- @brief
function rt.CutsceneFuture:get_is_done()
    return self._is_done
end

--- @brief
function rt.CutsceneFuture:skip()
    if self._is_done ~= true then
        self._on_exit()
        self._is_done = true
    end
end