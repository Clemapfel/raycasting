require "include"
local slick = require "physics.slick.slick"

-- raw data from my engine
local data = {
    [1] = {
        ["type"] = "polygon",
        ["vertices"] = {
            [1] = 1571.4665,
            [2] = 201.3818,
            [3] = 1557.1847,
            [4] = 191.59314,
            [5] = 1553.9753,
            [6] = 195.92582,
            [7] = 1553.9753,
            [8] = 196.08629,
            [9] = 1563.76395,
            [10] = 213.417
        }
    },
    [2] = {
        ["type"] = "polygon",
        ["vertices"] = {
            [1] = 1563.76395,
            [2] = 213.417,
            [3] = 1553.9753,
            [4] = 196.08629,
            [5] = 1549.3217,
            [6] = 203.14697,
            [7] = 1547.0751,
            [8] = 208.92388,
            [9] = 1545.4704,
            [10] = 214.8613,
            [11] = 1562.48019,
            [12] = 224.1685
        }
    },
    [3] = {
        ["type"] = "polygon",
        ["vertices"] = {
            [1] = 1562.48019,
            [2] = 224.1685,
            [3] = 1545.4704,
            [4] = 214.8613,
            [5] = 1545.4704,
            [6] = 223.0452,
            [7] = 1545.7913,
            [8] = 231.5501,
            [9] = 1563.92442,
            [10] = 232.192
        }
    },
    [4] = {
        ["type"] = "polygon",
        ["vertices"] = {
            [1] = 1563.92442,
            [2] = 232.192,
            [3] = 1545.7913,
            [4] = 231.5501,
            [5] = 1549.1612,
            [6] = 241.6597,
            [7] = 1569.21992,
            [8] = 239.2527
        }
    },
    [5] = {
        ["type"] = "polygon",
        ["vertices"] = {
            [1] = 1569.21992,
            [2] = 239.2527,
            [3] = 1549.1612,
            [4] = 241.6597,
            [5] = 1557.0242,
            [6] = 251.6089,
            [7] = 1566.33146,
            [8] = 258.0277,
            [9] = 1577.24341,
            [10] = 242.9435
        }
    },
    [6] = {
        ["type"] = "polygon",
        ["vertices"] = {
            [1] = 1577.24341,
            [2] = 242.9435,
            [3] = 1566.33146,
            [4] = 258.0277,
            [5] = 1576.2806,
            [6] = 261.7185,
            [7] = 1585.4274,
            [8] = 244.2273
        }
    },
    [7] = {
        ["type"] = "polygon",
        ["vertices"] = {
            [1] = 1585.4274,
            [2] = 244.2273,
            [3] = 1576.2806,
            [4] = 261.7185,
            [5] = 1585.5878,
            [6] = 262.3603,
            [7] = 1594.5742,
            [8] = 262.5208,
            [9] = 1593.6113,
            [10] = 243.2644
        }
    },
    [8] = {
        ["type"] = "polygon",
        ["vertices"] = {
            [1] = 1593.6113,
            [2] = 243.2644,
            [3] = 1594.5742,
            [4] = 262.5208,
            [5] = 1594.7346,
            [6] = 262.5208,
            [7] = 1604.6838,
            [8] = 259.7928,
            [9] = 1600.1906,
            [10] = 240.6969
        }
    },
    [9] = {
        ["type"] = "polygon",
        ["vertices"] = {
            [1] = 1600.1906,
            [2] = 240.6969,
            [3] = 1604.6838,
            [4] = 259.7928,
            [5] = 1613.6701,
            [6] = 253.695,
            [7] = 1604.8442,
            [8] = 237.1666
        }
    },
    [10] = {
        ["type"] = "polygon",
        ["vertices"] = {
            [1] = 1604.8442,
            [2] = 237.1666,
            [3] = 1613.6701,
            [4] = 253.695,
            [5] = 1758.5745,
            [6] = 114.2467,
            [7] = 1745.7365,
            [8] = 101.5695
        }
    }
}

-- process raw data to translate from map coordinates to screenspace
local min_x, min_y = math.huge, math.huge
for _, entry in pairs(data) do
    for i = 1, #entry.vertices, 2 do
        min_x = math.min(min_x, entry.vertices[i])
        min_y = math.min(min_y, entry.vertices[i+1])
    end
end

local offset_x, offset_y = 50, 50
local shapes = {}
for _, entry in pairs(data) do
    local translated = {}
    for i = 1, #entry.vertices, 2 do
        table.insert(translated, entry.vertices[i] - min_x + offset_x)
        table.insert(translated, entry.vertices[i+1] - min_y + offset_y)
    end
    table.insert(shapes, translated)
end

dbg(shapes)

local world, player
love.load = function()
    world = slick.newWorld(love.graphics.getDimensions())

    local id = 0
    for _, shape in pairs(shapes) do
        world:add(id, 0, 0, slick.newPolygonShape(shape))
        id = id + 1
    end

    local player_radius = 10
    local player_x, player_y = 0, 0
    player = {
        x = player_x,
        y = player_y,
        radius = player_radius,
        velocity_x = 0,
        velocity_y = 0,
        entity = nil
    }
    player.entity = world:add(player, player_x, player_y, slick.newCircleShape(0, 0, player_radius))
end

love.update = function(delta)
    player.x, player.y = world:move(
        player,
        player.x + delta * player.velocity_x,
        player.y + delta * player.velocity_y
    )
end

local handle_key = function(which, pressed_or_released)
    local max_velocity = 100
    local vx, vy = player.velocity_x, player.velocity_y
    if which == "left" then
        if pressed_or_released then
            vx = -1 * max_velocity
        else
            vx = 0
        end
    end

    if which == "right" then
        if pressed_or_released then
            vx = 1 * max_velocity
        else
            vx = 0
        end
    end

    if which == "up" then
        if pressed_or_released then
            vy = -1 * max_velocity
        else
            vy = 0
        end
    end

    if which == "down" then
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

love.draw = function()
    for _, vertices in pairs(shapes) do
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.polygon("fill", vertices)

        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.polygon("line", vertices)
    end

    love.graphics.setColor(1, 1, 1, 0.2)
    love.graphics.circle("fill", player.x, player.y, player.radius)

    love.graphics.setColor(1, 1, 1, 0.8)
    love.graphics.circle("fill", player.x, player.y, player.radius)
end