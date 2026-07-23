require "include"
require "common.error_handler"
require "build.config"
require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"
require "common.routine"

rt.GameState:set_draw_debug_information(false)
love.window.setMode(600, 300)

local x, y, w, h = 0, 0, 300, 300
local green   = function() return 0, 1, 0, 1 end
local cyan    = function() return 0, 1, 1, 1 end
local magenta = function() return 1, 0, 1, 1 end
local yellow  = function() return 1, 1, 0, 1 end
local center  = function() return 0.5, 0.75, 0.5, 1 end
local white = function() return 1, 1, 1, 1  end
local vertexData = {
    --    x,       y,     u,   v,   r, g, b, a
    { x + 0, y + 0,     0.25,   0.25,   white() },   -- #1
    { x + w, y + 0,     0.75,   0.25,   white() },    -- #2
    { x + w, y + h,     0.75,   0.75,   white() }, -- #3
    { x + 0, y + h,     0.25,   0.75,   white() },  -- #4
}

local rectangle = love.graphics.newMesh(vertexData, "fan", "dynamic")


local left = rt.Texture("assets/sprites/why.png"):get_native()
left:setFilter("nearest")

local right = rt.Texture("assets/sprites/why.png"):get_native()
right:setFilter("linear")

love.update = function(delta)
    local vertex = vertexData[5] -- center vertex
    local maxOffset = 40
    --vertex[1] = cx --+ maxOffset * ((love.math.perlinNoise(love.timer.getTime()) * 2) - 1)
    --vertex[2] = cy --+ maxOffset * ((love.math.perlinNoise(-1 * love.timer.getTime()) * 2) - 1)

    -- upload vertices
    rectangle:setVertices(vertexData)
end

love.draw = function()
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    rectangle:setTexture(left)
    love.graphics.draw(rectangle)

    love.graphics.push()
    love.graphics.translate(300, 0)
    rectangle:setTexture(right)
    love.graphics.draw(rectangle)
    love.graphics.pop()
end