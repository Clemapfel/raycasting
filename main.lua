require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"

input = rt.InputSubscriber()
input:signal_connect("pressed", function(_, which)
end)

local rope

love.load = function(args)
    local w, h = love.graphics.getDimensions()

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
    --rt.SceneManager:push(ow.OverworldScene, "tutorial", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene)

    require "overworld.result_screen_scene"
    --present()


    local rope_length = 100
    local n_segments = 30
    rope = {
        current_positions = {},
        last_positions = {},
        last_velocities = {},
        masses = {},
        anchor_x = 0, -- anchor of first node
        anchor_y = 0,
        axis_x = 0, -- axis constraint
        axis_y = 1,
        scale = 1, -- metaball scale
        length = rope_length, -- total rope length
        n_segments = n_segments,
        segment_length = rope_length / n_segments,
    }

    local center_x = 0.5 * love.graphics.getWidth()
    local center_y = 0.5 * love.graphics.getHeight()
    local dx, dy = math.normalize(rope.anchor_x - center_x, rope.anchor_y - center_x)

    for segment_i = 1, n_segments do
        table.insert(rope.current_positions, center_x)
        table.insert(rope.current_positions, center_x)
        table.insert(rope.last_positions, center_x)
        table.insert(rope.last_positions, center_x)
        table.insert(rope.last_velocities, 0)
        table.insert(rope.last_velocities, 0)
        table.insert(rope.masses,  1)
    end
end

local elapsed = 0
love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    local todo = rt.settings.player_body.non_bubble
    local mouse_x, mouse_y = love.mouse.getPosition()
    rt.PlayerBody._rope_handler({
        rope = rope,
        rope_i = 1,
        is_bubble = false,
        n_velocity_iterations = todo.n_velocity_iterations,
        n_distance_iterations = todo.n_distance_iterations,
        n_axis_iterations = todo.n_axis_iterations,
        axis_intensity = 1,
        n_bending_iterations = todo.n_bending_iterations,
        inertia = todo.inertia,
        gravity_x = 0,
        gravity_y = 10,
        delta = delta,
        velocity_damping = 1 - todo.velocity_damping,
        position_x = mouse_x,
        position_y = mouse_y,
        platform_delta_x = 0,
        platform_delta_y = 0
    })
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.line(rope.current_positions)
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize(width, height)
    end
end
