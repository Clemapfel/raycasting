require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"

require "overworld.player_recorder_eyes"
local eyes = ow.PlayerRecorderEyes(100)

require "common.input_subscriber"

local point = { 0, 0 }
input = rt.InputSubscriber()
input:signal_connect("pressed", function(_, which)
    local delta = 1
    if which == rt.InputAction.RIGHT then
        point[1] = point[1] - delta
    elseif which == rt.InputAction.LEFT then
        point[1] = point[1] + delta
    elseif which == rt.InputAction.UP then
        point[2] = point[2] + delta
    elseif which == rt.InputAction.DOWN then
        point[2] = point[2] - delta
    end

    --eyes:look_at(table.unpack(point))
end)

love.load = function(args)
    local w, h = love.graphics.getDimensions()

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
    --rt.SceneManager:push(ow.OverworldScene, "tutorial", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene)

    require "overworld.result_screen_scene"
    --present()

    eyes:set_position(0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight())
end

local elapsed = 0
love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    eyes:update(delta)
    eyes:look_at(love.mouse.getPosition())
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    eyes:draw()
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize(width, height)
    end
end
