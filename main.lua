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

require "common.rope"
local n_segments = 20
local rope_length = 800
local n_rows = 20
local n_columns = 20
local screen_width, screen_height = love.graphics.getWidth(), love.graphics.getHeight()
local x_spacing = screen_width / (n_columns + 1)
local y_spacing = screen_height / (n_rows + 1)
local ropes = {}

love.load = function(args)
    require "common.path"

    local y = love.graphics.getHeight()
    rope_length = love.graphics.getHeight()
    local n_ropes = 200
    for i = 1, n_ropes do
        local rope = rt.Rope(
            rope_length, n_ropes,
            (i - 1) / n_ropes * love.graphics.getWidth(), y,
            0, -1
        )

        table.insert(ropes, rope)
    end

    --require "overworld.overworld_scene"
    --rt.SceneManager:set_scene(ow.OverworldScene, "tutorial")
end
local unlocked = false

love.update = function(delta)
    rt.SceneManager:update(delta)

    if love.keyboard.isDown("space") then
        unlocked = true
    end

    if unlocked then
        local x, y = love.mouse.getPosition()
        for rope in values(ropes) do
            if rope:can_reach(x, y) then
                rope:set_target_position(x, y)
            end

            rope:update(delta)
        end
    end
end


love.draw = function()
    rt.SceneManager:draw()

    love.graphics.setLineWidth(1)
    local hue = 0
    for rope in values(ropes) do
        rt.LCHA(0.8, 1, hue, 1):bind()
        hue = hue + 1 / #ropes
        rope:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
    local x, y = love.mouse.getPosition()
    love.graphics.circle("fill", x, y, 5)
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end