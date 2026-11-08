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
require "jam.palette"
require "jam.polyline"
require "jam.aabb"
require "jam.lag"
require "jam.upscaler"
require "jam.stage"
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
    STATE.stage = stage_new(STATE.stage_list, "Stage 01")
    STATE.boobs = {}
    local min_radius, max_radius = 100 - 16, 100 + 16
    local min_x, min_y = 0.5 * w, 0.5 * h
    local max_x, max_y = 0.5 * w, 0.5 * h
    local n_boobs = 8
    local radii = iter_collect(iter_range(min_radius, max_radius, (max_radius - min_radius) / n_boobs))
    for i = 1, n_boobs do
        table_push(STATE.boobs, boob_init(
            boob_new(),
            random_number(min_x, max_x),
            random_number(min_y, max_y),
            radii[i],
            32
        ))
    end

    do
        local padding = 50
        local x, y = padding, padding
        local w, h = w - 2 * padding, h - 2 * padding
        STATE.level_contour = {
            polyline_new(
                x + 0, y + 0,
                x + w, y + 0,
                x + w, y + h,
                x + 0, y + h,
                x + 0, y + 0
            )
        }
    end

    STATE.upscaler = upscaler_new(love.graphics.getPixelDimensions())

    input_connect_pressed(input_action_accept, function(which)
        upscaler_queue_fade(STATE.upscaler, function()
            println("called")
        end)
    end)
end

input_connect_pressed(input_action_debug, function(which)
    love.load()
end)

love.resize = function()
    rt.SceneManager:resize() -- TODO
    upscaler_resize(STATE.upscaler, love.graphics.getPixelDimensions())
end

love.update = function(delta)
    rt.SceneManager:update(delta) -- TODO

    upscaler_update(STATE.upscaler, delta)

    for boob in iter_values(STATE.boobs) do
        boob_update(boob, delta)
    end

    for current in iter_values(STATE.boobs) do
        local contours = table_deepcopy(STATE.level_contour)
        for other in iter_values(STATE.boobs) do
            if current ~= other then
                table_push(contours, boob_get_contour(other))
            end
        end

        boob_set_collision_contours(current, contours)
    end
end

love.draw = function(delta)
    graphics_clear(0, 0, 0,0)
    rt.SceneManager:draw() -- TODO

    upscaler_bind(STATE.upscaler)
    graphics_clear(1, 0, 1, 1)

    stage_draw(STATE.stage)

    iter_map(boob_draw, STATE.boobs)
    upscaler_unbind(STATE.upscaler)
    upscaler_draw(STATE.upscaler)
end


