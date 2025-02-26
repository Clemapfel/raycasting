io.stdout:setvbuf("no") -- makes it so love2d error message is printed to console immediately

-- debugger

_G.DEBUG = false
if _G.DEBUG then
    pcall(function()
        package.cpath = package.cpath .. ';C:/Users/cleme/AppData/Roaming/JetBrains/CLion2023.3/plugins/EmmyLua/debugger/emmy/windows/x64/?.dll'
        local dbg = require('emmy_core')
        dbg.tcpConnect('localhost', 8172)

        love.errorhandler = function(msg)
            dbg.breakHere()
            return nil -- exit
        end
    end)
end

-- standard library extension

ffi = require "ffi"
utf8 = require "utf8"
bit = require "bit"
require "common.common"
meta = require "common.meta"

-- globals

for name in range("rt", "mn") do
    _G[name] = setmetatable({}, {
        __index = function(self, key)
            error("In " .. name .. "." .. key .. ": trying to access `" .. key .. "`, but no such value exists in table " .. name .. "")
        end
    })
end

setmetatable(_G, {
    __index = function(self, key)
        error("In _G." .. key .. ": trying to access `" .. key .. "`, but no such value exists in table _G")
    end
})

require "common.log"

rt.settings = meta.make_auto_extend({
    margin_unit = 10
}, true)
