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
require "jam.random"
require "jam.graphics"
require "jam.color"
require "jam.palette"
require "jam.cursor"
require "jam.polyline"
require "jam.aabb"
require "jam.lag"
require "jam.upscaler"
require "jam.softbody"
require "jam.player"
require "jam.stage"
require "jam.level_scene"

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

    local stage_list = stage_list_new()
    if love.getVersion() >= 12 then
        -- in dev env, export to file
        -- this is necessary because triangulation is unavailable in release mode
        local to_mount = love.filesystem.getSource() .. "/jam/assets"
        local mount_point = "stages"
        if not love.filesystem.mountFullPath(
            to_mount,
            mount_point,
            "readwrite",
            false
        ) then
            log_error("unable to mount path `", to_mount, "` to mount point `", mount_point, "`")
        end

        stage_list_export(
            stage_list,
            "jam/assets/stages.lua",
            "stages/stages_exported.lua"
        )

        love.filesystem.unmountFullPath(to_mount)
    end

    -- in release mode, import including triangulation
    stage_list_init(stage_list, "jam/assets/stages_exported.lua")

    STATE.stage_list = stage_list
    STATE.scene = level_scene_new(
        stage_new(STATE.stage_list, "Stage 01")
    )
end

input_connect_pressed(function(which)
    if which == input_action_debug then
        love.load()
    end
end)

require "common.palette"
dbg(rt.Palette)

love.resize = function()
    rt.SceneManager:resize() -- TODO
    upscaler_resize(love.graphics.getPixelDimensions())
end

love.update = function(delta)
    rt.SceneManager:update(delta) -- TODO

    upscaler_update(delta)

    local scene = STATE.scene
    if object_isa(scene, LevelScene_t) then
        level_scene_update(scene, delta)
    else
        log_error("in love.update: unhandled scene type `", object_typeof(STATE.scene), "`")
    end
end

love.draw = function()
    graphics_notify_start_of_frame()

    graphics_clear(0, 0, 0,0)
    rt.SceneManager:draw() -- TODO

    upscaler_bind()
    graphics_clear(1, 0, 1, 1)

    local scene = STATE.scene
    if object_isa(scene, LevelScene_t) then
        level_scene_draw(scene)
    else
        log_error("in love.update: unhandled scene type `", object_typeof(STATE.scene), "`")
    end

    upscaler_unbind()
    upscaler_draw()

    cursor_draw()

    graphics_notify_end_of_frame()
end


