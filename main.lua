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
love.window.setMode(300, 300)

local x, y, w, h = 50, 50, 200, 200
local cx, cy = x + w / 2, y + h / 2
local vertices = {
    --    x,       y,     u,   v,   r, g, b, a
    { x + 0, y + 0,     0,   0,   1, 1, 1, 1 },   -- #1
    { x + w, y + 0,     1,   0,   1, 1, 1, 1 },    -- #2
    { x + w, y + h,     1,   1,   1, 1, 1, 1 }, -- #3
    { x + 0, y + h,     0,   1,   1, 1, 1, 1 },  -- #4
    { cx, cy, 0.5, 0.5, 1, 1, 1, 1 },   -- #5 center
}

local rectangle = love.graphics.newMesh(vertices,
    "triangles",
    "stream"
)
rectangle:setVertexMap(
    1, 2, 5,
    2, 3, 5,
    3, 4, 5,
    4, 1, 5
)
rectangle:setTexture(rt.Texture("assets/sprites/why.png"):get_native())

love.update = function(delta)
    local vertex = vertices[5] -- center vertex
    local maxOffset = 40
    vertex[1] = cx + maxOffset * ((love.math.perlinNoise(love.timer.getTime()) * 2) - 1)
    vertex[2] = cy + maxOffset * ((love.math.perlinNoise(-1 * love.timer.getTime()) * 2) - 1)

    -- upload vertices
    rectangle:setVertices(vertices)
end

love.draw = function()
    love.graphics.clear()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(rectangle)
end