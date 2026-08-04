require("common.splash_screen")("loading...") -- splash screen during compilation

-- standard library extension

ffi = nil
do
    local ffi_success, ffi_maybe = pcall(require, "ffi")
    if ffi_success == true then
        ffi = ffi_maybe
    else
        ffi = nil
    end
end

utf8 = require "utf8"
bit = require "bit"

require "common.alias"
require "common.common"
require "common.math"
require "common.meta"

-- load love language server definitions

if _G.DEBUG then
    --- @alias Nil nil
    --- @alias Number number
    --- @alias String string
    --- @alias Boolean boolean
    --- @alias Table table
    --- @alias Function function
    --- @alias Any any
    --- @alias Integer number
    --- @alias Radians number
    --- @alias Degrees number
    --- @alias Union table

    require "love.definitions.audio"
    require "love.definitions.data"
    require "love.definitions.event"
    require "love.definitions.filesystem"
    require "love.definitions.font"
    require "love.definitions.graphics"
    require "love.definitions.image"
    require "love.definitions.joystick"
    require "love.definitions.keyboard"
    require "love.definitions.math"
    require "love.definitions.mouse"
    require "love.definitions.physics"
    require "love.definitions.sound"
    require "love.definitions.system"
    require "love.definitions.thread"
    require "love.definitions.timer"
    require "love.definitions.touch"
    require "love.definitions.video"
    require "love.definitions.window"
end

-- globals
if rt == nil then rt = {} end -- common
if mn == nil then mn = {} end -- menu
if ow == nil then ow = {} end -- overworld
if b2 == nil then b2 = {} end -- physics
if bd == nil then bd = {} end -- build

for id, t in pairs({
    { "_G", _G},
    { "rt", rt },
    { "rt.graphics", rt.graphics },
    { "mn", mn },
    { "bd", bd },
    { "ow", ow },
    { "b2", b2 },
    { "meta", meta }
}) do
    setmetatable(t, {
        __index = function(self, key)
            error("In " .. id .. "." .. key .. ": trying to access `" .. key .. "`, but no such value exists in table `" .. id .. "`")
        end
    })
end

require "common.log"

rt.settings = meta.make_auto_extend({
    native_height = 600
}, true)



