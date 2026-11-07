if unpack == nil then unpack = table.unpack end
io.stdout:setvbuf("no")
io.stderr:setvbuf("no")

require "common.error_handler" -- TODO
require "common.scene_manager" -- TODO

require "jam.object"
require "jam.functional"
require "jam.table"
require "jam.log"
require "jam.input"
require "jam.math"
require "jam.graphics"
require "jam.polyline"
require "jam.lag"
require "jam.upscaler"
require "jam.boob"

STATE = {}
setmetatable(_G, {
    __newindex = function(self, key, value)
        --log_error("In _G.__newindex: trying to modify global `", key, "`, but the environment is immutable")
        return rawset(self, key, value)
    end,

    __index = function(self, key)
        --log_error("In _G.__index: trying to access global `", key, "`, but it is undefined")
        return rawget(self, key)
    end
})

love.load = function()
    local w, h = graphics_get_size()
    STATE.player = boob_init(boob_new(), 0.5 * w, 0.5 * h, 64, 32)
    STATE.upscaler = upscaler_new(love.graphics.getPixelDimensions())

    input_connect_pressed(input_action_accept, function(which)
        upscaler_queue_fade(STATE.upscaler, function()
            println("called")
        end)
    end)
end

love.resize = function()
    rt.SceneManager:resize() -- TODO
    upscaler_resize(STATE.upscaler, love.graphics.getPixelDimensions())
end

love.update = function(delta)
    rt.SceneManager:update(delta) -- TODO

    upscaler_update(STATE.upscaler, delta)
    boob_update(STATE.player, delta)
end

love.draw = function(delta)
    graphics_clear(0, 0, 0,0)
    rt.SceneManager:draw() -- TODO

    upscaler_bind(STATE.upscaler)
    graphics_clear(1, 0, 1, 1)
    boob_draw(STATE.player)
    upscaler_unbind(STATE.upscaler)
    upscaler_draw(STATE.upscaler)
end


