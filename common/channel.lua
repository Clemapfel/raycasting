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

--- @brief
function rt.Channel:get_n_messages()
    return self._native:getCount()
end

for forward in range(
    "clear",
    "demand",
    "peek",
    "push",
    "pop",
    "supply"
) do
    rt.Channel[forward] = function(self, ...)
        return self._native[forward](self._native, ...)
    end
end