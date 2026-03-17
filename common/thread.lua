require "common.thread_manager"
require "common.channel"

--- @class rt.Thread
rt.Thread = meta.class("Thread")
meta.add_signal(rt.Thread, "shutdown")

rt.Thread.SHUTDOWN_MESSAGE = "shutdown"

--- @brief
function rt.Thread:instantiate(path, _)
    meta.assert(path, "String", _, "Nil")
    self._native = love.thread.newThread(path)
    self._path = path
    rt.ThreadManager:_notify_thread_added(self)
end

--- @brief
function rt.Thread:start(...)
    self._native:start(...)
end

--- @brief
function rt.Thread:get_native()
    return self._native
end

--- @brief
function rt.Thread:get_path()
    return self._path
end

--- @brief
function rt.Thread:get_is_running()
    return self._native:isRunning()
end

--- @brief
function rt.Thread:shutdown()
    if not self._native:isRunning() then return end

    local emitted = self:signal_try_emit("shutdown")
    if emitted == false then
        rt.error("In rt.Thread: thread `", self._path, "` has no handler connected to signal `shutdown`, shutdown was unsuccessfull")
    end
end

