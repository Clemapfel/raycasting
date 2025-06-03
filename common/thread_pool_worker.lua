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

local _error_prefix = "[" .. thread_id .. "]"

while true do
    local task_message = nil

    local add_handler_tried = false
    ::retry_add_handler::

    -- check for config message
    while main_to_worker_local:getCount() > 0 do
        local config_message = main_to_worker_local:pop()
        if config_message.type == MessageType.ADD_HANDLER then
            -- { type, handler_id, handler (serialized) }
            local handler_id = config_message.handler_id
            local success, handler = pcall(load, config_message.handler)
            if success then
                _G[handler_id] = handler
            else
                worker_to_main:push({
                    type = MessageType.ERROR,
                    hash = config_message.hash,
                    reason = _error_prefix .. "In thread_pool_worker: when registering handler `\"" .. handler_id .. "\"`: unable to `load` encoded chunk"
                })
            end
        end
    end

    if not add_handler_tried then
        -- non-busy wait for task
        -- { hash, handler_id, data }
        task_message = main_to_worker_global:demand()
    end

    local handler = _G[task_message.handler_id]

    if handler == nil then
        -- if handler is nil, it might be in main_to_worker_local
        -- check again but maintain current message
        if add_handler_tried == false then
            add_handler_tried = true
            goto retry_add_handler
        end

        -- if handler unknown, promote error to main
        worker_to_main:push({
            type = MessageType.ERROR,
            hash = task_message.hash,
            reason = _error_prefix .. "In thread_pool_worker: for message from object `" .. task_message.hash .. "`: handler_id `" .. task_message.handler_id .. "` does not refer to a function in common/thread_pool_worker.lua"
        })
    end

    -- invoke handler, promote error if one occurrs
    local success, data_or_error, _ = pcall(handler, task_message.data)
    if not success then
        worker_to_main:push({
            type = MessageType.ERROR,
            hash = task_message.hash,
            reason = _error_prefix .. "In thread_pool_worker: for object `" .. task_message.hash .. "`, handler `" .. task_message.handler_id .. "`: " .. data_or_error
        })
    else
        local data = data_or_error

        -- check if handler correctly only returns one table
        if _ ~= nil then
            worker_to_main:push({
                type = MessageType.ERROR,
                hash = task_message.hash,
                reason = _error_prefix .. "In thread_pool_worker: for object `" .. task_message.hash .. "`, handler `" .. task_message.handler_id .. "`: " .. "returns more than one object"
            })
        elseif type(data) ~= "table" then
            worker_to_main:push({
                type = MessageType.ERROR,
                hash = task_message.hash,
                reason = _error_prefix .. "In thread_pool_worker: for object `" .. task_message.hash .. "`, handler `" .. task_message.handler_id .. "`: " .. "handler does not return a singular table"
            })
        else
            -- send back result
            worker_to_main:push({
                type = MessageType.SUCCESS,
                hash = task_message.hash,
                data = data
            })
        end
    end
end