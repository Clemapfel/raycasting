DEBUG = false

if unpack == nil then unpack = table.unpack end
io.stdout:setvbuf("no")
io.stderr:setvbuf("no")

require "object"
require "functional"
require "tables"
require "log"
require "globals"
require "input"
require "math"
require "aabb"
require "polyline"
require "lag"
require "random"
require "graphics"
require "audio"
require "mesh"
require "texture"
require "render_texture"
require "color"
require "palette"
require "cursor"
require "upscaler"
require "label"
require "control_indicator"
require "softbody"
require "player"
require "stage"

if DEBUG then
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
end

love.load = function()
    require "stage_scene"
    require "main_menu_scene"
    require "skin_select_scene"
    require "stage_select_scene"
    require "settings_scene"
    require "state"

    STATE = state_new()
    state_allocate_scenes(STATE)
    state_set_scene(STATE, MainMenuScene_t)
    state_push_scene(STATE, SettingsScene_t)
end

input_connect_pressed(function(which)
    if which == input_action_debug then
        love.load()
    end
end)

love.resize = function(w, h)
    if DEBUG then
        rt.SceneManager:resize() -- TODO
    end

    state_resize(STATE, w, h)
end

love.update = function(delta)
    if DEBUG then
        rt.SceneManager:update(delta) -- TODO
    end

    state_update(STATE, delta)
end

love.draw = function()
    graphics_notify_start_of_frame()

    if DEBUG then
        rt.SceneManager:draw() -- TODO
    end

    state_draw(STATE)
    cursor_draw()

    graphics_notify_end_of_frame()
end
