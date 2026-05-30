require "build.config"
require "include"
require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"

love.load = function(args)
    local w, h = love.graphics.getDimensions()

    require "common.texture_format"
    local texture = rt.TextureScaleMode

    local result_screen = 1
    local overworld = 2
    local keybinding = 3
    local settings = 4
    local menu = 5

    for to_preallocate in range(
        -- result_screen
        --, overworld
        --, keybinding
        --, settings
        --, menu
    ) do
        if to_preallocate == 1 then
            require "overworld.result_screen_scene"
            rt.SceneManager:preallocate(ow.ResultScreenScene)
        elseif to_preallocate == 2 then
            require "overworld.overworld_scene"
            rt.SceneManager:preallocate(ow.OverworldScene)
        elseif to_preallocate == 3 then
            require "menu.keybinding_scene"
            rt.SceneManager:preallocate(mn.KeybindingScene)
        elseif to_preallocate == 4 then
            require "menu.settings_scene"
            rt.SceneManager:preallocate(mn.SettingsScene)
        elseif to_preallocate == 5 then
            require "menu.menu_scene"
            rt.SceneManager:preallocate(mn.MenuScene)
        end
    end

    require "overworld.overworld_scene"
    --rt.SceneManager:push(ow.OverworldScene, "air_dash_node_tutorial", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene, true) -- skip title
end

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end
end

local instance
local density = 1 / (1 * 10e3)
local polygons
local all = {}

local _init = function()
    --package.loaded["common.voronoi_tesselation"] = nil
    require "common.voronoi_tesselation"
    local before = love.timer.getTime()
    instance = rt.VoronoiTesselation()
    local w, h = love.graphics.getDimensions()
    local r = math.min(w, h) * 0.5

    local x, y, rw, rh = 0.5 * w - 0.5 * r, 0.5 * h - 0.5 * r, r, r
    local origin_x = rt.random.number(x, x + rw)
    local origin_y = rt.random.number(y, y + rh)

    instance:set_seed_density(density)
    instance:generate_seeds(
        origin_x, origin_y,
        instance:rotate_rectangle(
            x, y, rw, rh,
            origin_x, origin_y,
            0
    ))

    polygons = instance:tesselate()
    time = (love.timer.getTime() - before) / (1 / 60)
end

DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == rt.KeyboardKey.K then
        _init()
    elseif which == rt.KeyboardKey.ARROW_UP then
        density = density + 1 / 300
    elseif which == rt.KeyboardKey.ARROW_DOWN then
        density = density - 1 / 300
    elseif which == rt.KeyboardKey.J then
        if polygons ~= nil then
            local entry = all[#polygons]
            if entry == nil then
                entry = {}
                all[#polygons] = entry
            end

            local vertices = {}
            local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
            for polygon in values(polygons) do
                for i = 1, #polygon, 2 do
                    min_x = math.min(min_x, polygon[i+0])
                    max_x = math.max(max_x, polygon[i+0])
                    min_y = math.min(min_y, polygon[i+1])
                    max_y = math.max(max_y, polygon[i+1])
                end
            end

            local normalized = {}
            for polygon in values(polygons) do
                local to_insert = {}
                for i = 1, #polygon, 2 do
                    table.insert(to_insert, (polygon[i+0] - min_x) / (max_x - min_x))
                    table.insert(to_insert, (polygon[i+1] - min_y) / (max_y - min_y))
                end
                table.insert(normalized, to_insert)
            end

            table.insert(entry, normalized)
            dbg("added ", normalized)
        end
    elseif which == rt.KeyboardKey.P then
        love.filesystem.write("tesselations.lua", "return " .. table.serialize(all))
    end
end)

love.draw = function()
    love.graphics.clear(0.5, 0.5, 0.5, 1)

    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    if instance == nil then
        _init()
    end

    instance:draw()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.print(string.paste(
        "frame duration: " .. math.floor(time * 1000) / 1000 * 100 .. "%" .. "\n",
        "# triangles: " .. #instance._tris .. "\n",
        "# polygons : " .. #instance._polygons .. "\n",
        "density : " .. density
    ), 100, 100)
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize(width, height)
    end
end
