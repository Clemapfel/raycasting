_G.DEBUG = false

require "include"

local SceneManager = require "common.scene_manager"
require "menu.main_menu_scene"

require "overworld.camera"
local camera = ow.Camera()

require "overworld.stage"
local stage = ow.Stage("debug_stage")

love.load = function(args)
    SceneManager:set_scene(mn.MainMenuScene)
end

love.update = function(delta)
    SceneManager:update(delta)

    camera:update(delta)
    stage:update(delta)
end

love.draw = function()
    DRAW_ACTIVE = true
    --SceneManager:draw()

    camera:bind()
    stage:draw()
    --stage._config:draw()
    camera:unbind()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end