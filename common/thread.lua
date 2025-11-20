require "common.thread_handler"

--- @class rt.Thread
rt.Thread = meta.class("Thread")

--- @brief
function rt.Thread:instantiate(...)
    self._native = love.thread.newThread(...)
    rt.ThreadHandler:notify_thread_added(self)
end

--- @brief
function rt.Thread:get_native()
    return self._native
end

--- @class rt.Channel
rt.Channel = meta.class("Channel")

--- @brief
function rt.Channel:instantiate(...)
    self._native = love.thread.newChannel(...)
end

--- @brief
function rt.Channel:get_native()
    return self._native
end
