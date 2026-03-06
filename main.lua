require "include"

--[[

-- game state
local score = 0

-- generate a new field
local field = {
    circles = {},
    target = {},
    
    crosshair = {
        x = love.mouse.getX(),
        y = love.mouse.getY(),
        circle = {},
        top = {},
        bottom = {},
        right = {},
        left = {}
    },

    reveal_elapsed = 0,
    reveal_duration = 1,

    cooldown_elapsed = 0,
    cooldown_duration = 2,

    found_message_x = 0,
    found_message_y = 0,
}

local reinitialize_field = function()
    local screen_w, screen_h = love.graphics.getDimensions()

    local min_radius = 12
    local max_radius = 46
    
    local min_r = 0
    local max_r = 1
    local min_g = 0
    local max_g = 1
    local min_b = 0
    local max_b = 1

    local spotlight_radius = 128

    local cell_size = 64

    -- generate a random float in given range
    local random = function(lower, upper, ratio)
        return lower * (1 - ratio) + upper * ratio
    end

    field.circles = {}

    local n_rows = math.ceil(screen_w / cell_size)
    local n_columns = math.ceil(screen_h / cell_size)

    for row_i = 1, n_rows do
        for col_i = 1, n_columns do
            local n_per_cell = love.math.random(1, 6)
            for i = 1, n_per_cell do
                local x = random(
                    (row_i - 1) * cell_size,
                    (row_i - 0) * cell_size
                )

                local y = random(
                    (col_i - 1) * cell_size,
                    (col_i - 0) * cell_size
                )

                local radius = random(min_radius, max_radius)

                table.insert(field.circles, {
                    x = x,
                    y = y,
                    radius = radius,
                    color = {
                        random(min_r, max_r),
                        random(min_g, max_g),
                        random(min_b, max_b),
                        1
                    }
                })
            end
        end
    end

    local radius = random(min_radius, max_radius)

    local target_min_x = 0 + 2 * radius
    local target_max_x = screen_w - 2 * radius

    local target_min_y = 0 + 2 * radius
    local target_max_y = screen_h - 2 * radius

    field.target = {
        x = random(target_min_x, target_max_x),
        y = random(target_min_y, target_max_y),
        radius = radius,
        color = { 0, 1, 1, 1 }
    }


    field.crosshair.circle = {
        x = 0,
        y = 0,
        radius = spotlight_radius,
        color = { 1, 1, 1, 1 }
    }
    
    field.crosshair.left = {
        0 - field.target.radius, 0,
        0 - field.crosshair.circle.radius, 0
    }
    
    field.crosshair.right = {
        0 + field.target.radius, 0,
        0 + field.crosshair.circle.radius, 0
    }

    field.crosshair.top = {
        0, 0 - field.target.radius,
        0, 0 - field.crosshair.circle.radius
    }

    field.crosshair.bottom = {
        0, 0 + field.target.radius,
        0, 0 + field.crosshair.circle.radius
    }
end

function draw_field()
    love.graphics.setLineWidth(2)
    love.graphics.setLineStyle("smooth")

    local draw_circle = function(entry)
        love.graphics.setColor(0, 0, 0, 1)
        love.graphics.circle("line", entry.x, entry.y, entry.radius + 1)

        love.graphics.setColor(entry.color)
        love.graphics.circle("fill", entry.x, entry.y, entry.radius)
    end

    for _, entry in ipairs(field.circles) do
        draw_circle(entry)
    end

    draw_circle(field.target)

    if field.cooldown_elapsed >= 0 then
        love.graphics.print("Found!", field.found_message_x, field.found_message_y)
    end
end

function draw_stencil()
    -- stencil todo

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle(
        field.crosshair.circle.x,
        field.crosshair.circle.y,
        field.crosshair.circle.radius
    )

    love.graphics.line(field.crosshair.top)
    love.graphics.line(field.crosshair.right)
    love.graphics.line(field.crosshair.bottom)
    love.graphics.line(field.crosshair.left)

    -- stencil todo

    love.graphics.setColor(0, 0, 0, 1)
    --love.graphics.rectangle(0, 0, love.window.getDimensions())
end

function check_success(x, y)
    local dx = x - field.target.x
    local dy = y - field.target.y

    if math.sqrt(dx^2 + dy^2) < field.target.radius then
        field.cooldown_elapsed = field.cooldown_duration
    end
end

love.mousepressed = function(x, y)
    check_success(x, y)
end

love.keypressed = function(_)
    check_success(love.mouse.getPosition())
end
]]

require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"

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
    rt.SceneManager:push(ow.OverworldScene, "bounce_tutorial", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene) -- skip title

    --init()
end

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize(width, height)
    end
end
