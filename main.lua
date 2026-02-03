require "include"
require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"

local toast, toast_tris, circles = {}, {}, {}
local toast_coverage = {}
local fluid_sim = nil
do
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    for xy in range(
        { x = 19.7995, y = -13.8596 },
        { x = 79.1978, y = -43.5589 },
        { x = 170.275, y = -67.3181 },
        { x = 281.153, y = -79.1978 },
        { x = 360.349, y = -81.1777 },
        { x = 443.508, y = -77.2179 },
        { x = 524.686, y = -69.298 },
        { x = 566.265, y = -61.3783 },
        { x = 617.743, y = -45.5388 },
        { x = 647.443, y = -19.7995 },
        { x = 667.242, y = 13.8596 },
        { x = 673.181, y = 41.5789 },
        { x = 679.122, y = 89.0976 },
        { x = 683.082, y = 162.356 },
        { x = 685.06, y = 207.894 },
        { x = 685.06, y = 259.373 },
        { x = 685.06, y = 306.891 },
        { x = 683.082, y = 360.349 },
        { x = 679.122, y = 411.83 },
        { x = 679.122, y = 447.468 },
        { x = 677.141, y = 498.946 },
        { x = 675.162, y = 603.704 },
        { x = 671.202, y = 627.463 },
        { x = 659.323, y = 643.302 },
        { x = 637.542, y = 655.182 },
        { x = 588.043, y = 655.182 },
        { x = 516.766, y = 663.101 },
        { x = 449.447, y = 667.061 },
        { x = 368.269, y = 678.941 },
        { x = 306.891, y = 688.841 },
        { x = 253.434, y = 692.801 },
        { x = 196.015, y = 694.78 },
        { x = 134.636, y = 690.82 },
        { x = 85.1378, y = 680.922 },
        { x = 53.4584, y = 665.082 },
        { x = 29.6992, y = 635.382 },
        { x = 27.7193, y = 589.843 },
        { x = 21.7794, y = 483.107 },
        { x = 7.91978, y = 423.709 },
        { x = -3.9599, y = 352.43 },
        { x = -7.91978, y = 277.193 },
        { x = -11.8797, y = 197.995 },
        { x = -13.8596, y = 136.616 },
        { x = -13.8596, y = 85.1378 },
        { x = -11.8797, y = 27.7193 }
    ) do
        table.insert(toast, xy.x)
        table.insert(toast, xy.y)

        min_x = math.min(min_x, xy.x)
        max_x = math.max(max_x, xy.x)
        min_y = math.min(min_y, xy.y)
        max_y = math.max(max_y, xy.y)
    end

    local center_x = min_x + (max_x - min_x) / 2
    local center_y = min_y + (max_y - min_y) / 2

    for i = 1, #toast, 2 do
        toast[i+0] = (toast[i+0] - center_x) / (max_x - min_x) * 2
        toast[i+1] = (toast[i+1] - center_y) / (max_y - min_y) * 2
    end
end

love.load = function(args)
    local w, h = love.graphics.getDimensions()

    -- TODO
    do
        local toast_x = 0.5 * w
        local toast_y = 0.5 * h
        local toast_w = 0.25 * math.min(w, h)
        local toast_h = 0.25 * math.min(w, h)
        for i = 1, #toast, 2 do
            toast[i+0] = toast_x + toast[i+0] * toast_w
            toast[i+1] = toast_y + toast[i+1] * toast_h
        end

        require "common.triangulate"
        toast_tris = rt.math.triangulate(toast)

        local get_mass = function(i, n)
            local variance = 4
            local function butterworth(t)
                return 1 / (1 + (variance * (t - 0.5))^4)
            end

            local left = (i - 1) / n
            local right = i / n

            local center = 0.5 * (left + right)
            local half_width = 0.5 * (right - left)

            local t1 = center - half_width / math.sqrt(3)
            local t2 = center + half_width / math.sqrt(3)

            return 0.5 * (butterworth(t1) + butterworth(t2))
        end

        local n_circles = 500
        local min_radius, max_radius = 5, 15
        for i = 1, n_circles do
            local radius = math.mix(min_radius, max_radius, math.random())
            table.insert(circles, radius)
        end

        require "common.circle_coverage"
        local before = love.timer.getTime()
        toast_coverage = rt.contour.distribute_circles(toast_tris, circles)
        dbg((love.timer.getTime() - before) / (1 / 60))

        require "common.fluid_simulation"
        fluid_sim = rt.FluidSimulation()
        fluid_sim:add(
            0.5 * w, 0.5 * h,
            50, 50,
            { rt.Palette.WHITE:unpack() }, { rt.Palette.BLACK:unpack() }
        )
    end
    -- TODO

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
    --rt.SceneManager:push(ow.OverworldScene, "jump_tutorial", false)

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

    fluid_sim:update(delta)
    for id in values(fluid_sim:list_ids()) do
        fluid_sim:set_target_position(id, love.mouse.getPosition())
    end
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    love.graphics.setColor(1, 1, 1, 0.5)
    for tri in values(toast_tris) do
        love.graphics.polygon("fill", tri)
    end

    local circle_i = 1
    for i = 1, #toast_coverage, 2 do
        love.graphics.circle("line",
            toast_coverage[i+0],
            toast_coverage[i+1],
            circles[circle_i]
        )
        circle_i = circle_i + 1
    end

    fluid_sim:draw()
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize(width, height)
    end
end