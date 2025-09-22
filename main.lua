require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"

local t = {}

function meta.make_auto_extend(x, recursive)
    if recursive == nil then recursive = false end
    local metatable = getmetatable(x)
    if metatable == nil then
        metatable = {}
    end

    metatable.__index = function(self, key)
        local out = {}
        self[key] = out

        if recursive then
            return meta.make_auto_extend(out, recursive)
        else
            return out
        end
    end

    return setmetatable(x, metatable)
end

meta.make_auto_extend(t, true)

t.x.y.z = 1234



require "common.music_manager_playback"
local playback_a = rt.MusicManagerPlayback("assets/music/debug_song_a/debug_song_a.mp3")
--playback_a:play()

local playback_b = rt.MusicManagerPlayback("assets/music/debug_song_b/debug_song_b.mp3")
--playback_b:play()

local mixer = rt.SmoothedMotionND()
mixer:add_dimension(meta.hash(playback_a))
mixer:add_dimension(meta.hash(playback_b))

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

love.update = function(delta)
    rt.SceneManager:update(delta)

    mixer:update(delta)

    playback_a:set_volume(mixer:get_dimension(meta.hash(playback_a)))
    playback_b:set_volume(mixer:get_dimension(meta.hash(playback_b)))

    playback_a:update()
    playback_b:update()
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    rt.SceneManager:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end
