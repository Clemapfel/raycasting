require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

require "menu.stage_select_item"
local item = mn.StageSelectItem("tutorial")
item:realize()
item:reformat(0, 0, item:measure())

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "j" then
        debugger.reload()
    end
end)

love.load = function(args)
    local w, h = item:measure()
    --item:reformat(50, 50, 350, 1000)

    -- intialize all scenes
    require "overworld.overworld_scene"
    --rt.SceneManager:push(ow.OverworldScene, "tutorial", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    rt.SceneManager:push(mn.MenuScene)

    require "overworld.stage_title_card_scene"
    --rt.SceneManager:push(ow.StageTitleCardScene, "tutorial")
end

love.update = function(delta)
    rt.SceneManager:update(delta)
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    rt.SceneManager:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end

