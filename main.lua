require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

require "common.fade"
local fade = rt.Fade(5, "overworld/overworld_scene_fade.glsl")

input = rt.InputSubscriber()
input:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "j" then
        debugger.reload()
    elseif which == "space"then
        fade._shader:recompile()
        fade:start(true, true)
    end
end)

require "overworld.deformable_mesh"
require "physics.physics"
local world = b2.World()
local x, y = love.mouse.getPosition()

local contour = {}
local dbg_x, dbg_y, dbg_radius = 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight(), 200
local n_points = 64
for i = 1, n_points do
    local angle = (i - 1) * 2 * math.pi / n_points
    table.insert(contour, dbg_x + math.cos(angle) * dbg_radius * 1.25)
    table.insert(contour, dbg_y + math.sin(angle) * dbg_radius)
end

local mesh = ow.DeformableMesh(world, contour)

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

love.update = function(delta)
    rt.SceneManager:update(delta)

    local x, y = love.mouse.getPosition()
    local force_x, force_y = mesh:step(delta, x, y, 35, 1)
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    rt.SceneManager:draw()

    mesh:draw()
    local x, y = love.mouse.getPosition()
    love.graphics.circle("fill", x, y, 35)
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end

