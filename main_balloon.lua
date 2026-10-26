require "include"
require "common.error_handler"

if _G.PROFILE then
    profiler = require "common.profiler"
end

if _G.DEBUG then
    debugger = require "common.debugger"
end

require "common.game_state"
require "common.scene_manager"

local balloon
local init = function()
    package.loaded["overworld.balloon"] = nil
    meta._typenames["Balloon"] = nil
    require "overworld.balloon"
    balloon = rt.Balloon()
    balloon:reformat(0, 0, love.graphics.getDimensions())
end

love.load = function(args)
    init()
    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == rt.KeyboardKey.K then
            init()
        end
    end)
end

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    if not love.keyboard.isDown("space") then
        balloon:update(delta)
    end
end

love.draw = function()
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    balloon:draw()
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize()
    end
end