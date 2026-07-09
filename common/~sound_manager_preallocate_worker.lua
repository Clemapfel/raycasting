local main_to_worker, worker_to_main, message_types = ...

require "common"
require "log"
require "love.sound"
require "love.audio"
local _import_audio = require "common.sound_manager_import_audio"

while true do
    local message = main_to_worker:demand()

    -- load audio and send back
    if message.type == message_types.load then
        local success, data_or_error = pcall(_import_audio, message.path)
        if not success then
            worker_to_main:push({
                type = message_types.load_failure,
                id = message.id,
                error = data_or_error
            })
        else
            worker_to_main:push({
                type = message_types.load_success,
                id = message.id,
                data = data_or_error
            })
        end
    else
        worker_to_main:push({
            type = message_types.load_failure,
            id = message.id,
            error = "In rt.SoundManager:preallocate: unhandled thread-side message `" .. tostring(message.type) .. "`"
        })
    end
end

