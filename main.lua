require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"

local present = function()
    local coins = {}
    for i = 1, 50 do
        table.insert(coins, rt.random.toss_coin(0.5))
    end

    local w, h = love.graphics.getDimensions()

    local best = rt.GameState:stage_get_splits_best_run("tutorial")
    local current = table.deepcopy(best)
    for i, x in ipairs(current) do
        current[i] = math.max(x + rt.random.number(-10, 10), 0)
    end

    rt.SceneManager:push(ow.ResultScreenScene,
        rt.random.number(0, 1) * w,
        rt.random.number(0, 1) * h,
        rt.RenderTexture(),
        {
            coins = coins,
            time = 1.234,
            target_time = 1.230,
            stage_name = "The Shape of Jump to Come, The Shape of Jump to Come",
            stage_id = "tutorial",

            flow = 0.9868,
            time_grade = rt.StageGrade.S,
            coins_grade = rt.StageGrade.A,
            flow_grade = rt.StageGrade.F,

            splits_current = current,
            splits_best = best
        }
    )
end

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "^" then
        rt.SceneManager:set_scene(ow.OverworldScene, "tutorial", false)
        --present()
    elseif which == "k" then
    end
end)

love.load = function(args)
    local w, h = love.graphics.getDimensions()

    -- intialize all scenes
    require "overworld.overworld_scene"
    --rt.SceneManager:push(ow.OverworldScene, "tutorial", true)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene)

    require "overworld.result_screen_scene"
    --present()
end

love.update = function(delta)
    rt.SceneManager:update(delta)
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    rt.SceneManager:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end
