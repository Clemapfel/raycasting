require "include"
require "common.error_handler"

if _G.PROFILE then
    profiler = require "common.profiler"
end

if _G.DEBUG then
    debugger = require "common.debugger"
end


require "common.scene_manager"
require "common.log"
require "common.profiler"
rt.Log.start_worker()

DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == rt.KeyboardKey.K then
        local pf = rt.Profiler
        if pf:get_is_recording() == false then
            pf:set_is_recording(true)
        else
            println(pf:report())
            pf:set_is_recording(false)
        end
    end
end)

love.load = function(args)
    if PROFILE then profiler.push("love.load") end

    local before = love.timer.getTime()

    local result_screen = 1
    local overworld = 2
    local keybinding = 3
    local settings = 4
    local menu = 5

    for to_preallocate in range(
        --result_screen
        --, overworld
        --, keybinding
        --, settings
        --, menu
    ) do
        if to_preallocate == result_screen then
            require "overworld.result_screen_scene"
            rt.SceneManager:preallocate(ow.ResultScreenScene)
        elseif to_preallocate == overworld then
            require "overworld.overworld_scene"
            rt.SceneManager:preallocate(ow.OverworldScene)
        elseif to_preallocate == keybinding then
            require "menu.keybinding_scene"
            rt.SceneManager:preallocate(mn.KeybindingScene)
        elseif to_preallocate == settings then
            require "menu.settings_scene"
            rt.SceneManager:preallocate(mn.SettingsScene)
        elseif to_preallocate == menu then
            require "menu.menu_scene"
            rt.SceneManager:preallocate(mn.MenuScene)
        end
    end

    require "overworld.overworld_scene"
    --rt.SceneManager:push(ow.OverworldScene, "trailer", ow.StageEntryMode.INSTANT)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene, false)
end
local _body, _contours, _mesh, _mesh_data
local _initial_aabb
local _n = 3

local _update_mesh = function()
    local contour = softbody_get_draw_contour(_body)

    local slick = require "dependencies.slick.slick"
    local tris = slick.triangulate({ contour:get_vertices() })
    local aabb = contour:get_aabb()
    local cx, cy = contour:get_centroid()

    _mesh_data = {}
    local zoom = 0.75
    for tri_i, tri in ipairs(tris) do
        for i = 1, #tri, 2 do
            local x = tri[i + 0]
            local y = tri[i + 1]

            local u, v
            if false then --_mesh_data[tri_i] ~= nil then
                u = _mesh_data[tri_i][3]
                v = _mesh_data[tri_i][4]
            else
                local angle = math.angle(x - cx, y - cy)
                u = math.cos(angle)
                v = math.sin(angle)
            end


            table.insert(_mesh_data, {
                x, y,
                u, v,
                1, 1, 1, 1
            })
        end
    end

    if _mesh ~= nil and #tris == _mesh:get_n_vertices() then
        _mesh:replace_data(_mesh_data)
    else
        _mesh = rt.Mesh(_mesh_data)
        _mesh:set_texture(rt.Texture("assets/sprites/why.png"))
    end
end

local _init = function()
    local padding = 100
    local min_x, min_y, max_x, max_y = padding, padding, love.graphics.getWidth() - 2 * padding, love.graphics.getHeight() - 2 * padding
    local spawn_x, spawn_y = math.mix2(min_x, min_y, max_x, max_y, 0.5)
    local spawn_r = 150

    _body = softbody_new(rt.PolylinePolygon(spawn_x, spawn_y, spawn_r, _n):subdivide(8))
    _n = _n + 1
    _contours = {
        rt.Polyline(
            spawn_x - padding, spawn_y + 2 * spawn_r,
            spawn_x + padding, spawn_y + 2 * spawn_r,
            spawn_x, spawn_y + (2 * spawn_r - padding)
        ):close():reverse()
    }

    softbody_set_gravity(_body, 0, 200)
    softbody_set_collision_contours(_body, _contours)

    _update_mesh()
end

_init()
DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == rt.KeyboardKey.CIRCUMFLEX then
        rerequire("common.softbody")
        _init()
    end
end)

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    softbody_update(_body, delta)
end

love.draw = function()
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    local contour = softbody_get_draw_contour(_body)
    local n = contour:get_n_vertices()

    _update_mesh()
    _mesh:draw()

    for i = 1, n do
        local hue = (i - 1) / n
        local color = rt.LCHA(0.8, 1, hue, 1)

        local ax, ay = contour:get_vertex(i + 0)
        local bx, by = contour:get_vertex(math.wrap(i + 1, n))

        color:bind()
        love.graphics.line(ax, ay, bx, by)
    end

    for bound in values(_contours) do
        bound:draw()
    end
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize()
    end
end
