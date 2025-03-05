_G.DEBUG = true

require "include"
require "physics.physics"

local world, player, obstacle

love.load = function()
    local w, h = love.graphics.getDimensions()
    world = slick.newWorld(w, h)

    obstacle = {
        shape = b2.Rectangle(-50, -50, 100, 100),
        transform = slick.newTransform(0.5 * w, 0.5 * h, 0)
    }
    obstacle.id = world:add(obstacle, obstacle.transform, obstacle.shape._native)

    local player_radius = 20
    player = {
        shape = b2.Circle(0, 0, 50),
        transform = slick.newTransform(0.5 * w, 0.5 * h, 0)
    }
    player.id = world:add(player, player.transform, player.shape._native)

    --[[
    player.x, player.y = world:push(player, function()
        return true
    end, player.transform)
    ]]--
end

local ray_x1, ray_y1, ray_x2, ray_y2, ray_x3, ray_y3

love.update = function(delta)
    local x, y = love.mouse.getPosition()
    player.transform.x, player.transform.y = world:move(
        player,
        x, y
    )

    local angle = obstacle.transform.rotation
    local rotation_speed = 2 * math.pi / 10
    if love.keyboard.isDown("m") then
        angle = angle + rotation_speed * delta
    elseif love.keyboard.isDown("n") then
        angle = angle - rotation_speed * delta
    end

    local scale = obstacle.transform.scaleX
    local scale_speed = 1
    if love.keyboard.isDown("x") then
        scale = scale + scale_speed * delta
    elseif love.keyboard.isDown("y") then
        scale = scale - scale_speed * delta
    end

    obstacle.transform:setTransform(obstacle.transform.x, obstacle.transform.y, angle, scale, scale)
    obstacle.transform.x, obstacle.transform.y = world:update(obstacle, obstacle.transform)

    ray_x1, ray_y1 = player.transform.x, player.transform.y
    local ray_dx, ray_dy = obstacle.transform.x - player.transform.x, obstacle.transform.y - player.transform.y

    local responses, n, query = world:queryRay(
        ray_x1, ray_y1,
        ray_dx, ray_dy
    )
    debugger.breakHere()

    for i = 1, n do
        local response = responses[i]
        local normal_x, normal_y = response.normal.x, response.normal.y
        local contact_x, contact_y = response.touch.x, response.touch.y
        ray_x2, ray_y2 = contact_x, contact_y

        local normal_length = math.sqrt(normal_x^2 + normal_y^2)
        local nx = normal_x / normal_length
        local ny = normal_y / normal_length

        local dot_product = ray_dx * nx + ray_dy * ny

        local reflection_dx = ray_dx - 2 * dot_product * nx
        local reflection_dy = ray_dy - 2 * dot_product * ny
        reflection_dx = reflection_dx * -1
        reflection_dy = reflection_dy * -1

        ray_x3, ray_y3 = contact_x + reflection_dx * 100, contact_y + reflection_dy * 100
    end
end

love.draw = function()
    player.shape:draw(world:get(player).transform)
    obstacle.shape:draw(world:get(obstacle).transform)

    love.graphics.line(ray_x1, ray_y1, ray_x2, ray_y2, ray_x3, ray_y3)
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