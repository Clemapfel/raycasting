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

require "menu.selection_particle_frame"
local frame
love.load = function(args)
    frame = mn.SelectionParticleFrame()
    frame:realize()
    local margin = 100
    frame:reformat(margin, margin, love.graphics.getWidth() - 2 * margin, love.graphics.getHeight() - 2 * margin)

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

    frame:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()

    frame:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end

