_G.DEBUG = false

require "include"
require "common.label"

local SceneManager = require "common.scene_manager"

local x, y = love.mouse.getPosition()

require "overworld.text_box"
local box = ow.TextBox("debug_dialog")

love.load = function(args)
    local data = love.image.newImageData("assets/sprites/cursor.png")
    local cursor = love.mouse.newCursor(data)
    --love.mouse.setCursor(cursor, data:getWidth(), data:getHeight())

    require "overworld.overworld_scene"
    SceneManager:set_scene(ow.OverworldScene, "debug_stage")

    local joystick = love.joystick.getPosition
end

local start = true
love.update = function(delta)
    if love.keyboard.isDown("space") then start = true end

    if start then
        SceneManager:update(delta)
    end
end

love.draw = function()
    SceneManager:draw()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end