DEBUG = true -- removed by build script
io.stdout:setvbuf("no") -- makes it so love2d error message is printed to console immediately
require "common.splash_screen" -- splash screen during compilation

if DEBUG then
    -- debugger
    debugger = {}
    local _debugger_active, _emmy_debugger = false
    function debugger.break_here()
        if _debugger_active == false then
            debugger.connect()
        end

        if _emmy_debugger ~= nil then
            _emmy_debugger.breakHere()
        end
    end
end

-- standard library extension

ffi = require "ffi"
utf8 = require "utf8"
bit = require "bit"

require "common.common"
meta = require "common.meta"

if DEBUG then
    -- load love language server definitions
    require "love.audio"
    require "love.data"
    require "love.event"
    require "love.filesystem"
    require "love.font"
    require "love.graphics"
    require "love.image"
    require "love.joystick"
    require "love.keyboard"
    require "love.math"
    require "love.mouse"
    require "love.physics"
    require "love.sound"
    require "love.system"
    require "love.thread"
    require "love.timer"
    require "love.touch"
    require "love.video"
    require "love.window"
end

-- globals
rt = {}
mn = {}
ow = {}
b2 = {}
bd = {}
rt.graphics = {}

for id, t in pairs({
    {"_G", _G},
    {"rt", rt},
    {"mn", mn},
    {"bd", bd},
    {"ow", ow},
    {"b2", b2},
    {"meta", meta}
}) do
    setmetatable(t, {
        __index = function(self, key)
            error("In " .. id .. "." .. key .. ": trying to access `" .. key .. "`, but no such value exists in table `" .. id .. "`")
        end
    })
end

require "common.log"

rt.settings = meta.make_auto_extend({
    margin_unit = 10,
    native_height = 600
}, true)

function rt.get_pixel_scale()
    return love.graphics.getHeight() / rt.settings.native_height
end

