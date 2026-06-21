--- @class rt.Timer
rt.Timer = meta.class("Timer")

local _TYPE_START = "start"
local _TYPE_PAUSE = "pause"
local _TYPE_UNPAUSE = "unpause"
local _TYPE_STOP = "stop"

--- @brief
function rt.Timer:instantiate()
    self._timestamps = {}
end

--- @brief
function rt.Timer:start()
    self:reset()
    table.insert(self._timestamps, {
        type = _TYPE_START,
        time = love.timer.getTime()
    })
end

--- @brief
function rt.Timer:pause()
    table.insert(self._timestamps, {
        type = _TYPE_PAUSE,
        time = love.timer.getTime()
    })
end

--- @brief
function rt.Timer:unpause()
    table.insert(self._timestamps, {
        type = _TYPE_UNPAUSE,
        time = love.timer.getTime()
    })
end

--- @brief
function rt.Timer:stop()
    table.insert(self._timestamps, {
        type = _TYPE_STOP,
        time = love.timer.getTime()
    })
end

--- @brief
function rt.Timer:reset()
    self._timestamps = {}
end

--- @brief
function rt.Timer:get_is_active()
    local n = #self._timestamps
    return n > 0
        and (self._timestamps[n].type ~= _TYPE_STOP or self._timestamps[n].type ~= _TYPE_PAUSE)
end

--- @brief
function rt.Timer:get_elapsed()
    local elapsed = 0
    local last_start_time = nil
    local is_started = false

    for _, stamp in ipairs(self._timestamps) do
        if stamp.type == _TYPE_START then
            is_started = true
            last_start_time = stamp.time
        elseif stamp.type == _TYPE_PAUSE then
            if last_start_time ~= nil then
                elapsed = elapsed + (stamp.time - last_start_time)
                last_start_time = nil
            end
        elseif stamp.type == _TYPE_UNPAUSE then
            last_start_time = stamp.time
        elseif stamp.type == _TYPE_STOP then
            if last_start_time ~= nil then
                elapsed = elapsed + (stamp.time - last_start_time)
                last_start_time = nil
            end
            break
        end
    end

    -- not yet stopped, add current time
    if #self._timestamps > 0 and last_start_time ~= nil then
        elapsed = elapsed + (love.timer.getTime() - last_start_time)
    end

    return elapsed
end
