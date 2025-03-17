local slick = require "physics.slick.slick" -- change this path

local _sin, _cos = math.sin, math.cos
local segments = {
    [1] = {
        ["x"] = 121.85400390625,
        ["y"] = 450.89001464844,
        ["radius"] = 13.5
    },
    [2] = {
        ["x"] = 108.35400390625,
        ["y"] = 450.89001464844,
        ["radius"] = 14
    },
    [3] = {
        ["x"] = 94.35400390625,
        ["y"] = 450.89001464844,
        ["radius"] = 12
    },
    [4] = {
        ["x"] = 82.35400390625,
        ["y"] = 450.89001464844,
        ["radius"] = 9
    }
}

local vertices = {}
local step = (2 * math.pi) / 32

for i, segment in ipairs(segments) do
    for angle = 0, 2 * math.pi + step, step do
        local x = segment.x + _cos(angle) * segment.radius
        local y = segment.y + _sin(angle) * segment.radius

        table.insert(vertices, x)
        table.insert(vertices, y)
    end
end

io.write("n_vertices: ", #vertices); io.flush()
local out = slick.polygonize({vertices})
io.write("done"); io.flush()
exit(0)


local world, player, rectangle, circle
local ray, normals = {}, {}

love.load = function()
    world = slick.newWorld(love.graphics.getDimensions())

    circle = {
        x = 50,
        y = 50,
        r = 30
    }
    circle.entity = world:add(circle, circle.x, circle.y, slick.newCircleShape(0, 0, circle.r))

    rectangle = {
        x = 200,
        y = 200,
        w = 40,
        h = 50
    }
    rectangle.entity = world:add(rectangle, rectangle.x, rectangle.y, slick.newRectangleShape(0, 0, rectangle.w, rectangle.h))

    player = {
        x = 140,
        y = 140,
        r = 10,
        velocity_x = 0,
        velocity_y = 0
    }
    player.entity = world:add(player, player.x, player.y, slick.newCircleShape(0, 0, player.r))
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

    -- cast ray
    if which == "space" then
        local px, py = player.x, player.y
        local mx, my = love.mouse.getPosition()
        local dx, dy = mx - px, my - py

        local responses, n_responses = world:queryRay(px, py, dx, dy, function() return true end)
        ray = {}
        normals = {}
        for i = 1, n_responses do
            local response = responses[i]
            table.insert(ray, response.touch.x)
            table.insert(ray, response.touch.y)

            table.insert(normals, {
                response.touch.x,
                response.touch.y,
                response.touch.x + 20 * response.normal.x,
                response.touch.y + 20 * response.normal.y
            })
        end
    end
end

love.keypressed = function(which)
    handle_key(which, true)
end

love.keyreleased = function(which)
    handle_key(which, false)
end

love.update = function(delta)
    player.x, player.y = world:move(player,
        player.x + player.velocity_x * delta,
        player.y + player.velocity_y * delta
    )
end

-- draw
love.draw = function()
    love.graphics.setColor(1, 0, 1, 0.4)
    love.graphics.circle("fill", player.x, player.y, player.r)

    local mouse_x, mouse_y = love.mouse.getPosition()
    love.graphics.circle("fill", mouse_x, mouse_y, 3)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.circle("fill", circle.x, circle.y, circle.r)
    love.graphics.rectangle("fill", rectangle.x, rectangle.y, rectangle.w, rectangle.h)

    if #ray >= 4 then
        love.graphics.setPointSize(5)
        love.graphics.points(ray)
        love.graphics.line(ray)
    end

    love.graphics.setColor(0, 1, 0, 1)
    for _, normal in pairs(normals) do
        love.graphics.line(normal)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf("Use Arrows or WASD to move | space to cast ray", 2, 2, math.huge)
end