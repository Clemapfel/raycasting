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

require "menu.verbose_info_panel"
local temp = mn.VerboseInfoPanel()
temp:realize()
local w, h = love.graphics.getDimensions()
temp:reformat(50, 50, w - 50 * 2, h - 50 * 2)
temp:show(
    rt.VerboseInfoObject.VSYNC,
    rt.VerboseInfoObject.FULLSCREEN,
    rt.VerboseInfoObject.MSAA,
    rt.VerboseInfoObject.MSAA_WIDGET,
    rt.VerboseInfoObject.SOUND_EFFECT_LEVEL,
    rt.VerboseInfoObject.MUSIC_LEVEL,
    rt.VerboseInfoObject.SHAKE_ENABLED,
    rt.VerboseInfoObject.DEADZONE,
    rt.VerboseInfoObject.DEADZONE_WIDGET,
    rt.VerboseInfoObject.TEXT_SPEED,
    rt.VerboseInfoObject.TEXT_SPEED_WIDGET
)

_input:signal_connect("pressed", function(_, which)
    if which == rt.InputButton.UP then
        temp:scroll_up()
    elseif which == rt.InputButton.DOWN then
        temp:scroll_down()
    end
end)

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