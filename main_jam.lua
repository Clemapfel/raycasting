if unpack == nil then unpack = table.unpack end
io.stdout:setvbuf("no")
io.stderr:setvbuf("no")

require "common.error_handler" -- TODO
require "common.scene_manager" -- TODO

require "jam.object"
require "jam.functional"
require "jam.table"
require "jam.log"
require "jam.globals"
require "jam.input"
require "jam.math"
require "jam.random"
require "jam.graphics"
require "jam.audio"
require "jam.mesh"
require "jam.texture"
require "jam.render_texture"
require "jam.color"
require "jam.palette"
require "jam.cursor"
require "jam.polyline"
require "jam.aabb"
require "jam.lag"
require "jam.upscaler"
require "jam.label"
require "jam.control_indicator"
require "jam.softbody"
require "jam.player"
require "jam.stage"

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
    require "jam.stage_scene"
    require "jam.main_menu_scene"
    require "jam.skin_select_scene"
    require "jam.stage_select_scene"
    require "jam.settings_scene"

    require "jam.state" -- wait for init
    state_set_scene(MainMenuScene_t)
end

input_connect_pressed(function(which)
    if which == input_action_debug then
        love.load()
    end
end)

love.resize = function(w, h)
    rt.SceneManager:resize() -- TODO
    state_resize(w, h)
end

love.update = function(delta)
    rt.SceneManager:update(delta) -- TODO

    state_update(delta)
end

love.draw = function()
    graphics_notify_start_of_frame()

    rt.SceneManager:draw() -- TODO

    state_draw()
    cursor_draw()

    graphics_notify_end_of_frame()
end


