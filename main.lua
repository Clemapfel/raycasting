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

love.load = function(args)
    --require "menu.stage_select_scene"
    --rt.SceneManager:set_scene(mn.StageSelectScene)

    --require "menu.menu_scene"
    --rt.SceneManager:set_scene(mn.MenuScene)

    require "overworld.overworld_scene"
    rt.SceneManager:set_scene(ow.OverworldScene, "tutorial")

    --love.resize(love.graphics.getDimensions())
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