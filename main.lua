_G.DEBUG = false

require "include"
require "common.label"

local SceneManager = require "common.scene_manager"

local label = rt.Label("<outline_color=WHITE><color=BLACK>BIG</color></outline_color>", rt.settings.font.default_huge)
label:realize()
label:reformat(50, 50)

love.load = function(args)
    require "overworld.overworld_scene"
    SceneManager:set_scene(ow.OverworldScene, "debug_stage")
end

local start = false
love.update = function(delta)
    if love.keyboard.isDown("space") then start = true end

    if start then
        SceneManager:update(delta)
    end
end

love.draw = function()
    SceneManager:draw()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end