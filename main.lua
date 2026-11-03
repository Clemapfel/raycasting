require "include"
require "common.error_handler"


do
    -- test

    local Foo = meta.class("Foo")

    local schema = meta.Schema {
        foo = Foo,
        number = meta.Number,
        union_string = meta.Union(meta.String, Foo),
        [false] = mt.Boolean,
        inner = {
            [1] = {
                [2] = Foo
            },
            inner_foo = meta.Optional(Foo),
            inner_number = meta.Number,
            inner_union = meta.Union(meta.String, Foo)
        }
    }

    local x = {
        foo = Foo(),
        number = 1234,
        union_string = "union",
        [false] = true,
        inner = {
            [1] = {
                [2] = Foo(),
            },
            --inner_foo = Foo(),
            inner_number = -1234,
            inner_union = Foo()
        }
    }

    dbg(schema:validate(x))
end

if _G.PROFILE then
    profiler = require "common.profiler"
end

if _G.DEBUG then
    debugger = require "common.debugger"
end

require "common.game_state"
require "common.scene_manager"

rt.GameState:set_draw_debug_information(true) -- TODO
bd.mount_path("C:/Users/cleme/Workspace/raycasting/website/screenshots", "screenshots")
DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == rt.KeyboardKey.M then
        rt.SceneManager:screenshot("screenshots/" .. string.unique_timestamp() .. ".png")
    end
end)

local shader = rt.Shader("website/game/src/content/shaders/bismuth.glsl")
local elapsed = 0

require "common.log"
rt.Log.start_worker()

love.load = function(args)
    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == rt.KeyboardKey.K then
            local success, error = pcall(shader.recompile, shader)
            if not success then
                rt.critical(error)
            end

            elapsed = 0
        end
    end)

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
    rt.SceneManager:push(ow.OverworldScene, "trailer", ow.StageEntryMode.INSTANT)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene, false)
end

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    elapsed = elapsed + delta
end

love.draw = function()
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    shader:bind()
    shader:send("elapsed", elapsed)
    --love.graphics.rectangle("fill", 0, 0, love.graphics.getDimensions())
    shader:unbind()
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize()
    end
end