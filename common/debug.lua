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
        rt.warning("In debugger.reload: error when parsing file at `" .. path.. "`: " .. chunk_or_error)
        return
    end

    if love_error ~= nil then
        rt.warning("In debugger.reload: error when loading file at `" .. path .. "`: " .. love_error)
        return
    end

    local chunk_success, config_or_error = pcall(chunk_or_error)
    if not chunk_success then
        rt.warning("In debugger.reload: error when running file at `" .. path .. "`: " .. config_or_error)
        return
    end

    DBG = config_or_error

    if not _is_first_load then
        rt.log("successfully loaded dbg.lua")
    end
    _is_first_load = false
end
debugger.reload()

--- @brief
function debugger.get(key)
    return DBG[key]
end