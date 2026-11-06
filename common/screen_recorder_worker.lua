local main_to_worker, worker_to_main, MessageType = ...

require "common.common"
require "love.data"
require "love.image"
require "love.filesystem"
require "love.timer"

local push_error = function(is_fatal, ...)
    worker_to_main:push({
        type = MessageType.ERROR,
        error = string.paste(...),
        traceback = debug.traceback(),
        fatal = (is_fatal == true)
    })
end

-- main
local success, error_maybe = xpcall(function()
    local shutdown_active = false
    while true do
        local message
        if shutdown_active then
            message = main_to_worker:pop()
            if message == nil then return end
        else
            message = main_to_worker:demand()
        end

        if message.type == MessageType.RECORDING_START then
            -- TODO open ffmpeg pipe
        elseif message.type == MessageType.RECORDING_END then
            -- TODO close ffmpeg pipe
        elseif message.type == MessageType.FRAME then
            if message.use_ffmpeg == true then
                -- TODO pipe to ffmpeg
            else
                if message.data:typeOf("ImageData") then
                    message.data:encode("png", message.path .. ".png")
                elseif message.data:typeOf("ByteData") then
                    love.filesystem.write(message.path, message.data .. ".bin")
                end
            end
        elseif message.type == MessageType.SHUTDOWN then
            shutdown_active = true
        else
            push_error(false, "Unhandled message type `", message.type, "`")
        end

        if shutdown_active ~= true then
            -- throttle
            love.timer.sleep(0.25 * 1 / 60)
        end
    end
end, function(error)
    return {
        error = tostring(error),
        traceback = debug.traceback()
    }
end) -- xpcall

local error_value = nil
local traceback = nil
if success ~= true then
    error_value = error_maybe.error
    traceback = error_maybe.traceback
    worker_to_main:push({
        type = MessageType.ERROR,
        error = error_value,
        traceback = traceback,
        fatal = true
    })
end

worker_to_main:push({
    type = MessageType.SHUTDOWN_RESPONSE,
    success = success,
    error = error_value,
    traceback = traceback
})
