require "include"
require "common.error_handler"
require "build.config"
require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"
require "common.routine"

--[[
-- condition
local is_hung = false
local routine = rt.Routine(function(routine)
    local condition = rt.Routine.Condition(
        function() return is_hung end
    )

    condition:await()
end)

local other = rt.Routine(function(routine)
    while is_hung == false do
        is_hung = rt.random.toss_coin(0.01)
        rt.Routine.Timer(0.005):await()
    end
end)

-- future
local routine = rt.Routine(function(routine)
    local give = rt.Routine.Future({
        on_start = function(self)
            self.value = 0
            return rt.Routine.FutureResult.IS_DONE
        end,

        on_update = function(self, delta)
            self.value = self.value + math.random()
            dbg(self.value)
            return self.value > 200
        end,

        on_return = function(self)
            return self.value
        end
    })

    dbg("was given: ", give:await())
end)

local n = 0
local outer = rt.Routine(function()
    local inner = rt.Routine(function()
        println(n)
        n = n + 1
    end):resume() -- line 53
end)

outer:start()
outer:restart()
outer:restart()
outer:restart()
]]

local sound_handler

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
    --rt.SceneManager:push(ow.OverworldScene, "air_dash_node_tutorial", ow.StageEntryMode.INSTANT)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene, false)


    local center_x, center_y = 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight()
    rt.SoundManager:set_player_position(center_x, center_y)
    sound_handler = rt.SoundManager:play("debug.debug", {
        should_loop = true,
        position_x = center_x,
        position_y = center_y
    })
    rt.SceneManager:set_is_cursor_visible(true)

    rt.SoundManager:set_effect(sound_handler, rt.ChorusSoundEffect())
end

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    rt.SoundManager:set_position(sound_handler,
        love.mouse.getPosition()
    )
end

love.draw = function()
    love.graphics.clear(0.5, 0.5, 0.5, 1)

    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize()
    end
end
