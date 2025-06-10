require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

local labels = {}
for grade_size in range(
    {rt.StageGrade.SS, rt.FontSize.GIGANTIC},
    {rt.StageGrade.S, rt.FontSize.GIGANTIC},
    {rt.StageGrade.A, rt.FontSize.GIGANTIC},
    {rt.StageGrade.B, rt.FontSize.GIGANTIC},
    {rt.StageGrade.F, rt.FontSize.GIGANTIC},
    {rt.StageGrade.NONE, rt.FontSize.GIGANTIC}
) do
    local grade, size = table.unpack(grade_size)
    table.insert(labels, mn.StageGradeLabel(grade, size))
end

local x, y = 50, 50
for label in values(labels) do
    label:realize()
    local w, h = label:measure()
    label:reformat(x, y, w, h)
    y = y + h + 5
end

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
end

love.update = function(delta)
    rt.SceneManager:update(delta)

    for label in values(labels) do
        label:update(delta)
    end
end

love.draw = function()
    rt.SceneManager:draw()

    for label in values(labels) do
        label:draw()
    end
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end

