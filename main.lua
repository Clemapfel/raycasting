require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"

require "common.music_manager_interface"
rt.MusicManager = rt.MusicManagerInterface()

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "1" then
        rt.MusicManager:play("debug_song_a")
    elseif which == "2" then
        rt.MusicManager:play("debug_song_b")
    elseif which == "9" then
        if rt.MusicManager:get_is_paused() then
            rt.MusicManager:unpause()
            dbg("unpause")
        else
            rt.MusicManager:pause()
            dbg("pause")
        end
    elseif which == "3" then
        rt.MusicManager:set_volume(0.2)
    elseif which == "0" then
        rt.MusicManager:stop()
    end
end)

love.load = function(args)
    local w, h = love.graphics.getDimensions()

    local result_screen = 1
    local overworld = 2
    local keybinding = 3
    local settings = 4
    local menu = 5

    for to_preallocate in range(
        result_screen
        --, overworld
        --, keybinding
        --, settings
        --, menu
    ) do
        if to_preallocate == 1 then
            require "overworld.result_screen_scene"
            rt.SceneManager:preallocate(ow.ResultScreenScene)
        elseif to_preallocate == 2 then
            require "overworld.overworld_scene"
            rt.SceneManager:preallocate(ow.OverworldScene)
        elseif to_preallocate == 3 then
            require "menu.keybinding_scene"
            rt.SceneManager:preallocate(mn.KeybindingScene)
        elseif to_preallocate == 4 then
            require "menu.settings_scene"
            rt.SceneManager:preallocate(mn.SettingsScene)
        elseif to_preallocate == 5 then
            require "menu.menu_scene"
            rt.SceneManager:preallocate(mn.MenuScene)
        end
    end

    require "overworld.overworld_scene"
    rt.SceneManager:push(ow.OverworldScene, "tutorial", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene)

    require "overworld.result_screen_scene"
    --present()
end

local elapsed = 0
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
