debugger = {}
local _debugger_active, _emmy_debugger = false

--- @brief
function debugger.break_here()
    if _debugger_active == false then
        debugger.connect()
    end

    if _emmy_debugger ~= nil then
        _emmy_debugger.breakHere()
    end
end

--- @brief
function debugger.get_is_active()
    return _debugger_active
end

--- @brief
function debugger.connect()
    pcall(function()
        -- connect debugger only when required
        package.cpath = package.cpath .. ';C:/Users/cleme/AppData/Roaming/JetBrains/CLion2023.3/plugins/EmmyLua/debugger/emmy/windows/x64/?.dll'
        _emmy_debugger = require('emmy_core')
        _emmy_debugger.tcpConnect('localhost', 8172)

        love.errorhandler = function(msg)
            _emmy_debugger.breakHere()
            return nil
        end

        _debugger_active = true
    end)
end

--- ###

DBG = {}

local _is_first_load = true

--- @brief
function debugger.reload()
    local path = "dbg.lua"
    local load_success, chunk_or_error, love_error = pcall(love.filesystem.load, path)
    if not load_success then
        rt.warning("In debugger.reload: error when parsing file at `",  path.. "`: ",  chunk_or_error)
        return
    end

    if love_error ~= nil then
        rt.warning("In debugger.reload: error when loading file at `",  path,  "`: ",  love_error)
        return
    end

    local chunk_success, config_or_error = pcall(chunk_or_error)
    if not chunk_success then
        rt.warning("In debugger.reload: error when running file at `",  path,  "`: ",  config_or_error)
        return
    end

    DBG = config_or_error

    if not _is_first_load then
        rt.log("successfully loaded dbg.lua")
    end
    _is_first_load = false
end
debugger.reload()

require "common.input_subscriber"
debugger._input = rt.InputSubscriber()
debugger._input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "k" then
        debugger.reload()
    end
end)

--- @brief
function debugger.get(key)
    return DBG[key]
end

--- @brief
function debugger.traceback()
    return debug.traceback()
end

local _data = {}
local _id_to_data = {}
local _history_count = 120
local _active_timings = {}

function debugger.push(id)
    meta.assert(id, "String")
    _active_timings[id] = love.timer.getTime()
end

function debugger.pop(id)
    meta.assert(id, "String")

    local start_time = _active_timings[id]
    if start_time == nil then return end

    local elapsed = math.floor((love.timer.getTime() - start_time) / (1 / 60) * 1000) / 1000
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
function debugger.report(use_max)
    if #_data == 0 then return end

    table.sort(_data, function(a, b)
        return a.max > b.max
    end)

    local max_id_length = 2
    for entry in values(_data) do
        local value = ternary(use_max ~= false, entry.max, entry.sum / #entry.history)
        if value > 0 then
            max_id_length = math.max(max_id_length, #entry.id)
        end
    end

    println("")
    for entry in values(_data) do
        local value = ternary(use_max ~= false, entry.max, entry.sum / #entry.history)
        if value > 0 then
            println(string.format("| %-" .. max_id_length .. "s | %.3f |", entry.id, value))
        end
    end
    println("")
end

return debugger