--[[
main_to_worker, worker_to_main = ...
]]--

--- @class rt.Thread
rt.Thread = meta.class("Thread")

function rt.Thread:instantiate(file_or_code, should_start)
    meta.install(self, {
        _native = love.thread.newThread(file_or_code),
        _main_to_worker = love.thread.newChannel(),
        _worker_to_main = love.thread.newChannel()
    })

    if should_start == true then self:start() end
end

--- @brief
function rt.Thread:start()
    self._native:start(self._main_to_worker, self._worker_to_main)
end

--- @brief
function rt.Thread:push(x)
    if not self._native:isRunning() then self:start() end
    self._main_to_worker:push(x)
end

--- @brief waits
function rt.Thread:wait()
    if not self._native:isRunning() then self:start() end
    return self._worker_to_main:demand()
end

--- @brief
function rt.Thread:pop()
    if not self._native:isRunning() then self:start() end
    return self._worker_to_main:pop()
end

--- @brief
function rt.Thread:peek()
    if not self._native:isRunning() then self:start() end
    return self._worker_to_main:peek()
end



