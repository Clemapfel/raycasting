local slick = require "physics.slick.slick" -- change this path
local USE_POLYGONAL_CIRCLE = true

-- shape data
local shapes = {
    [1] = {
        [1] = 68.29355,
        [2] = 161.8475,
        [3] = 58.5049,
        [4] = 144.51679,
        [5] = 53.8513,
        [6] = 151.57747,
        [7] = 51.6047,
        [8] = 157.35438,
        [9] = 50,
        [10] = 163.2918,
        [11] = 67.00979,
        [12] = 172.599
    },
    [2] = {
        [1] = 73.74952,
        [2] = 187.6832,
        [3] = 53.6908,
        [4] = 190.0902,
        [5] = 61.5538,
        [6] = 200.0394,
        [7] = 70.86106,
        [8] = 206.4582,
        [9] = 81.77301,
        [10] = 191.374
    },
    [3] = {
        [1] = 68.45402,
        [2] = 180.6225,
        [3] = 50.3209,
        [4] = 179.9806,
        [5] = 53.6908,
        [6] = 190.0902,
        [7] = 73.74952,
        [8] = 187.6832
    },
    [4] = {
        [1] = 109.3738,
        [2] = 185.5971,
        [3] = 118.1997,
        [4] = 202.1255,
        [5] = 263.1041,
        [6] = 62.6772,
        [7] = 250.2661,
        [8] = 50
    },
    [5] = {
        [1] = 104.7202,
        [2] = 189.1274,
        [3] = 109.2134,
        [4] = 208.2233,
        [5] = 118.1997,
        [6] = 202.1255,
        [7] = 109.3738,
        [8] = 185.5971
    },
    [6] = {
        [1] = 98.1409,
        [2] = 191.6949,
        [3] = 99.1038,
        [4] = 210.9513,
        [5] = 99.2642,
        [6] = 210.9513,
        [7] = 109.2134,
        [8] = 208.2233,
        [9] = 104.7202,
        [10] = 189.1274
    },
    [7] = {
        [1] = 67.00979,
        [2] = 172.599,
        [3] = 50,
        [4] = 163.2918,
        [5] = 50,
        [6] = 171.4757,
        [7] = 50.3209,
        [8] = 179.9806,
        [9] = 68.45402,
        [10] = 180.6225
    },
    [8] = {
        [1] = 89.957,
        [2] = 192.6578,
        [3] = 80.8102,
        [4] = 210.149,
        [5] = 90.1174,
        [6] = 210.7908,
        [7] = 99.1038,
        [8] = 210.9513,
        [9] = 98.1409,
        [10] = 191.6949
    },
    [9] = {
        [1] = 75.9961,
        [2] = 149.8123,
        [3] = 61.7143,
        [4] = 140.02364,
        [5] = 58.5049,
        [6] = 144.35632,
        [7] = 58.5049,
        [8] = 144.51679,
        [9] = 68.29355,
        [10] = 161.8475
    },
    [10] = {
        [1] = 81.77301,
        [2] = 191.374,
        [3] = 70.86106,
        [4] = 206.4582,
        [5] = 80.8102,
        [6] = 210.149,
        [7] = 89.957,
        [8] = 192.6578
    }
}

local world, player

love.load = function()
    -- create world
    world = slick.newWorld(love.graphics.getDimensions())

    -- add polygon shapes using anonymous id
    local id = 0
    for _, shape in pairs(shapes) do
        world:add(id, 0, 0, slick.newPolygonShape(shape))
        id = id + 1
    end

    -- init player
    local player_radius = 10
    local player_x, player_y = 5 * player_radius, 5 * player_radius
    player = {
        x = player_x,
        y = player_y,
        radius = player_radius,
        velocity_x = 0,
        velocity_y = 0,
        entity = nil
    }

    if USE_POLYGONAL_CIRCLE then
        local vertices = {}
        local center_x, center_y = 0, 0
        local x_radius, y_radius = player_radius, player_radius
        local n_outer_vertices = 16
        local angle_step = (2 * math.pi) / n_outer_vertices
        for angle = 0, 2 * math.pi, angle_step do
            table.insert(vertices, center_x + x_radius * math.cos(angle))
            table.insert(vertices, center_y + y_radius * math.sin(angle))
        end

        player.vertices = vertices
        player.entity = world:add(player, player_x, player_y, slick.newPolygonShape(vertices))
    else
        player.entity = world:add(player, player_x, player_y, slick.newCircleShape(0, 0, player.radius))
    end
end

-- update player position
love.update = function(delta)
    player.x, player.y = world:move(
        player,
        player.x + delta * player.velocity_x,
        player.y + delta * player.velocity_y
    )
end

-- handle input to move player
local handle_key = function(which, pressed_or_released)
    local max_velocity = 100
    local vx, vy = player.velocity_x, player.velocity_y
    if which == "left" or which == "a" then
        if pressed_or_released then
            vx = -1 * max_velocity
        else
            vx = 0
        end
    end

    if which == "right" or which == "d" then
        if pressed_or_released then
            vx = 1 * max_velocity
        else
            vx = 0
        end
    end

    if which == "up" or which == "w" then
        if pressed_or_released then
            vy = -1 * max_velocity
        else
            vy = 0
        end
    end

    if which == "down" or which == "s" then
        if pressed_or_released then
            vy = 1 * max_velocity
        else
            vy = 0
        end
    end

    player.velocity_x, player.velocity_y = vx, vy
end

love.keypressed = function(which)
    handle_key(which, true)
end

love.keyreleased = function(which)
    handle_key(which, false)
end

-- draw
love.draw = function()
    for _, vertices in pairs(shapes) do
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.polygon("fill", vertices)

        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.polygon("line", vertices)
    end

    if USE_POLYGONAL_CIRCLE then
        love.graphics.push()
        love.graphics.translate(player.x, player.y)
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.polygon("fill", player.vertices)

        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.polygon("line", player.vertices)
        love.graphics.pop()
    else
        love.graphics.push()
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.circle("fill", player.x, player.y, player.radius)

        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.circle("line", player.x, player.y, player.radius)
        love.graphics.pop()
    end

    love.graphics.printf("Use Arrows or WASD to move | player is polygon: " .. tostring(USE_POLYGONAL_CIRCLE), 10, 10, math.huge)
end