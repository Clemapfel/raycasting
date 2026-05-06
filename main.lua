require "build.config"
require "include"
require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"


local orb = require "orb"

love.load = function(args)
    local w, h = love.graphics.getDimensions()

    require "common.texture_format"
    local texture = rt.TextureScaleMode

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
    --rt.SceneManager:push(ow.OverworldScene, "introductions", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene) -- skip title

    --init()

    orb.initialize()
end

local elapsed = 0
local click_before = false

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    local mouse_x, mouse_y = love.mouse.getPosition()
    orb.set_position(mouse_x, mouse_y)

    elapsed = elapsed + delta
    local step = delta --rt.random.number(1 / 144, 1 / 30)
    while elapsed >= step do
        elapsed = elapsed - step
        orb.step(step)
        --step = rt.random.number(1 / 144, 1 / 30)
    end

    local click_now = love.mouse.isDown(1)
    if click_before == false and click_now == true then
        orb.agitate()
    end
    click_before = click_now
end

love.draw = function()
    love.graphics.clear(0.5, 0.5, 0.5, 1)

    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    orb.draw()
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize(width, height)
    end
end