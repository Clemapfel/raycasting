local main_to_worker_native, worker_to_main_native, MessageType = ...

require "include"
require "common.thread"

require "love.image"

local main_to_worker = main_to_worker_native
local worker_to_main = worker_to_main_native

local function main()
    local shutdown_active = false
    while true do
        if shutdown_active and main_to_worker:getCount() == 0 then break end
        local message = main_to_worker:demand()
        if message.type == MessageType.HANDLE_IMAGE then
            message.data:encode("png", message.file_name)
        elseif message.type == MessageType.SHUTDOWN then
            shutdown_active = true
        else
            rt.error("In rt.ScreenRecorder: thread errored: unhandled message type `", message.type, "`")
        end
    end
end

local success, error_maybe = pcall(main)
worker_to_main:push({
    type = MessageType.SHUTDOWN_RESPONSE,
    success = success,
    error = error_maybe
})

