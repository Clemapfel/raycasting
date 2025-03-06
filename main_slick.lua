require "include"
require "physics.physics"

local shapes = {
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

local min_x, min_y = math.huge, math.huge
for entry in values(shapes) do
    for i = 1, #entry.vertices, 2 do
        min_x = math.min(min_x, entry.vertices[i])
        min_y = math.min(min_y, entry.vertices[i+1])
    end
end

local true_shapes = {}
for entry in values(shapes) do
    local translated = {}
    for i = 1, #entry.vertices, 2 do
        table.insert(translated, entry.vertices[i] - min_x)
        table.insert(translated, entry.vertices[i+1] - min_y)
    end
    table.insert(true_shapes, translated)
end


love.draw = function()
    love.graphics.push()
    for _, vertices in pairs(true_shapes) do
        love.graphics.setColor(1, 1, 1, 0.2)
        love.graphics.polygon("fill", vertices)

        love.graphics.setColor(1, 1, 1, 0.8)
        love.graphics.polygon("line", vertices)
    end
    love.graphics.pop()
end