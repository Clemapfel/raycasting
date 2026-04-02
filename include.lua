---@diagnostic disable: unnecessary-if
ENABLE_DEBUGGER = true -- if true, love errorhandler invokes debugger
require "common.splash_screen" -- splash screen during compilation

-- standard library extension

ffi = require "ffi"
utf8 = require "utf8"
bit = require "bit"

require "common.common"
require "common.math"
require "common.meta"

-- load love language server definitions

if false then
    love = {}
    math = {}
    ffi = {}
    utf8 = {}
end


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

-- globals
if rt == nil then rt = {} end -- common
if mn == nil then mn = {} end -- menu
if ow == nil then ow = {} end -- overworld
if b2 == nil then b2 = {} end -- physics (box2d)
if bd == nil then bd = {} end -- build

if rt.graphics == nil then rt.graphics = {} end

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
    margin_unit = 10,
    native_height = 600
}, true)

function rt.get_pixel_scale()
    return love.graphics.getHeight() / rt.settings.native_height
end

