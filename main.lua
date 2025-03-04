require "include"

local SceneManager = require "common.scene_manager"
require "menu.main_menu_scene"

require "overworld.camera"
local camera = ow.Camera()

require "overworld.stage"
local stage = ow.Stage("debug_stage")

love.load = function()
    SceneManager:set_scene(mn.MainMenuScene)
end

love.update = function(delta)
    SceneManager:update(delta)

    camera:update(delta)
end

love.draw = function()
    --SceneManager:draw()

    camera:bind()
    stage:draw()
    --stage._config:draw()
    camera:unbind()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end