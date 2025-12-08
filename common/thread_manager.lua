--- @class rt.ThreadManager
rt.ThreadManager = meta.class("ThreadManager")

--- @brief
function rt.ThreadManager:instantiate()
    self._threads = meta.make_weak({})
    self._shutdown_active = false
end

--- @brief
function rt.ThreadManager:request_shutdown()
    self._shutdown_active = true
    for thread in values(self._threads) do
        if thread:get_native():isRunning() then
            thread:shutdown()
        end
    end
end

--- @brief
function rt.ThreadManager:shutdown_active()
    return self._shutdown_active
end

--- @brief
function rt.ThreadManager:get_is_shutdown()
    for thread in values(self._threads) do
        if thread:get_native():isRunning() then return false end
    end

    return true
end

--- @brief
function rt.ThreadManager:_notify_thread_added(thread)
    meta.assert(thread, rt.Thread)
    table.insert(self._threads, thread)
end


rt.ThreadManager = rt.ThreadManager() -- singleton instance