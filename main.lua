require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

require "overworld.result_screen"
local screen = ow.ResultsScreen()
screen:realize()

require "common.cutscene_dialog_handler"
local handler = rt.DialogHandler()
handler:create_from({
    [1] = {
        speaker = "Self Speaker",
        orientation = "left",
        next = 2,

        "I am testing debug dialog, it has <b><wave><rainbow>fancy formatting</rainbow></wave></b>, too.",
    },

    [2] = {
        speaker = "Other Speaker",
        orientation = "right",

        "Are you <i>sure</i> this is the best way to implement it? It feels like you're just copying Mystery Dungeon.",

        next = {
            { "yes", 3 },
            { "no", 3 }
        }
    },

    [3] = {
        speaker = "Self Speaker",
        next = nil,

        "...||||", -- | = dialog beat unit
    },
})

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "j" then
        --background:recompile()
    elseif which == "space"then
        --[[
        screen:present(
            "1-1: Subluminalitiy",
            123, -- time
            rt.StageGrade.S,
            0.68, -- flow
            rt.StageGrade.A,
            8, 10, -- coins
            rt.StageGrade.B,
            rt.StageGrade.NONE
        )
        ]]--
    elseif which == "b" then
        screen:close()
    end
end)

love.load = function(args)
    -- intialize all scenes
    require "overworld.overworld_scene"
    --rt.SceneManager:push(ow.OverworldScene, "level_01", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene)

    require "overworld.stage_title_card_scene"
    --rt.SceneManager:push(ow.StageTitleCardScene, "tutorial")

    local screen_w, screen_h = love.graphics.getDimensions()
    local w = screen_w * (2 / 3)
    screen:reformat(0 + screen_w - w, 0, w, screen_h)

    handler:realize()
    handler:reformat(0, 0, screen_w, 2 / 3 * screen_h)
end

love.update = function(delta)
    rt.SceneManager:update(delta)

    handler:update(delta)
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    --rt.SceneManager:draw()

    handler:draw()
    handler:draw_bounds()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end

