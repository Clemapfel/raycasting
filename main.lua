require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"

--require "overworld.result_screen"
--local screen = ow.ResultScreen()
--screen:realize()

love.load = function(args)
    -- intialize all scenes
    require "overworld.overworld_scene"
    rt.SceneManager:push(ow.OverworldScene, "tutorial", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene)

    local w, h = love.graphics.getDimensions()
    --screen:reformat(0, 0, w, h)
    --screen:present(0.25 * w, 0.5 * h)
end

love.update = function(delta)
    rt.SceneManager:update(delta)

    --screen:update(delta)
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    rt.SceneManager:draw()

    --screen:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end
