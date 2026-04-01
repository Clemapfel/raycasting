local main_to_worker_native, worker_to_main_native, MessageType = ...

require "common.meta"
require "common.common"
require "love.image"
require "love.graphics"

local main_to_worker = main_to_worker_native
local worker_to_main = worker_to_main_native

-- main
local success, error_maybe = pcall(function()
    local queue = {} -- FIFO
    local recording_id_to_frame_count = {} -- Table<String, Boolean>
    local shutdown_active = false

    while true do
        local message
        if shutdown_active then
            message = main_to_worker:pop()
            if message == nil then return end
        else
            message = main_to_worker:demand()
        end

        if message.type == MessageType.SHUTDOWN then
            shutdown_active = true
        elseif message.type == MessageType.RECORDING_START
            or message.type == MessageType.RECORDING_END
            or message.type == MessageType.READBACK
            or message.type == MessageType.EXPORT
        then
            table.insert(queue, message)
        elseif message.type == MessageType.UPDATE then
            -- do one pass through the queue
            while #queue > 0 do
                local current_message = queue[1]
                if current_message.type == MessageType.RECORDING_START then
                    if recording_id_to_frame_count[current_message.id] ~= nil then
                        worker_to_main:push({
                            type = MessageType.ERROR,
                            error = string.paste("recording with id `", current_message.id, "` is already active"),
                            id = current_message.id
                        })
                    else
                        recording_id_to_frame_count[current_message.id] = 0
                        worker_to_main:push({
                            type = MessageType.RECORDING_START_RESPONSE,
                            id = current_message.id
                        })
                    end
                elseif current_message.type == MessageType.READBACK then
                    if current_message.readback:isComplete() then
                        local readback_success, error_or_image_data = pcall(current_message.readback.getImageData, current_message.readback)
                        if readback_success == false then
                            worker_to_main:push({
                                type = MessageType.ERROR,
                                error = string.paste("In GraphicsReadback.getImageData: ", error_or_image_data),
                                id = current_message.id
                            })

                            goto skip
                        end

                        local image_data = error_or_image_data

                        local encode_success, error_maybe = pcall(image_data.encode, image_data, "png", current_message.filename)
                        if encode_success == false
                            or not meta.is_function(error_maybe.typeOf)
                            or not error_maybe:typeOf("FileData")
                        then
                            worker_to_main:push({
                                type = MessageType.ERROR,
                                error = string.paste("In ImageData.encode: ", error_maybe),
                                id = current_message.id
                            })

                            goto skip
                        end

                        local frame_i = recording_id_to_frame_count[current_message.id]
                        worker_to_main:push({
                            type = MessageType.READBACK_RESPONSE,
                            filename = current_message.filename,
                            frame_i = frame_i
                        })

                        recording_id_to_frame_count[current_message.id] = frame_i + 1

                        ::skip::
                    else
                        break -- stop update, try again next tick
                    end
                elseif current_message.type == MessageType.RECORDING_END then
                    if recording_id_to_frame_count[current_message.id] == nil then
                        worker_to_main:push({
                            type = MessageType.ERROR,
                            error = string.paste("recording with id `", current_message.id, "` is not currently active"),
                            id = current_message.id
                        })
                    else
                        worker_to_main:push({
                            type = MessageType.RECORDING_END_RESPONSE,
                            id = current_message.id,
                            n_frames = recording_id_to_frame_count[current_message.id]
                        })
                    end
                elseif current_message.type == MessageType.EXPORT then
                    if recording_id_to_frame_count[current_message.id] == nil then
                        worker_to_main:push({
                            type = MessageType.ERROR,
                            error = string.paste("recording with id `", current_message.id, "` is not currently active"),
                            id = current_message.id
                        })
                    else
                        -- export as video
                        local success, error_maybe = pcall(os.execute, current_message.command)
                        if success == true then
                            worker_to_main:push({
                                type = MessageType.EXPORT_RESPONSE,
                                filename = current_message.filename,
                                id = current_message.id
                            })
                        else
                            worker_to_main:push({
                                type = MessageType.ERROR,
                                error = string.paste("command failed: ", current_message.command),
                                id = current_message.id
                            })
                        end
                    end
                end

                -- message handled, pop front
                table.remove(queue, 1)
            end
        else
            worker_to_main:push({
                type = MessageType.ERROR,
                error = string.paste("unhandled message type `", message.type, "`"),
                id = message.id
            })
        end
    end
end) -- pcall

worker_to_main:push({
    type = MessageType.SHUTDOWN_RESPONSE,
    success = success,
    error = error_maybe
})
