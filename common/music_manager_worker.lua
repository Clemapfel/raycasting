local main_to_worker, worker_to_main, messages = ...

require "love.timer"
require "include"
require "common.music_manager"

local manager = nil -- rt.MusicManager

-- message handling
local message_id_to_callback = {
    [messages.instantiate] = function(message)
        manager = rt.MusicManager()
    end,

    [messages.play] = function(message)
        if manager ~= nil then
            manager:play(message.id, message.restart)
        end
    end,

    [messages.pause] = function(message)
        if manager ~= nil then
            manager:pause()
        end
    end,

    [messages.unpause] = function(message)
        if manager ~= nil then
            manager:unpause()
        end
    end,

    [messages.stop] = function(message)
        if manager ~= nil then
            manager:stop()
        end
    end,

    [messages.set_volume] = function(message)
        if manager ~= nil then
            manager:set_volume(message.value)
        end
    end
}

local function handle_message(message)
    if message == nil then return end
    local callback = message_id_to_callback[message.message_id]
    if callback == nil then
        rt.critical("In rt.MusicManager: error in thread: unhandled message id `" .. message.message_id .. "`")
    else
        local success, error_maybe = pcall(callback, message)
        if not success then
            rt.critical("In rt.MusicManager: error in thread when handling message `" .. message.message_id .. "`: " .. error_maybe)
        end
    end
end

-- main
local last_time = love.timer.getTime()
local step = 1 / 120
while true do
    -- if initialized, busy check for messages
    if manager ~= nil then
        if main_to_worker:peek() ~= nil then
            handle_message(main_to_worker:pop())
        end

        local now = love.timer.getTime()
        local elapsed = now - last_time
        local updated = false
        while elapsed > step do
            manager:update(step)
            last_time = now
        end

        love.timer.sleep(step^2) -- prevent CPU running at full cycle
    else
        handle_message(main_to_worker:demand()) -- non busy wait
    end
end