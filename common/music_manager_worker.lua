local main_to_worker, worker_to_main, messages = ...

require "love.timer"
require "include"
require "common.music_manager_instance"

local manager = nil -- rt.MusicManagerInstance

-- message handling
local message_id_to_callback = {
    [messages.instantiate] = function(message)
        manager = rt.MusicManagerInstance()
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
        rt.critical("In rt.MusicManager: error in thread: unhandled message id `",  message.message_id,  "`")
    else
        local success, error_maybe = pcall(callback, message)
        if not success then
            rt.critical("In rt.MusicManager: error in thread when handling message `",  message.message_id,  "`: ",  error_maybe)
        end
    end
end

-- main
local last_time = love.timer.getTime()
local step = 1 / 120
while true do
    while main_to_worker:peek() ~= nil do
        local message = main_to_worker:pop()
        if message.message_id == "shutdown" then return end
        handle_message(message)
    end

    if manager ~= nil then
        local now = love.timer.getTime()
        local elapsed = now - last_time
        while elapsed > step do
            local success, error_maybe = pcall(manager.update, manager, step)
            if not success then
                rt.critical("In rt.MusicManager: error in thread when called `rt.MusicManagerInstance.update`: ",  error_maybe)
            end

            elapsed = elapsed - step
            last_time = last_time + step
        end
    end

    love.timer.sleep(step^2) -- limit cpu rate
end