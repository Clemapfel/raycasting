rt.settings.thread_pool = {
    max_n_threads = math.huge
}

--[[
Usage:

Add handler "example_handler" to common/thread_pool_worker.lua
    _G["example_handler] = function(data)
        -- do stuff with data
        return data
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
    SUCCESS = 1,
    ERROR = 2,
    EXIT = 3
}

--- @brief
function rt.ThreadPool:instantiate()
    self._entries = {}
    self._n_threads = math.min(love.system.getProcessorCount() - 1, rt.settings.thread_pool.max_n_threads)
    if self._n_threads <= 0 then self._n_threads = 1 end

    self._main_to_worker = love.thread.newChannel()
    self._hash_to_instance = meta.make_weak({})
    self._hash_to_messages = {}

    local success, error = pcall(love.thread.newThread, "common/thread_pool_worker.lua")
    println(success, error)

    for i = 1, self._n_threads do
        local entry = {
            _id = i,
            _thread = error,
            _worker_to_main = love.thread.newChannel()
        }

        table.insert(self._entries, entry)
    end

    for i = 1, self._n_threads do
        local entry = self._entries[i]
        entry._thread:start(
            self._main_to_worker,
            entry._worker_to_main,
            MessageType
        )
    end
end

--- @brief
function rt.ThreadPool:send_message(instance, handler_id, data)
    meta.assert_typeof(handler_id, "String")
    meta.assert_typeof(data, "Table")

    local hash = meta.hash(instance)
    self._hash_to_instance[hash] = instance
    self._main_to_worker:push({
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
            elseif message.type == MessageType.EXIT then
                to_kill[i] = true -- don't immediately kill, wait for queue to be emptied
            end

            message = entry._worker_to_main:pop()
        end
    end

    for index in keys(to_kill) do
        local entry = self._entries[index]
        entry._thread:kill()
        self._entries[index] = nil
        self._n_threads = self._n_threads - 1
    end
end

rt.ThreadPool = rt.ThreadPool() -- static instance
return rt.ThreadPool
