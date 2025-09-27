require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "common.sound_manager"

rt.SoundManager = rt.SoundManager() -- singleton instance

local to_allocate = {}
bd.apply("assets/sounds", function(path, name)
    if #to_allocate < 128 then
        table.insert(to_allocate, string.sub(name, 1, #name - 4))
        return true
    end
end)
rt.SoundManager:preallocate(to_allocate)

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    for i in range(1, 2, 3, 4, 5, 6, 7, 8, 9) do
        if which == tostring(i) then
            rt.SoundManager:play("0700 - Click", {
                position_x = rt.random.number(-10, 10),
                position_y = rt.random.number(-10, 10)
            })
        end
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

    rt.SoundManager:update(delta)
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    rt.SceneManager:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end
