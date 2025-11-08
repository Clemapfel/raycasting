--- @class rt.Thread
rt.Thread = meta.class("Thread")

local _all_threads = meta.make_weak({})

--- @brief
function rt.Thread:instantiate(...)
    self._native = love.thread.newThread(...)
    table.insert(_all_threads, self._native)
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