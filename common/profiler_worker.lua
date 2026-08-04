require "love.timer"
require "love.filesystem"
require "common"

local main_to_worker, worker_to_main, MessageType = ...

local safe_call = function(f, ...)
    local res = { pcall(f, ...) }
    if res[1] == true then
        table.remove(res, 1)
        return table.unpack(res)
    else
        worker_to_main:push({
            type = MessageType.ERROR,
            error = res[2],
            traceback = debug.traceback(),
            fatal = false
        })
    end
end

--[[

local _data = {}
local _id_to_data = {}
local _history_count = 120
local _active_timings = {}

function debugger.push(id)
    meta.assert(id, mt.String)
    _active_timings[id] = love.timer.getTime()
end

function debugger.pop(id, show_instant_time)
    local now = love.timer.getTime() -- measure before any code in pop is executed

    meta.assert(id, mt.String)

    local start_time = _active_timings[id]
    if start_time == nil then return end

    local elapsed = math.floor((now - start_time) / (1 / 60) * 1000) / 1000
    _active_timings[id] = nil

    local entry = _id_to_data[id]
    if entry == nil then
        entry = {
            id = id,
            max = -math.huge,
            history = table.rep(0, _history_count),
            sum = 0
        }

        _id_to_data[id] = entry
        table.insert(_data, entry)
    end

    entry.max = math.max(entry.max, elapsed)
    local first = entry.history[1]
    table.remove(entry.history, 1)
    table.insert(entry.history, elapsed)
    entry.sum = entry.sum - first + elapsed

    if entry.max == first then
        local new_max = -math.huge
        for t in values(entry.history) do
            new_max = math.max(new_max, t)
        end
        entry.max = new_max
    end
end

--- @brief
function debugger.report()
    if #_data == 0 then return end

    table.sort(_data, function(a, b)
        return a.max > b.max
    end)

    local max_id_length = 2
    for entry in values(_data) do
        if entry.max > 0 then
            max_id_length = math.max(max_id_length, #entry.id)
        end
    end

    println("")
    for entry in values(_data) do
        local mean = entry.sum / #entry.history
        if entry.max > 0 then
            println(string.format("| %-" .. max_id_length .. "s | mean: %.3f | max: %.3f |", entry.id, mean, entry.max))
        end
    end
    println("")
end
]]

local initialize = function()

end

local handle = function()

end

local report = function()

end

local success, error_maybe = pcall(function()
    local shutdown_active = true
    while true do
        local message
        if shutdown_active then
            -- worker through entire queue, then exit
            message = main_to_worker:pop()
            if message == nil then return end
        else
            message = main_to_worker:demand()
        end

        if message.type == MessageType.SHUTDOWN_REQUEST then
            shutdown_active = true
        elseif message.type == MessageType.INITIALIZE then
            initialize()
        elseif message.type == MessageType.REPORT_REQUEST then
            local str = report()
            worker_to_main:push({
                type = MessageType.RESPONSE,
                report = str
            })
        elseif message.type == MessageType.DUMPSTACK then
            local dump = message.stackdump
            handle(dump)
        else
            worker_to_main:push({
                type = MessageType.ERROR,
                error = "In profiler_worker: unhandled message type `" .. tostring(message.type) .. "`"
            })
        end
    end
end)

if success then
    worker_to_main:push({
        type = MessageType.SHUTDOWN_RESPONSE
    })
else
    worker_to_main:push({
        type = MessageType.ERROR,
        error = error_maybe
    })
end



