_G.DEBUG = false

require "include"
require "physics.physics"

local world
local floor, player, obstacle

local _fill_a = 0.3
local _line_a = 1

love.load = function()
    local w, h = love.graphics.getDimensions()
    world = slick.newWorld(w, h)

    obstacle = {
        x = 0.5 * w,
        y = 0.5 * h,
        shape = b2.Rectangle(-50, -50, 100, 100),
        angle = 0
    }
    obstacle.id = world:add(obstacle, obstacle.x, obstacle.y, obstacle.shape._native)

    local player_radius = 20
    player = {
        x = 0.5 * w,
        y = 0.5 * h,
        shape = b2.Circle(0, 0, 50),
        angle = 0
    }
    player.id = world:add(player, player.x, player.y, player.shape._native)

    player.x, player.y = world:push(player, function()
        return true
    end, player.x, player.y)
end

love.update = function(delta)
    local x, y = love.mouse.getPosition()

    --[[
    local dx, dy = x - player.x, y - player.y
    local speed = 100
    player.x, player.y = world:move(
        player,
        player.x + dx * delta * speed,
        player.y + dy * delta * speed
    )
    ]]--

    player.x, player.y = world:move(
        player,
        x, y
    )

    local angle = obstacle.angle
    local rotation_speed = 2 * math.pi / 100
    if love.keyboard.isDown("m") then
        angle = angle + rotation_speed * delta
    elseif love.keyboard.isDown("n") then
        angle = angle - rotation_speed * delta
    end
    if angle ~= obstacle.angle then
        obstacle.angle = angle
        obstacle.x, obstacle.y = world:update(obstacle, slick.newTransform(obstacle.x + delta, obstacle.y, obstacle.angle))
    end
end

love.draw = function()
    player.shape:draw(player.x, player.y, player.angle)
    obstacle.shape:draw(obstacle.x, obstacle.y, obstacle.angle)
end

--[[

local SceneManager = require "common.scene_manager"
require "menu.main_menu_scene"

require "overworld.camera"
local camera = ow.Camera()

require "overworld.stage"
local stage = ow.Stage("debug_stage")

love.load = function()
    SceneManager:set_scene(mn.MainMenuScene)
end

love.update = function(delta)
    SceneManager:update(delta)

    camera:update(delta)
end

love.draw = function()
    --SceneManager:draw()

    camera:bind()
    stage:draw()
    --stage._config:draw()
    camera:unbind()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end
]]--