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
require "common.functional"

require "socials.social_media_banner_generator"
rt.GameState:set_draw_debug_information(false)

local downres = 1
rt.SocialMediaPlatform.YOUTUBE[1] = rt.SocialMediaPlatform.YOUTUBE[1] / downres
rt.SocialMediaPlatform.YOUTUBE[2] = rt.SocialMediaPlatform.YOUTUBE[2] / downres

local generator = rt.SocialMediaBannerGenerator(rt.SocialMediaPlatform.YOUTUBE)
DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == rt.KeyboardKey.Q then
        local before = love.timer.getTime()
        generator:regenerate()
        dbg(love.timer.getTime() - before)
    elseif which == rt.KeyboardKey.R then
        generator:update(1 / 30)
    elseif which == rt.KeyboardKey.U then
        generator:export()
    elseif which == rt.KeyboardKey.J then
        rt.SoundManager:pause()
    elseif which == rt.KeyboardKey.K then
        rt.SoundManager:unpause()
    elseif which == rt.KeyboardKey.M then
        rt.SoundManager:flush()
    end
end)

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
    --rt.SceneManager:push(ow.OverworldScene, "debug_room", ow.StageEntryMode.INSTANT)

    require "menu.keybinding_scene"
    rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    -- rt.SceneManager:push(mn.MenuScene, false)
end

local elapsed = 0
local n = 8

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    elapsed = elapsed + delta
    if elapsed > 1 / n then
        if love.keyboard.isDown("r") then
            generator:update(1 / n)
        end
        elapsed = 0
    end
end

love.draw = function()
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    --generator:draw()
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize()
    end

    generator:reformat(0, 0, width, height)
end
