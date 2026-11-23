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
    getmetatable("").__index = function(_, key)
        _G.error("In string." .. key .. ": trying to call instance method on a string")
    end

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
    rt.SceneManager:push(ow.OverworldScene, "trailer", ow.StageEntryMode.INSTANT)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene, false)
end

local _body, _contours, _mesh, _mesh_data
local _initial_aabb

-- Cached rest-pose data
local _rest_points
local _triangles

local _n = 3

local _update_mesh = function()
    local contour = _body:get_draw_contour()
    local vertices = table.deepcopy(contour:get_vertices())
    local cx, cy = contour:get_centroid()

    -- Capture the initial shape and triangulate only once.
    if _rest_points == nil then
        local slick = require "dependencies.slick.slick"

        local aabb = contour:get_aabb()
        _initial_aabb = {
            x = aabb.x,
            y = aabb.y,
            width = aabb.width,
            height = aabb.height
        }

        -- The centroid is the first point.
        _rest_points = {
            { cx, cy }
        }

        -- Store the original contour vertices.
        for i = 1, #vertices, 2 do
            table.insert(_rest_points, {
                vertices[i],
                vertices[i + 1]
            })
        end

        -- Flatten points for slick.triangulate.
        local polygon = {}

        for _, point in ipairs(_rest_points) do
            table.insert(polygon, point[1])
            table.insert(polygon, point[2])
        end

        local tris = slick.triangulate({ polygon })

        -- Convert triangle coordinates into stable rest-pose indices.
        _triangles = {}

        local function get_rest_point_index(x, y)
            local best_index = nil
            local best_distance_squared = math.huge

            for i, point in ipairs(_rest_points) do
                local dx = x - point[1]
                local dy = y - point[2]
                local distance_squared = dx * dx + dy * dy

                if distance_squared < best_distance_squared then
                    best_distance_squared = distance_squared
                    best_index = i
                end
            end

            assert(
                best_index ~= nil and best_distance_squared < 1e-12,
                "Could not match triangulation vertex to rest pose"
            )

            return best_index
        end

        for _, tri in ipairs(tris) do
            local indexed_triangle = {}

            for i = 1, #tri, 2 do
                table.insert(
                    indexed_triangle,
                    get_rest_point_index(tri[i], tri[i + 1])
                )
            end

            table.insert(_triangles, indexed_triangle)
        end
    end

    -- Collect the current, deformed positions.
    -- Indices correspond to the original rest-pose points.
    local current_points = {
        { cx, cy }
    }

    for i = 1, #vertices, 2 do
        table.insert(current_points, {
            vertices[i],
            vertices[i + 1]
        })
    end

    -- Rebuild mesh data using deformed positions and fixed UVs.
    _mesh_data = {}

    for _, tri in ipairs(_triangles) do
        for _, point_index in ipairs(tri) do
            local current_point = current_points[point_index]
            local rest_point = _rest_points[point_index]

            local x = current_point[1]
            local y = current_point[2]

            -- UVs always come from the original undeformed shape.
            local u = (rest_point[1] - _initial_aabb.x) / _initial_aabb.width
            local v = (rest_point[2] - _initial_aabb.y) / _initial_aabb.height

            table.insert(_mesh_data, {
                x, y,
                u, v,
                1, 1, 1, 1
            })
        end
    end

    -- Create the mesh or update its existing vertex data.
    if _mesh == nil or #_mesh_data ~= _mesh:get_n_vertices() then
        _mesh = rt.Mesh(_mesh_data)
        _mesh:set_texture(rt.Texture("assets/sprites/why.png"))
    else
        _mesh:replace_data(_mesh_data)
    end
end

local _init = function()
    -- Reset cached mesh data whenever the body is recreated.
    _rest_points = nil
    _triangles = nil
    _initial_aabb = nil
    _mesh = nil
    _mesh_data = nil

    local padding = 100
    local min_x, min_y, max_x, max_y =
    padding,
    padding,
    love.graphics.getWidth() - 2 * padding,
    love.graphics.getHeight() - 2 * padding

    local spawn_x, spawn_y = math.mix2(min_x, min_y, max_x, max_y, 0.5)
    local spawn_r = 150

    _body = rt.SoftBody(
        rt.PolylinePolygon(spawn_x, spawn_y, spawn_r, _n):subdivide(8)
    )

    _n = _n + 1

    _contours = {
        rt.Polyline(
            spawn_x - padding, spawn_y + 2 * spawn_r,
            spawn_x + padding, spawn_y + 2 * spawn_r,
            spawn_x, spawn_y + (2 * spawn_r - padding)
        ):close():reverse()
    }

    _body:set_gravity(0, 200)
    _body:set_collision_contours(_contours)

    _update_mesh()
end

_init()

DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == rt.KeyboardKey.CIRCUMFLEX then
        rerequire("common.softbody")
        _init()
    end
end)

DBG = false

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    if DBG then
        local x, y = love.mouse.getPosition()
        _body:set_anchor(x, y, 0, 100)
        _body:update(delta)
    end
end

love.draw = function()
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    if DBG then
        local contour = _body:get_draw_contour()
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

        local x, y = love.mouse.getPosition()
        love.graphics.circle("fill", x, y, 3)
    end
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize()
    end
end