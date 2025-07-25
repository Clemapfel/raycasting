require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

require "overworld.result_screen"
local screen = ow.ResultsScreen()
screen:realize()

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "j" then
        debugger.reload()
    elseif which == "space"then
        if screen:get_is_active() then
            screen:close()
        else
            screen:present(
                "Title of Stage that is Long",
                123, -- time
                rt.StageGrade.S,
                0.68, -- flow
                rt.StageGrade.A,
                8, 10, -- coins
                rt.StageGrade.B,
                rt.StageGrade.NONE
            )
        end
    end
end)

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

    require "overworld.stage_title_card_scene"
    --rt.SceneManager:push(ow.StageTitleCardScene, "tutorial")

    local screen_w, screen_h = love.graphics.getDimensions()
    local w = screen_w / 2
    screen:reformat(0 + screen_w - w, 0, w, screen_h)
end

love.update = function(delta)
    rt.SceneManager:update(delta)

    screen:update(delta)
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    rt.SceneManager:draw()

    screen:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end

