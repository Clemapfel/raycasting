require "include"
require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"

local to_require = "overworld.fluid_projectiles"
require(to_require)
local eggs = nil
local batch_id_to_entry = {}
local n_eggs = 1
local n_particles_per_egg = 32
local n_path_nodes = 20
local velocity = 50 -- px / s

local init = function()
    eggs = ow.FluidProjectiles()
    batch_id_to_entry = {}

    local w, h = love.graphics.getDimensions()
    local padding = math.max(w, h) / 3
    w = w - padding
    h = h - padding

    local batch_ids = {}
    for i = 1, n_eggs do
        table.insert(batch_ids, eggs:add(
            0.5 * love.graphics.getWidth() + rt.random.number(-0.5, 0.5) * w,
            0.5 * love.graphics.getHeight() + rt.random.number(-0.5, 0.5) * h,
            n_particles_per_egg
        ))
    end

    for batch_id in values(batch_ids) do
        local path = {}
        for i = 1, n_path_nodes do
            table.insert(path, 0.5 * love.graphics.getWidth() + rt.random.number(-0.5, 0.5) * w)
            table.insert(path, 0.5 * love.graphics.getHeight() + rt.random.number(-0.5, 0.5) * h)
        end

        path = rt.close_contour(path)
        batch_id_to_entry[batch_id] = {
            id = batch_id,
            path = rt.Spline(path),
            speed = rt.random.number(1, 3),
            elapsed = 0
        }
    end
end

love.load = function(args)
    local w, h = love.graphics.getDimensions()

    local result_screen = 1
    local overworld = 2
    local keybinding = 3
    local settings = 4
    local menu = 5

    for to_preallocate in range(
         result_screen
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
    rt.SceneManager:push(ow.OverworldScene, "jump_tutorial", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene, false) -- skip title

    --init()

    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "^" then
            package.loaded[to_require] = false
            require(to_require)
            init()
        end
    end)
end

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    --[[
    for batch_id, entry in pairs(batch_id_to_entry) do
        entry.elapsed = entry.elapsed + delta
        local t = math.fract((entry.elapsed * entry.speed * velocity) / entry.path:get_length())
        --eggs:set_target_position(batch_id, love.mouse.getPosition()) --entry.path:at(t))
    end

    --eggs:update(delta)
    ]]--
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    --love.graphics.clear(0.4, 0.2, 0.4, 1)
    --eggs:draw()
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize(width, height)
    end
end