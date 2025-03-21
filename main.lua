_G.DEBUG = false

require "include"
require "common.label"

local SceneManager = require "common.scene_manager"

local x, y = love.mouse.getPosition()

require "overworld.dialog_box"
local box = ow.DialogBox("debug_dialog")
local box_shown = false

require "common.background"
local bg = rt.Background("overworld/objects/shader_wall/mirror.glsl", true)
bg:realize()

require "common.input_subscriber"
input = rt.InputSubscriber()
input:signal_connect("pressed", function(_, which)
    if which == rt.InputButton.B then
        bg:recompile()
    elseif box_shown == false and which == rt.InputButton.A then
        box_shown = true
    else
        box:handle_button(which)
    end
end)



love.load = function(args)
    local data = love.image.newImageData("assets/sprites/cursor.png")
    local cursor = love.mouse.newCursor(data)
    --love.mouse.setCursor(cursor, data:getWidth(), data:getHeight())

    require "overworld.overworld_scene"
    SceneManager:set_scene(ow.OverworldScene, "debug_stage_alt_room")

    local joystick = love.joystick.getPosition

    box:realize()
    love.resize(love.graphics.getDimensions())
end

local start = true
love.update = function(delta)
    if love.keyboard.isDown("space") then start = true end

    SceneManager:update(delta)

    if box_shown then
        box:update(delta)
    end

    bg:update(delta)
end

love.draw = function()
    SceneManager:draw()

    if box_shown then
        box:draw()
    end

    --bg:draw()
end

love.resize = function(width, height)
    SceneManager:resize(width, height)

    box:reformat(0, 0, love.graphics.getDimensions())
    bg:reformat(0, 0, love.graphics.getDimensions())

end