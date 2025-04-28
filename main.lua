require "include"

--debugger.connect()

require "common.label"

require "common.scene_manager"

require "common.mesh"
require "common.input_subscriber"

dbg(string.match("GPS:Ground Pos:28997.29:-6011.1:53247.73:#FFB1DCF1:", ":([%-%d%.]+):([%-%d%.]+):"))

_input = rt.InputSubscriber()
_input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "p" then
        debugger.reload()
        dbg("dbg reload")
    end
end)

love.load = function(args)
    require "overworld.overworld_scene"
    rt.SceneManager:set_scene(ow.OverworldScene, "boost_tutorial")
    love.resize(love.graphics.getDimensions())
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
