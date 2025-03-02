require "include"

local SceneManager = require "common.scene_manager"
require "menu.main_menu_scene"

require "overworld.tileset"
local tileset = ow.Tileset("debug_tileset_objects")

require "overworld.stage_config"
local stage_config = ow.StageConfig("debug_stage")

love.load = function()
    SceneManager:set_scene(mn.MainMenuScene)
end

love.update = function(delta)
    SceneManager:update(delta)
end

love.draw = function()
    SceneManager:draw()
    stage_config:draw()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end