_G.DEBUG = false

require "include"
require "common.label"

local SceneManager = require "common.scene_manager"

-- TODO
require "common.mesh"
require "common.input_subscriber"

local m = 0
local mesh

function update_mesh()
    local cx, cy = 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight()
    local x_radius = 100
    local y_radius = 100

    local vertices = {}

    local n = 0
    local step = 2 * math.pi / 32
    for angle = 0, 2 * math.pi + step, step do
        local x = math.cos(angle)
        local y = math.sin(angle) * math.sin(0.5 * angle)^m
        local r, g, b, a = rt.hsva_to_rgba(angle / (2 * math.pi), 1, 1, 1)

        local tx = cx + x * x_radius
        local ty = cy + y * y_radius
        table.insert(vertices, {
            tx, ty, 0, 0, r, g, b, a
        })

        n = n + 1
    end

    table.insert(vertices, {
        cx, cy, 0, 0, 1, 1, 1, 1
    })

    local indices = {}
    local total_area = 0
    local areas = {}
    for i = 2, n do
        local i1, i2, i3 = i, i + 1, 1
        for index in range(i1, i2, i3) do
            table.insert(indices, index)
        end

        local x1, y1 = vertices[i1][1], vertices[i1][2]
        local x2, y2 = vertices[i2][1], vertices[i2][2]
        local x3, y3 = cx, cy
        local area = 0.5 * math.abs(x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2))
        areas[i] = area
        total_area = total_area + area
    end

    do
        local x1, y1 = vertices[n-1][1], vertices[n-1][2]
        local x2, y2 = vertices[n][1], vertices[n][2]
        local x3, y3 = cx, cy
        local area = 0.5 * math.abs(x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2))
        areas[1] = area
        total_area = total_area + area
    end

    local numerator = math.gamma((3 + m) / 2)
    local denominator = math.gamma(3 + m / 2)
    local analytic_area = 4 * math.sqrt(math.pi) * numerator / denominator
    dbg(total_area, analytic_area)

    local x_sum, y_sum, tri_n, total_fraction = 0, 0, 0, 0
    for i = 2, n do
        local i1, i2, i3 = i, i + 1, 1
        for index in range(i1, i2, i3) do
            table.insert(indices, index)
        end

        local x1, y1 = vertices[i1][1], vertices[i1][2]
        local x2, y2 = vertices[i2][1], vertices[i2][2]
        local x3, y3 = cx, cy
        local area = 0.5 * math.abs(x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2))
        local fraction = area / total_area

        x_sum = x_sum + (x1 + x2 + x3) * fraction
        y_sum = y_sum + (y1 + y2 + y3) * fraction
        total_fraction = total_fraction + fraction
        tri_n = tri_n + 3 * fraction
    end

    table.insert(vertices, 1,{
        x_sum / tri_n, y_sum / tri_n, 0, 0, 1, 1, 1, 1
    })

    mesh = rt.Mesh(vertices, rt.MeshDrawMode.TRIANGLES)
    mesh:set_vertex_map(indices)
end

update_mesh()
input = rt.InputSubscriber()
input:signal_connect("pressed", function(_, which)
    if which == rt.InputButton.UP then
        m = m + 1
        update_mesh()
    elseif which == rt.InputButton.DOWN then
        m = m - 1
        update_mesh()
    end
end)

-- TODO

love.load = function(args)
    require "overworld.overworld_scene"
    SceneManager:set_scene(ow.OverworldScene, "platformer_room")
    love.resize(love.graphics.getDimensions())
end

love.update = function(delta)
    SceneManager:update(delta)
end

love.draw = function()
    --SceneManager:draw()
    love.graphics.setWireframe(true)
    mesh:draw()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)
end