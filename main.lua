require "include"
--debugger.connect()

require "common.label"

local SceneManager = require "common.scene_manager"

require "common.mesh"
require "common.input_subscriber"

local velocity = 1 -- ball velocity
local gravity = 1 -- gravity constant
local position = 0 -- position of the ball
local center = 0.5 -- position of the ball at rest
local stiffness = 10 -- stiffness of the spring
local damping = 0.9

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

    velocity = velocity + gravity + -1 * (position - center) * stiffness
    velocity = velocity * damping
    position = position + velocity * delta
end

love.draw = function()
    --SceneManager:draw()

    love.graphics.circle("fill", 100, 50 + position * 200, 30)
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end