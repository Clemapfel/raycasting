rt.settings.thread_pool = {
    max_n_threads = 1
}

--[[
Usage:

Add handler "example_handler" using `register_handler`
    rt.ThreadPool:register_handler("example_handler", function(data)
        -- this function cannot have upvalues
        data[1] = data[1] + 1
    end

Then, in main:
    -- somewhere inside a meta.class object
    rt.ThreadPool:send_message(self, "example_handler", data)

    -- somewhere after
    local messages = rt.ThreadPool:get_messages(self) -- can be {}
    for data in values(messages) do
        -- handle returned data
    end
]]--

--- @class rt.Thread
rt.ThreadPool = meta.class("ThreadPool")

--- @enum MessageTypes
local MessageType = { -- native enum so it can be send via channel
    SUCCESS = 1,    -- task successfully done
    ERROR = 2,      -- thread wants to promote error
    EXIT = 3,       -- cause thread to safely exit
    ADD_HANDLER = 4
}

--- @brief
function rt.ThreadPool:instantiate()
    self._entries = {}
    self._n_threads = math.min(love.system.getProcessorCount() - 1, rt.settings.thread_pool.max_n_threads)
    if self._n_threads <= 0 then self._n_threads = 1 end

    self._main_to_worker_global = love.thread.newChannel()
    self._hash_to_instance = meta.make_weak({})
    self._hash_to_messages = {}

    for i = 1, self._n_threads do
        local entry = {
            _id = i,
            _thread = love.thread.newThread("common/thread_pool_worker.lua"),
            _main_to_worker_local = love.thread.newChannel(),
            _worker_to_main = love.thread.newChannel()
        }

        table.insert(self._entries, entry)
    end

    for i = 1, self._n_threads do
        local entry = self._entries[i]
        entry._thread:start(
            i,
            self._main_to_worker_global,
            entry._main_to_worker_local,
            entry._worker_to_main,
            MessageType
        )
    end
end

--- @brief
function rt.ThreadPool:register_handler(handler_id, handler)
    meta.assert(handler_id, "String", handler, "Function")
    assert(debug.getupvalue(handler, 1) == nil, "In rt.ThreadPool.register_handler: function for handler `" .. handler_id .. "` has an upvalue, only pure functions can be registered as handlers")

    -- serialize pure function and deserialize thread-side with `load`
    local message = {
        type = MessageType.ADD_HANDLER,
        handler_id = handler_id,
        handler = string.dump(handler)
    }

    for i = 1, self._n_threads do
        local entry = self._entries[i]
        entry._main_to_worker_local:push(message)
    end
end

--- @brief
function rt.ThreadPool:send_message(instance, handler_id, data)
    meta.assert_typeof(handler_id, "String")
    meta.assert_typeof(data, "Table")

    local hash = meta.hash(instance)
    self._hash_to_instance[hash] = instance
    self._main_to_worker_global:push({
        hash = hash,
        handler_id = handler_id,
        data = data
    })
end

--- @brief
function rt.ThreadPool:has_messages(instance)
    local hash = meta.hash(instance)
    return self._hash_to_messages[hash] ~= nil and table.sizeof(self._hash_to_messages[hash]) > 0
end

local _empty = setmetatable({}, {
    __newindex = function()
        rt.error("In rt.ThreadPool: trying to modify empty table returned by get_messages")
    end
})

--- @brief
--- Table<Any>
function rt.ThreadPool:get_messages(instance)
    local hash = meta.hash(instance)
    local messages = self._hash_to_messages[hash]
    if messages == nil then return _empty end

    self._hash_to_messages[hash] = nil
    self._hash_to_instance[hash] = nil
    return messages
end

--- @brief
function rt.ThreadPool:update(_)
    local to_kill = {}
    for i, entry in ipairs(self._entries) do
        local message = entry._worker_to_main:pop()
        while message ~= nil do
            -- error message = { type, hash, reason }
            -- success message = { type, hash, data }

            if message.type == MessageType.SUCCESS then
                local message_entry = self._hash_to_messages[message.hash]
                if message_entry == nil then
                    message_entry = {}
                    self._hash_to_messages[message.hash] = message_entry
                end
                table.insert(message_entry, message.data)
            elseif message.type == MessageType.ERROR then
                rt.error("In rt.ThreadPool: " .. message.reason)
            end

            message = entry._worker_to_main:pop()
        end
    end
end

rt.ThreadPool = rt.ThreadPool() -- static instance
return rt.ThreadPool
