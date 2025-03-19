_G.DEBUG = false

require "include"
require "common.label"

local SceneManager = require "common.scene_manager"

local x, y = love.mouse.getPosition()

require "overworld.dialog_box"
local box = ow.DialogBox("debug_dialog")

require "common.input_subscriber"
input = rt.InputSubscriber()
input:signal_connect("pressed", function(_, which)
    if which == rt.InputButton.A then
        box:advance()
    end
end)

love.load = function(args)
    local data = love.image.newImageData("assets/sprites/cursor.png")
    local cursor = love.mouse.newCursor(data)
    --love.mouse.setCursor(cursor, data:getWidth(), data:getHeight())

    require "overworld.overworld_scene"
    SceneManager:set_scene(ow.OverworldScene, "debug_stage")

    local joystick = love.joystick.getPosition

    box:realize()
    box:reformat(0, 0, love.graphics.getDimensions())
end

local start = true
love.update = function(delta)
    if love.keyboard.isDown("space") then start = true end

    if start then
        SceneManager:update(delta)
    end

    box:update(delta)
end

love.draw = function()
    SceneManager:draw()

    box:draw()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end