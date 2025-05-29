require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "common.profiler"

_input = rt.InputSubscriber()
_input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "p" then
        debugger.reload()
    elseif which == "backspace" then
    elseif which == "space" then
    end
end)

require "menu.settings_scene"
local temp_scene = mn.SettingsScene()

require "menu.deadzone_visualization_widget"
local temp = mn.DeadzoneVisualizationWidget(temp_scene)
temp:realize()
temp:reformat(50, 50, 100, 100)

love.load = function(args)
    require "menu.menu_scene"
    rt.SceneManager:set_scene(mn.MenuScene)

    --require "overworld.overworld_scene"
    --rt.SceneManager:set_scene(ow.OverworldScene, "tutorial")
end

love.update = function(delta)
    rt.SceneManager:update(delta)

    temp:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()

    temp:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end