local main_to_worker_native, worker_to_main_native, MessageType = ...

require "include"
require "common.thread"

require "love.image"
require "love.graphics"

local main_to_worker = main_to_worker_native
local worker_to_main = worker_to_main_native

local readback_queue = {}

local function main()
    local shutdown_active = false
    while true do
        if shutdown_active and main_to_worker:getCount() == 0 then break end
        local message = main_to_worker:demand()
        if message.type == MessageType.IMAGE then
            local success, error_maybe = pcall(message.data.encode, message.data, "png", message.filename)
            if success == false then
                worker_to_main:push({
                    type = MessageType.IMAGE_RESPONSE,
                    success = false,
                    error = error_maybe
                })
            else
                worker_to_main:push({
                    type = MessageType.IMAGE_RESPONSE,
                    success = true,
                    error = ""
                })
            end
        elseif message.type == MessageType.READBACK then
            -- add readback to queue
            table.insert(readback_queue, message)
        elseif message.type == MessageType.UPDATE then
            -- work through queue
            while #readback_queue > 0 do
                local entry = readback_queue[1]
                entry.readback:update()

                if entry.readback:isComplete() then
                    local image_data
                    do
                        local success, error_or_image_data = pcall(entry.readback.getImageData, entry.readback)
                        if success == false then
                            worker_to_main:push({
                                type = MessageType.READBACK_RESPONSE,
                                success = false,
                                error = error_or_image_data
                            })

                            goto skip
                        else
                            image_data = error_or_image_data
                        end
                    end

                    do
                        local success, error_maybe = pcall(image_data.encode, image_data, "png", entry.filename)
                        if success == false then
                            worker_to_main:push({
                                type = MessageType.READBACK_RESPONSE,
                                success = false,
                                error = error_maybe
                            })

                            goto skip
                        else
                            worker_to_main:push({
                                type = MessageType.READBACK_RESPONSE,
                                success = true,
                                error = ""
                            })
                        end
                    end

                    ::skip::
                elseif entry.readback:hasError() then
                    worker_to_main:push({
                        type = MessageType.READBACK_RESPONSE,
                        success = false,
                        error = ""
                    })
                else
                    -- wait for first to finish
                    break
                end

                table.remove(readback_queue, 1)
            end
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

