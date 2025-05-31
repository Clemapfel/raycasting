require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "common.profiler"

local background = rt.Background("menu/settings_scene.glsl", true)
background:realize()
background:reformat(0, 0, love.graphics.getDimensions())

_input = rt.InputSubscriber()
_input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "p" then
        debugger.reload()
    elseif which == "r" then
        background:recompile()
    elseif which == "backspace" then
    elseif which == "space" then
    end
end)

love.load = function(args)
    require "menu.settings_scene"
    rt.SceneManager:set_scene(mn.SettingsScene)

    --require "overworld.overworld_scene"
    --rt.SceneManager:set_scene(ow.OverworldScene, "tutorial")
end


love.update = function(delta)
    rt.SceneManager:update(delta)

    background:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()

    background:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
    background:reformat(0, 0, width, height)
end
