rt.coroutine = {}

--- @class rt.CoroutineStatus
rt.CoroutineStatus = meta.enum("CoroutineStatus", {
    IDLE = "normal",
    RUNNING = "running",
    SUSPENDED = "suspended",
    DONE = "dead"
})

local _n_active = 0

--- @class rt.Coroutine
rt.Coroutine = meta.class("Coroutine")

function rt.Coroutine:instantiate(coroutine_callback, start_immediately)
    self._native = coroutine.create(coroutine_callback)
    self._status = rt.CoroutineStatus.IDLE

    if start_immediately then
        self:start()
    end
end

--- @brief yield if frame duration is above threshold
rt.savepoint_maybe = function(frame_percentage)
    if frame_percentage == nil then frame_percentage = 0.2 end
    if rt.SceneManager:get_frame_duration() > frame_percentage * (1 / 120) then
        coroutine.yield()
    end
end

--- @brief yield immediately, unless no coroutine is active
rt.savepoint = function()
    if _n_active > 0 then
        coroutine.yield()
    end
end

--- @brief Start the coroutine
function rt.Coroutine:start(...)
    if self._status == rt.CoroutineStatus.IDLE or self._status == rt.CoroutineStatus.SUSPENDED then
        _n_active = _n_active + 1
        self._status = rt.CoroutineStatus.RUNNING
        local success, result = coroutine.resume(self._native, ...)
        if not success then
            rt.error(result)
        end

        if coroutine.status(self._native) == "dead" then
            self._status = rt.CoroutineStatus.DONE
            _n_active = _n_active - 1
        end
    end
end

--- @brief Resume the coroutine
function rt.Coroutine:resume(...)
    if self._status == rt.CoroutineStatus.SUSPENDED then
        _n_active = _n_active + 1
        self._status = rt.CoroutineStatus.RUNNING
        local success, result = coroutine.resume(self._native, ...)
        if not success then
            rt.error(result)
        end

        if coroutine.status(self._native) == "dead" then
            self._status = rt.CoroutineStatus.DONE
            _n_active = _n_active - 1
        end
    elseif self._status == rt.CoroutineStatus.IDLE then
        self:start()
    end
end

--- @brief Get the coroutine status
function rt.Coroutine:get_status()
    return self._status
end

--- @brief Check if the coroutine is running
function rt.Coroutine:get_is_running()
    return self._status == rt.CoroutineStatus.RUNNING
end

--- @brief Check if the coroutine is done
function rt.Coroutine:get_is_done()
    return self._status == rt.CoroutineStatus.DONE
end