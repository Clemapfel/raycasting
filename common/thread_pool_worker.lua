slick = require "dependencies.slick.slick"

require "common.common"
require "love.timer"
require "love.math"

local thread_id,
      main_to_worker_global,    -- channel for receiving tasks, shared between all threads
      main_to_worker_local,     -- channel for receiving config events, local to this threads
      worker_to_main,           -- channel for delivering tasks, local to this thread
      MessageType               -- message type enum
  = ...

local error_prefix = "[" .. thread_id .. "]"

while true do
    local add_handler_tried = false
    ::retry_add_handler::

    -- check for config message
    while main_to_worker_local:getCount() > 0 do
        local message = main_to_worker_local:pop()
        if message.type == MessageType.ADD_HANDLER then
            -- { type, handler_id, handler (serialized) }
            local handler_id = message.handler_id
            local success, handler = pcall(load, message.handler)
            if success then
                _G[handler_id] = handler
            else
                worker_to_main:push({
                    type = MessageType.ERROR,
                    hash = message.hash,
                    reason = error_prefix .. "In thread_pool_worker: when registering handler `\"" .. handler_id .. "\"`: unable to `load` encoded chunk"
                })
            end
        end
    end

    -- non-busy wait for task
    -- { hash, handler_id, data }
    local message = main_to_worker_global:demand()

    -- if handler unknown, promote error to main
    local handler = _G[message.handler_id]
    if handler == nil then
        -- if handler is nil, it might be in main_to_worker_local
        if add_handler_tried == false then
            add_handler_tried = true
            goto retry_add_handler
        end

        worker_to_main:push({
            type = MessageType.ERROR,
            hash = message.hash,
            reason = error_prefix .. "In thread_pool_worker: for message from object `" .. message.hash .. "`: handler_id `" .. message.handler_id .. "` does not refer to a function in common/thread_pool_worker.lua"
        })
    end

    -- invoke handler, promote error if one occurrs
    local success, data_or_error, _ = pcall(handler, message.data)
    if not success then
        worker_to_main:push({
            type = MessageType.ERROR,
            hash = message.hash,
            reason = error_prefix .. "In thread_pool_worker: for object `" .. message.hash .. "`, handler `" .. message.handler_id .. "`: " .. data_or_error
        })
    else
        local data = data_or_error

        -- check if handler correctly operates on data as a pure function
        if _ ~= nil then
            worker_to_main:push({
                type = MessageType.ERROR,
                hash = message.hash,
                reason = error_prefix .. "In thread_pool_worker: for object `" .. message.hash .. "`, handler `" .. message.handler_id .. "`: " .. "returns more than one object"
            })
        end

        if type(data) ~= "table" then
            worker_to_main:push({
                type = MessageType.ERROR,
                hash = message.hash,
                reason = error_prefix .. "In thread_pool_worker: for object `" .. message.hash .. "`, handler `" .. message.handler_id .. "`: " .. "handler does not return a singular table"
            })
        else
            -- send back result
            worker_to_main:push({
                type = MessageType.SUCCESS,
                hash = message.hash,
                data = data
            })
        end
    end
end

return