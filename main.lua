require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

love.load = function(args)
    -- intialize all scenes
    require "overworld.overworld_scene"
    --rt.SceneManager:push(ow.OverworldScene, "tutorial")

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene)

    require "overworld.stage_title_card_scene"
    rt.SceneManager:push(ow.StageTitleCardScene, "tutorial")
end

love.update = function(delta)
    rt.SceneManager:update(delta)
    --texture:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()
    --love.graphics.origin()
    --texture:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end

