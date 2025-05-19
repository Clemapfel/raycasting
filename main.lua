require "include"

--[[
require "common.scene_manager"

local n_points = 100 -- Number of points
local _dx = 0.1 -- Spatial step
local _dt = 0.05 -- Time step
local _damping = 0.99 -- Adjust this value for stronger or weaker damping
local _courant = _dt / _dx
local wave = {} -- Table to store wave states

-- Initialize wave solver
local function initialize_wave()
    wave.previous = table.rep(0, n_points)
    wave.current = table.rep(0, n_points)
    wave.next = {}
end

-- Update wave state with damping (viscosity)

local radius = 100
local center_x, center_y = radius * 2, radius * 2
local vertices = {}
for i = 1, n_points, 1 do
    local angle = (i - 1) * (2 * math.pi) / n_points
    table.insert(vertices, math.cos(angle))
    table.insert(vertices, math.sin(angle))
end

local function update_wave()
    for i = 1, n_points do
        local left = (i == 1) and n_points or (i - 1)
        local right = (i == n_points) and 1 or (i + 1)
        wave.next[i] = 2 * wave.current[i] - wave.previous[i] + _courant^2 * (wave.current[left] - 2 * wave.current[i] + wave.current[right])
        wave.next[i] = wave.next[i] * _damping -- Apply damping
    end
    wave.previous, wave.current, wave.next = wave.current, wave.next, wave.previous
end

local function excite_wave(center_index, amplitude, width)
    for i = 1, n_points do
        local distance = math.abs(i - center_index)
        distance = math.min(distance, n_points - distance)
        wave.current[i] = wave.current[i] + amplitude * math.exp(-((distance / width) ^ 2))
    end
end

function love.mousepressed(x, y, button)
    if button == 1 then -- Left mouse button
        local cursor_distance = math.sqrt((x - center_x)^2 + (y - center_y)^2)
        local amplitude = (radius - cursor_distance) / radius -- Proportional to distance from the boundary

        if cursor_distance < radius then
            amplitude = -math.abs(amplitude) -- Negative if inside
        else
            amplitude = math.abs(amplitude) -- Positive if outside
        end

        local min_distance, min_i = math.huge, nil
        for i = 1, #vertices, 2 do
            -- Scale vertex coordinates to screen space
            local vx = center_x + vertices[i] * radius
            local vy = center_y + vertices[i + 1] * radius
            local distance = math.distance(x, y, vx, vy)
            if distance < min_distance then
                min_distance = distance
                min_i = (i + 1) / 2
            end
        end

        if min_i then
            excite_wave(min_i, 0.1 * amplitude, 5) -- Excite with adjusted amplitude and width 5
        end
    end
end

-- Love2D callbacks
function love.load()
    initialize_wave()
end

function love.update(delta)
    update_wave()
end

function love.draw()
    local screen_width = love.graphics.getWidth()
    local screen_height = love.graphics.getHeight()
    local scale_x = screen_width / n_points
    local scale_y = screen_height / 2

    love.graphics.setColor(0, 0.5, 1)
    love.graphics.setLineWidth(2)

    local positions = {}

    local wave_i = 1
    for i = 1, #vertices, 2 do
        local vx, vy = vertices[i+0], vertices[i+1]
        local value = 1 + wave.current[wave_i]
        table.insert(positions, center_x + vx * radius * value)
        table.insert(positions,center_y + vy * radius * value
        )
        wave_i = wave_i + 1
    end

    table.insert(positions, positions[1])
    table.insert(positions, positions[2])

    local r, g, b, a = rt.Palette.GREEN_2:unpack()

    love.graphics.setColor(r, g, b, 0.4)
    love.graphics.polygon("fill", positions)
    love.graphics.setColor(r, g, b, 1)
    love.graphics.line(positions)

    for i = 1, n - 1 do
        local x1 = (i - 1) * scale_x
        local y1 = screen_height / 2 - wave.current[i] * scale_y
        local x2 = i * scale_x
        local y2 = screen_height / 2 - wave.current[i + 1] * scale_y
        love.graphics.line(x1, y1, x2, y2)
    end

end

]]--

--debugger.connect()


require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"

_input = rt.InputSubscriber()
_input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "p" then
        debugger.reload()
    end
end)

love.load = function(args)
    --require "menu.stage_select_scene"
    --rt.SceneManager:set_scene(mn.StageSelectScene)

    require "menu.title_screen_scene"
    rt.SceneManager:set_scene(mn.TitleScreenScene)

    --require "overworld.overworld_scene"
    --rt.SceneManager:set_scene(ow.OverworldScene, "tutorial")

    --love.resize(love.graphics.getDimensions())
end

love.update = function(delta)
    rt.SceneManager:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end
