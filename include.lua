io.stdout:setvbuf("no") -- makes it so love2d error message is printed to console immediately

-- compat assertion
do
    local supported = love.graphics.getSupported()
    if supported.glsl4 ~= true then
        error("In include.lua: This machine does not have a graphics card or graphics card driver capable of glsl4, which many advanced graphical effects require. This game cannot run on this machine, we apologize for the inconvenience.")
    end
end

-- splash screen

do
    local screen_w, screen_h = love.graphics.getWidth(), love.graphics.getHeight()
    love.graphics.setColor(0, 0, 0, 1)
    local label = "loading..."
    local font = love.graphics.newFont(0.15 * love.graphics.getHeight())
    local label_w, label_h = font:getWidth(label), font:getHeight(label)

    love.graphics.setColor(0, 0, 0, 1)
    love.graphics.rectangle("fill", 0, 0, screen_w, screen_h)

    local value = 0.3
    love.graphics.setColor(value, value, value, 1)
    love.graphics.print(label, font,
        math.floor(0.5 * screen_w - 0.5 * label_w),
        math.floor(0.5 * screen_h - 0.5 * label_h)
    )
    love.graphics.present()
end

-- debugger
if _G.DEBUG == nil then _G.DEBUG = false end
if _G.DEBUG == true then
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
rt = {}
mn = {}
ow = {}

for _, t in pairs({
    {"_G", _G},
    {"rt", rt},
    {"mn", mn},
    {"ow", ow},
    {"meta", meta}
}) do
    setmetatable(t, {
        __index = function(self, key)
            error("In _G." .. key .. ": trying to access `" .. key .. "`, but no such value exists in table _G")
        end
    })
end


require "common.log"

rt.settings = meta.make_auto_extend({
    margin_unit = 10
}, true)
