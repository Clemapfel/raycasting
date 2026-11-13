DEBUG = true

if unpack == nil then unpack = table.unpack end
io.stdout:setvbuf("no")
io.stderr:setvbuf("no")

local _require = _G.require
if DEBUG then
    _require = function(x)
        _G.require("jam." .. x)
    end
end

_require "include.object"
_require "include.functional"
_require "include.table"
_require "include.log"
_require "include.globals"
_require "include.input"
_require "include.math"
_require "include.aabb"
_require "include.polyline"
_require "include.delaunay"
_require "include.lag"
_require "include.random"
_require "include.graphics"
_require "include.audio"
_require "include.mesh"
_require "include.shader"
_require "include.texture"
_require "include.render_texture"
_require "include.color"
_require "include.palette"
_require "include.cursor"
_require "include.upscaler"
_require "include.label"
_require "include.control_indicator"
_require "include.softbody"
_require "include.player"
_require "include.stage"

if DEBUG then
    require "include"
    require "common.error_handler"

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

     input_connect_pressed(function(which)
        if which == input_action_debug then
            for k, v in pairs(package.loaded) do
                package.loaded[k] = nil
            end

            dbg("called")
            love.load()
        end
    end)
end

love.load = function()
    _require "include.stage_scene"
    _require "include.main_menu_scene"
    _require "include.skin_select_scene"
    _require "include.stage_select_scene"
    _require "include.settings_scene"
    _require "include.state"

    STATE = state_new()
    state_allocate_scenes(STATE)
    state_set_scene(STATE, MainMenuScene_t)
    state_push_scene(STATE, StageScene_t, "jump_introduction")
end

input_connect_pressed(function(which)
    if which == input_action_debug then
        love.load()
    end
end)

love.resize = function(w, h)
    state_resize(STATE, w, h)
end

love.update = function(delta)
    state_update(STATE, delta)
end

local shader

love.draw = function()
    graphics_notify_start_of_frame()

    if shader == nil then
        shader = shader_new("assets/shaders/test.glsl")
    end

    state_draw(STATE)
    graphics_notify_end_of_frame()
end
