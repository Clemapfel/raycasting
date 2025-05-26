io.stdout:setvbuf("no") -- makes it so love2d error message is printed to console immediately

-- compat assertion
do
    local supported = love.graphics.getSupported()
    if supported.glsl4 ~= true or supported.shaderderivatives ~= true then
        error("In include.lua: This machine does not have a graphics card or graphics card driver capable of GLSL4. This game cannot run on this machine, we apologize for the inconvenience.")
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
rt.graphics = {}

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
require "common.debug"

rt.settings = meta.make_auto_extend({
    margin_unit = 10,
    native_height = 600
}, true)

function rt.get_pixel_scale()
    return love.graphics.getHeight() / rt.settings.native_height
end
