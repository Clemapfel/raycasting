require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "common.profiler"

_input = rt.InputSubscriber()
_input:signal_connect("keyboard_key_pressed", function(_, which)
    --[[
    if which == "p" then
        debugger.reload()
    elseif which == "r" then
        background:recompile()
    elseif which == "1" then
        require "menu.settings_scene"
        rt.SceneManager:set_scene(mn.SettingsScene)
    elseif which == "2" then
        require "overworld.overworld_scene"
        rt.SceneManager:set_scene(ow.OverworldScene, "tutorial")
    elseif which == "3" then
        require "menu.keybinding_scene"
        rt.SceneManager:set_scene(mn.KeybindingScene)
    end
    ]]--
end)

love.load = function(args)
    -- intialize all scenes
    require "overworld.overworld_scene"
    rt.SceneManager:push(ow.OverworldScene, "tutorial")

    --[[
    require "menu.keybinding_scene"
    rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    rt.SceneManager:push(mn.MenuScene)
    ]]--
end

love.update = function(delta)
    rt.SceneManager:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end
