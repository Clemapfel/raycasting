require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

require "overworld.result_screen"
local screen = ow.ResultsScreen()
screen:realize()

require "overworld.fireworks"
local fireworks = ow.Fireworks()

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "j" then
        --background:recompile()
    elseif which == "space"then
        --[[
        screen:present(
            "1-1: Subluminality",
            123, -- time
            rt.StageGrade.S,
            0.68, -- flow
            rt.StageGrade.A,
            8, 10, -- coins
            rt.StageGrade.B,
            rt.StageGrade.S
        )
        ]]--
    elseif which == "n" then
        local w, h = love.graphics.getDimensions()

        local min_x, max_x = 50, w - 50
        local start_min_y, start_max_y = 0.75 * h, 1 * h - 50
        local end_min_y, end_max_y = 50, 0.25 * h

        local start_x, end_x = rt.random.number(min_x, max_x), rt.random.number(min_x, max_x)
        local start_y, end_y = rt.random.number(start_min_y, start_max_y), rt.random.number(end_min_y, end_max_y)

        fireworks:spawn(400,
            0.5 * love.graphics.getWidth(), 0.75 * love.graphics.getHeight(),
            start_x, start_y,
            end_x, end_y,
            0, 1
        )
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
end

love.update = function(delta)
    rt.SceneManager:update(delta)

    screen:update(delta)
    fireworks:update(delta)
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    rt.SceneManager:draw()

    --screen:draw()
    love.graphics.clear(0.5, 0.5, 0.5, 1)
    fireworks:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
    screen:reformat(0, 0, love.graphics.getDimensions())
end

