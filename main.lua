require "include"
require "common.error_handler"

if _G.PROFILE then
    profiler = require "common.profiler"
end

if _G.DEBUG then
    debugger = require "common.debugger"
end

require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"
require "common.routine"

love.load = function(args)
    if PROFILE then profiler.push("love.load") end

    local before = love.timer.getTime()

    local result_screen = 1
    local overworld = 2
    local keybinding = 3
    local settings = 4
    local menu = 5

    for to_preallocate in range(
    -- result_screen
    --, overworld
    --, keybinding
    --, settings
    --, menu
    ) do
        if to_preallocate == result_screen then
            require "overworld.result_screen_scene"
            rt.SceneManager:preallocate(ow.ResultScreenScene)
        elseif to_preallocate == overworld then
            require "overworld.overworld_scene"
            rt.SceneManager:preallocate(ow.OverworldScene)
        elseif to_preallocate == keybinding then
            require "menu.keybinding_scene"
            rt.SceneManager:preallocate(mn.KeybindingScene)
        elseif to_preallocate == settings then
            require "menu.settings_scene"
            rt.SceneManager:preallocate(mn.SettingsScene)
        elseif to_preallocate == menu then
            require "menu.menu_scene"
            rt.SceneManager:preallocate(mn.MenuScene)
        end
    end

    require "overworld.overworld_scene"
    rt.SceneManager:push(ow.OverworldScene, "air_dash_node_tutorial", ow.StageEntryMode.INSTANT)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene, true)
end

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end
end

love.draw = function()
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize()
    end
end
