require "include"
require "common.error_handler"

if _G.PROFILE then
    profiler = require "common.profiler"
end

if _G.DEBUG then
    debugger = require "common.debugger"
end

require "common.game_state"
require "common.scene_manager"

local shader = rt.Shader("website/game/src/content/shaders/bismuth.glsl")
local elapsed = 0

local prefix = love.filesystem.getAppdataDirectory() .. "/" .. love.filesystem.getIdentity() .. "/"
love.filesystem.createDirectory("a")
love.filesystem.createDirectory("b")

local a_path = prefix .. "a"
local b_path = prefix .. "b"
local a_mount = "mount_a"
local b_mount = "mount_b"

local args = function() return "readwrite", true end

--[[
assert(love.filesystem.mountFullPath(a_path, a_mount, args()))
assert(love.filesystem.mountFullPath(b_path, a_mount, args()))
love.filesystem.write(a_mount .. "/foo.txt", "foo")
]]--



love.filesystem.createDirectory("a")
love.filesystem.write("a/a_before.txt", "a_before")
love.filesystem.createDirectory("b")
love.filesystem.write("b/b_before.txt", "b_before")
love.filesystem.write("b/b_hidden.txt", "hidden")

    local exists = function(x) assert(love.filesystem.getInfo(x) ~= nil, x) end
exists("a/a_before.txt") -- passes, appdata a/a_test
exists("b/b_before.txt") -- passes, appdata b/b_test

assert(love.filesystem.mountFullPath(love.filesystem.getAppdataDirectory() .. "/" .. love.filesystem.getIdentity() .. "/a",
    "b",
    "readwrite",
    true
)) -- mount so writing to b writes to a

assert(love.filesystem.write("b/b_after.txt", "b_after"))
exists("b/a_before.txt")
exists("b/b_before.txt")
exists("b/b_after.txt")

exists("b/b_after.txt")
println(love.filesystem.read("b/b_hidden.txt"))

--[[
assert(love.filesystem.getInfo(a_mount .. "/foo.txt") ~= nil, "not written to a_mount")
assert(love.filesystem.getInfo(a_path .. "/foo.txt") ~= nil, "not written to a_path")
assert(love.filesystem.getInfo(b_path .. "/foo.txt") ~= nil, "not written to b_path")
]]--



DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == rt.KeyboardKey.K then
        local success, error = pcall(shader.recompile, shader)
        if not success then
            rt.critical(error)
        end

        elapsed = 0
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
    -- result_screen
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
    rt.SceneManager:push(ow.OverworldScene, "debug_room", ow.StageEntryMode.INSTANT)

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
