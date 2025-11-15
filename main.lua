
require "include"
require "common.game_state"
require "common.scene_manager"
require "common.music_manager"
require "common.sound_manager"
require "common.input_manager"

local canvas, clouds, rotation, cloud_center_z, view_transform, draw_mesh
local slice_i = 1
local first = true
local function _init()
    local w, h = love.graphics.getDimensions()
    local x, y = 0, 0
    require "common.render_texture_3d"
    canvas = rt.RenderTexture3D(w, h)
    canvas:set_fov(0.4)

    require "common.clouds"
    clouds = rt.Clouds(
        4, -- n_slices
        256,
        256,
        16 -- depth
    )
    clouds:realize()

    view_transform = rt.Transform():look_at(
        0,  0,  0, -- eye xyz
        0,  0,  1, -- target xyz
        0, -1,  0  -- up xyz
    )
    canvas:set_view_transform(view_transform)

    require "common.quaternion"
    rotation = { math.quaternion.from_axis_angle(0, 1, 0, 0) }

    cloud_center_z = 220
    draw_mesh = rt.MeshRectangle3D(
        0, 0, cloud_center_z,
        w / 2, h / 2,
        0, 0, -1
    )
    draw_mesh:set_texture(clouds:get_texture(slice_i))

    if first then
        DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
            local update_texture = false

            if which == "right" and slice_i < clouds:get_n_slices() then
                slice_i = slice_i + 1
                update_texture = true
            elseif which == "left" and slice_i > 1 then
                slice_i = slice_i - 1
                update_texture = true
            end

            if update_texture then
                draw_mesh:set_texture(clouds:get_texture(slice_i))
                dbg(slice_i)
            end
        end)
        first = false
    end
end

love.load = function(args)
    local w, h = love.graphics.getDimensions()

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
    --rt.SceneManager:push(ow.OverworldScene, "tutorial", false)

    require "menu.keybinding_scene"
    --rt.SceneManager:push(mn.KeybindingScene)

    require "menu.settings_scene"
    --rt.SceneManager:push(mn.SettingsScene)

    require "menu.menu_scene"
    --rt.SceneManager:push(mn.MenuScene)

    require "overworld.result_screen_scene"
    --present()

    _init()
end

local elapsed = 0
love.update = function(delta)
    if rt.SceneManager ~= nil then
        rt.SceneManager:update(delta)
    end

    elapsed = elapsed + delta
    --clouds:set_offset(0, 0, 0, elapsed / 10)
end

love.draw = function()
    love.graphics.clear(0, 0, 0, 0)
    if rt.SceneManager ~= nil then
        rt.SceneManager:draw()
    end

    canvas:bind()
    love.graphics.clear()

    local transform = rt.Transform()
        :translate(0, 0, cloud_center_z)
        :apply(math.quaternion.as_transform(table.unpack(rotation)))
        :translate(0, 0, -cloud_center_z)

    canvas:set_model_transform(transform)
    draw_mesh:draw()
    canvas:unbind()

    love.graphics.setColor(1, 1, 1, 1)
    canvas:draw()
end

love.resize = function(width, height)
    if rt.SceneManager ~= nil then
        rt.SceneManager:resize(width, height)
    end

    _init()
end