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
    --rt.SceneManager:push(mn.MenuScene, false)
end

local properties = {}
local property_name_to_is_private = {
    pecan = true
}
local instance = setmetatable({}, {
    __index = function(self, key)
        return properties[key]
    end,

    __newindex = function(self, key, value)
        if property_name_to_is_private[key] == true then
error("do not access privates")
        else
            properties[key] = value
        end
    end
})

instance.walnut = 1 -- works
instance.pecan = 2 -- error

local t = { 1, 2, nil, 3 }
local other = {}
for _, i in ipairs(t) do
    if other[i] == 2 then

    end
end

require "common.cutscene"
local cutscene = rt.Cutscene(function()
    print("a")
    sleep(1)
    print("b")
    sleep(1)
    barrier()
    print("c")
end)

love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    cutscene:update(delta)
end

love.draw = function()
    love.graphics.clear(0.5, 0.5, 0.5, 1)

    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize(width, height)
    end
end


local co = coroutine.create(function()
    coroutine.yield(1, 2, 3)
    return 4, 5, 6
end)

while coroutine.status(co) ~= "dead" do
    dbg(coroutine.resume(co))
end

coroutine.resume(co)