if unpack == nil then unpack = table.unpack end
io.stdout:setvbuf("no")
io.stderr:setvbuf("no")

require "common.error_handler" -- TODO
require "common.scene_manager" -- TODO

require "jam.object"
require "jam.log"
require "jam.math"
require "jam.graphics"
require "jam.upscaler"
require "jam.boob"

STATE = {}

love.load = function()
    local w, h = graphics_get_size()
    STATE.player = boob_init(boob_new(), 0.5 * w, 0.5 * h, 64, 32)
    STATE.upscaler = upscaler_new(love.graphics.getPixelDimensions())
end

love.resize = function()
    rt.SceneManager:resize() -- TODO
    upscaler_resize(STATE.upscaler, love.graphics.getPixelDimensions())
end

love.update = function(delta)
    rt.SceneManager:update(delta) -- TODO

    boob_update(STATE.player, delta)
end

love.draw = function(delta)
    rt.SceneManager:draw() -- TODO

    upscaler_bind(STATE.upscaler)
    boob_draw(STATE.player)
    upscaler_unbind(STATE.upscaler)
    upscaler_draw(STATE.upscaler)
end


