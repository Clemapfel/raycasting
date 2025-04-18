require "include"
--debugger.connect()

require "common.label"

require "common.scene_manager"

require "common.mesh"
require "common.input_subscriber"

_input = rt.InputSubscriber()
_input:signal_connect("keyboard_key_pressed", function(_, which)

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