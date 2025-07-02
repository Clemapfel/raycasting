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

require "menu.stage_select_debris_emitter"
local emitter = mn.StageSelectDebrisEmitter()
emitter:realize()
emitter:reformat(0, 0, love.graphics.getDimensions())

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

    emitter:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()

    emitter:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)

    emitter:reformat(0, 0, love.graphics.getDimensions())
end

