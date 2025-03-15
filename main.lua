require "include"
require "common.label"
require "overworld.player_body"

local SceneManager = require "common.scene_manager"

local rope = rt.Rope(200, 25, love.mouse.getPosition())
rope:realize()

love.load = function(args)
    local data = love.image.newImageData("assets/sprites/cursor.png")
    local cursor = love.mouse.newCursor(data)
    --love.mouse.setCursor(cursor, data:getWidth(), data:getHeight())

    require "overworld.overworld_scene"
    SceneManager:set_scene(ow.OverworldScene, "debug_stage")
end

local start = true
love.update = function(delta)
    if love.keyboard.isDown("space") then start = true end

    if start then
        SceneManager:update(delta)
    end

    rope:set_anchor(love.mouse.getPosition())
    rope:update(delta)
end

love.draw = function()
    SceneManager:draw()
    rope:draw()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end