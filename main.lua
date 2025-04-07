require "include"
--debugger.connect()

require "common.label"

local SceneManager = require "common.scene_manager"

require "common.mesh"
require "common.input_subscriber"

_input = rt.InputSubscriber()
_input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "escape" then
        SceneManager:get_current_scene():reload()
    elseif which == "^" then
        debugger.reload()
    end
end)

love.load = function(args)
    require "overworld.overworld_scene"
    SceneManager:set_scene(ow.OverworldScene, "platformer_room")
    love.resize(love.graphics.getDimensions())
end

love.update = function(delta)
    SceneManager:update(delta)
end

love.draw = function()
    SceneManager:draw()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end