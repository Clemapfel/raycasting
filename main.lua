require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

local frame
local page_i, n_pages = 1, 10

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "up" then
        if page_i > 1 then page_i = page_i - 1 end
        frame:set_selected_page(page_i)
    elseif which == "down" then
        if page_i < n_pages then page_i = page_i + 1 end
        frame:set_selected_page(page_i)
    end
end)

love.load = function(args)
    require "menu.selection_particle_frame"
    frame = mn.SelectionParticleFrame(n_pages)
    frame:realize()
    local margin = 100
    frame:reformat(100, 100, love.graphics.getWidth() - 200, love.graphics.getHeight() - 200)

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

    frame:reformat(100, 100, love.graphics.getWidth() - 200, love.graphics.getHeight() - 200)

end

