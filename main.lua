require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "p" then
        debugger.reload()
    end
end)

require "overworld.coin_particle"
local particle = ow.CoinParticle(200)


love.load = function(args)
    -- intialize all scenes
    require "overworld.overworld_scene"
    --rt.SceneManager:push(ow.OverworldScene, "tutorial")

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene)

    require "overworld.stage_title_card_scene"
    --rt.SceneManager:push(ow.StageTitleCardScene, "tutorial")
end

require "common.label"
local label = rt.Label("<wave><rainbow><b><o>LÖVE</o></b></rainbow></wave>", rt.FontSize.GIGANTIC)
label:realize()
label:reformat(50, 50, math.huge)

love.update = function(delta)
    rt.SceneManager:update(delta)
    particle:update(delta)
end

love.draw = function()
    --rt.SceneManager:draw()

    love.graphics.setColor(1, 1, 1, 1)
    particle:draw(500, 400, false)
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end

