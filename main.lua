require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "common.profiler"

_input = rt.InputSubscriber()
_input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "p" then
        debugger.reload()
    elseif which == "backspace" then
    elseif which == "space" then
    end
end)

local contour
local ropes = {}

do
    local w, h = 400, 200
    local x, y = 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight()
    contour = {
        x - 0.5 * w, y,
        x + 0.5 * w, y,
    }
end

local target_x, target_y = 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight()
local n_ropes = 40
local n_segments = 100
local rope_length = 400
local circle_x, circle_y = 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight()
local circle_radius = 200

local n_rows = 20
local n_columns = 20
local screen_width, screen_height = love.graphics.getWidth(), love.graphics.getHeight()
local x_spacing = screen_width / (n_columns + 1)
local y_spacing = screen_height / (n_rows + 1)

love.load = function(args)
    require "common.path"

    for row = 1, n_rows do
        for col = 1, n_columns do
            local x = col * x_spacing
            local y = row * y_spacing

            local rope = {
                positions = {},
                old_positions = {},
                distances = {},
                anchor_x = x,
                anchor_y = y
            }

            for segment_i = 1, n_segments do
                local px, py = x, y - (segment_i - 1) / n_segments * rope_length
                table.insert(rope.positions, px)
                table.insert(rope.positions, py)
                table.insert(rope.old_positions, px)
                table.insert(rope.old_positions, py)
                table.insert(rope.distances, rope_length / n_segments)
            end

            table.insert(ropes, rope)
        end
    end

    require "overworld.overworld_scene"
    rt.SceneManager:set_scene(ow.OverworldScene, "tutorial")
end

local function _solve_bending_constraint(a_x, a_y, b_x, b_y, c_x, c_y, stiffness)
    local ab_x = b_x - a_x
    local ab_y = b_y - a_y
    local bc_x = c_x - b_x
    local bc_y = c_y - b_y

    ab_x, ab_y = math.normalize(ab_x, ab_y)
    bc_x, bc_y = math.normalize(bc_x, bc_y)

    local target_x = ab_x + bc_x
    local target_y = ab_y + bc_y

    local correction_x = target_x
    local correction_y = target_y

    local blend = 0.5 * stiffness
    a_x = a_x - correction_x * blend
    a_y = a_y - correction_y * blend
    c_x = c_x + correction_x * blend
    c_y = c_y + correction_y * blend

    return a_x, a_y, c_x, c_y
end

local stiffness = 1

function fabrik(positions, target_x, target_y, segment_lengths, anchor_x, anchor_y, tolerance, max_iterations)
    local num_segments = math.floor(#positions / 2)
    local error = math.huge
    local iteration_i = 0

    while error > tolerance and iteration_i < max_iterations do
        positions[#positions - 1], positions[#positions] = target_x, target_y
        for i = num_segments, 2, -1 do
            local x1, y1 = positions[2 * (i - 1) - 1], positions[2 * (i - 1)]
            local x2, y2 = positions[2 * i - 1], positions[2 * i]
            local dx, dy = x2 - x1, y2 - y1
            local dist = math.magnitude(dx, dy)
            local scale = segment_lengths[i - 1] / dist
            local new_x = x2 - dx * scale
            local new_y = y2 - dy * scale
            positions[2 * (i - 1) - 1] = x1 + (new_x - x1) * stiffness
            positions[2 * (i - 1)] = y1 + (new_y - y1) * stiffness
        end

        positions[1], positions[2] = anchor_x, anchor_y
        for i = 2, num_segments do
            local x1, y1 = positions[2 * (i - 1) - 1], positions[2 * (i - 1)]
            local x2, y2 = positions[2 * i - 1], positions[2 * i]
            local dx, dy = x2 - x1, y2 - y1
            local dist = math.magnitude(dx, dy)
            local scale = segment_lengths[i - 1] / dist
            local new_x = x1 + dx * scale
            local new_y = y1 + dy * scale
            positions[2 * i - 1] = x2 + (new_x - x2) * stiffness
            positions[2 * i] = y2 + (new_y - y2) * stiffness
        end

        local end_x, end_y = positions[#positions - 1], positions[#positions]
        error = math.magnitude(target_x - end_x, target_y - end_y)

        iteration_i = iteration_i + 1
    end
end

local velocity_damping = 0.8
love.update = function(delta)
    rt.SceneManager:update(delta)

    local x, y = love.mouse.getPosition()
    local tolerance = 0.05

    for rope in values(ropes) do
        local positions, old_positions = rope.positions, rope.old_positions
        fabrik(
            positions, x, y,
            rope.distances, rope.anchor_x, rope.anchor_y,
            0.5, 1
        )
    end
end

local colors = {}
for i = 1, n_segments do
    table.insert(colors, { rt.lcha_to_rgba(0.8, 1, (i - 1) / n_segments)} )
end

love.draw = function()
    rt.SceneManager:draw()

    love.graphics.setLineWidth(1)
    for rope in values(ropes) do
        local color_i = 1
        for i = 1, #rope.positions - 2, 2 do
            love.graphics.setColor(table.unpack(colors[color_i]))
            love.graphics.line(rope.positions[i], rope.positions[i+1], rope.positions[i+2], rope.positions[i+3])
            color_i = color_i + 1
        end
    end
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end