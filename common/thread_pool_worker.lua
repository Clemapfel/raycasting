require "love.timer"
require "love.math"

-- ### MESSAGE HANDLERS (add new handlers here) ### --

_G["example_handler"] = function(data)
    love.timer.sleep()
    return data -- should be pure function that only returns data
end



-- ### WORKER LOGIC (do not modify) ### --

local main_to_worker, worker_to_main, MessageType = ...

while true do
    --- message = { hash, handler_id, data }
    local message = main_to_worker:demand()

    -- quit safely
    if message.type == MessageType.EXIT then
        break
    end

    -- if handler unknown, promote error to main
    local handler = _G[message.handler_id]
    if handler == nil then
        worker_to_main:push({
            type = MessageType.ERROR,
            hash = message.hash,
            reason = "In thread_pool_worker: for message from object `" .. message.hash .. "`: handler_id `" .. message.handler_id .. "` does not refer to a function in common/thread_pool_worker.lua"
        })
    end

    -- invoke handler, promote error if one occurrs
    local success, data_or_error, _ = pcall(handler, message.data)
    if not success then
        worker_to_main:push({
            type = MessageType.ERROR,
            hash = message.hash,
            reason = "In thread_pool_worker: for object `" .. message.hash .. "`, handler `" .. message.handler_id .. "`: " .. data_or_error
        })
    else
        -- check if handler correctly operates on data as a pure function
        if _ ~= nil then
            worker_to_main:push({
                type = MessageType.ERROR,
                hash = message.hash,
                reason = "In thread_pool_worker: for object `" .. message.hash .. "`, handler `" .. message.handler_id .. "`: " .. "returns more than one object"
            })
        end

        if not type(data_or_error) == "table" then
            worker_to_main:push({
                type = MessageType.ERROR,
                hash = message.hash,
                reason = "In thread_pool_worker: for object `" .. message.hash .. "`, handler `" .. message.handler_id .. "`: " .. "handler does not return pure data object"
            })
        else
            -- send back result
            worker_to_main:push({
                type = MessageType.SUCCESS,
                hash = message.hash,
                data = data_or_error
            })
        end
    end
end

worker_to_main:push({
    type = MessageType.EXIT
})

return