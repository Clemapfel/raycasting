_G.DEBUG = false

require "include"
require "common.label"

local SceneManager = require "common.scene_manager"

require "common.mesh"
require "common.input_subscriber"

love.load = function(args)
    require "overworld.overworld_scene"
    SceneManager:set_scene(ow.OverworldScene, "platformer_room")
    love.resize(love.graphics.getDimensions())
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