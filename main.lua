require "include"

--debugger.connect()

require "common.label"

require "common.scene_manager"

require "common.mesh"
require "common.input_subscriber"


_input = rt.InputSubscriber()
_input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "p" then
        debugger.reload()
        dbg("dbg reload")
    end
end)

local player_x, player_y = 100, 100
local axis_x, axis_y = 1, 0.5

local points = {}
local n_segments, length, height = 30, 150, 40
for i = 1, n_segments do
    local fraction = i / n_segments
    local x, y = player_x + fraction * length * axis_x, player_y + fraction * length * axis_y

    local px, py = math.turn_left(axis_x, axis_y)
    local value = math.sin(fraction * math.pi * 4)
    x = x + value * px * height
    y = y + value * py * height

    table.insert(points, x)
    table.insert(points, y)
end

love.load = function(args)
    require "overworld.overworld_scene"
    rt.SceneManager:set_scene(ow.OverworldScene, "tutorial")
    love.resize(love.graphics.getDimensions())
end

love.update = function(delta)
    rt.SceneManager:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.line(points)
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end
