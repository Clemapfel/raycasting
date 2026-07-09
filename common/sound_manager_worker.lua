require "love.audio"
require "include"

local main_to_worker, worker_to_main, MessageType = ...

--local success, error_maybe = pcall(function()
do
    local shutdown_active = false

    while true do
        local message
        if shutdown_active then
            message = main_to_worker:pop()
            if message == nil then return end
        else
            message = main_to_worker:demand()
        end

        if message.type == MessageType.DEBUG then
            message.source:play()
        elseif message.type == MessageType.SHUTDOWN then
            shutdown_active = true
        end
    end
end
--end) -- pcall

worker_to_main:push({
    type = MessageType.SHUTDOWN_RESPONSE,
    success = success,
    error = error_maybe
})