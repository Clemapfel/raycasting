_G.DEBUG = true

require "include"

local SceneManager = require "common.scene_manager"

love.load = function(args)
    require "overworld.overworld_scene"
    SceneManager:set_scene(ow.OverworldScene, "debug_stage")
end

love.update = function(delta)
    SceneManager:update(delta)
end

love.draw = function()
    SceneManager:draw()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end