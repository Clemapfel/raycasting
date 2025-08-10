require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

require "overworld.result_screen"
local screen = ow.ResultsScreen()
screen:realize()

require "overworld.shatter_surface"
local surface = nil

local allow_update = false

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
        local before = love.timer.getTime()
        surface:shatter(rt.random.number(0.25, 0.75) * w, rt.random.number(0.25, 0.75) * h)
        allow_update = false
        dbg((love.timer.getTime() - before) / (1 / 60))
    elseif which == "m" then
        allow_update = true
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

    local w, h = love.graphics.getDimensions()
    surface = ow.ShatterSurface(0, 0, w, h)
    surface:shatter(0.5 * w, 0.5 * h)
end

love.update = function(delta)
    rt.SceneManager:update(delta)
    screen:update(delta)

    if allow_update then
        surface:update(delta)
    end
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    rt.SceneManager:draw()
    love.graphics.clear(0.5, 0.5, 0.5, 1)
    --screen:draw()

    surface:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
    screen:reformat(0, 0, love.graphics.getDimensions())
end

