require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

require "menu.stage_select_item"
local item = mn.StageSelectItem("tutorial")
item:realize()

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)

end)

require "menu.stage_select_page_indicator_ring"
local ring = mn.StageSelectParticleRing(300, 300, 150, 5)


love.load = function(args)
    local w, h = item:measure()
    item:size_allocate(0, 0, w, 10)

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

love.update = function(delta)
    rt.SceneManager:update(delta)

    ring:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()

    love.graphics.clear(0.5, 0.5, 0.5, 1)
    ring:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end

