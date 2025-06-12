require "include"
require "common.scene_manager"
require "common.game_state"
require "common.input_subscriber"
require "menu.stage_grade_label"

--[[
ParticleTexture = meta.class("ParticleTexture")

local padding = 5

local _position_x = 1
local _position_y = 2
local _velocity_x = 3
local _velocity_y = 4
local _r = 5
local _g = 6
local _b = 7
local _velocity_magnitude = 8
local _scale = 9

local _draw_shader

function ParticleTexture:initialize()
    if _draw_shader == nil then _draw_shader = rt.Shader("overworld/objects/accelerator_surface_draw_particles.glsl") end

    local max_size = rt.get_pixel_scale() * 30
    local particle_mesh = rt.MeshCircle(0, 0, 0.5 * max_size)
    particle_mesh:set_vertex_color(1, 1, 1, 1, 1)
    for i = 2, particle_mesh:get_n_vertices() do
        particle_mesh:set_vertex_color(i, 1, 1, 1, 0.0)
    end

    local canvas_w = max_size + padding
    self._particle_texture = rt.RenderTexture(canvas_w, canvas_w, 4)
    self._particle_texture:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(particle_mesh:get_native(), 0.5 * canvas_w, 0.5 * canvas_w)
    self._particle_texture:unbind()
    self._particle_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)

    self._n_particles = 1000
    self._mesh_data = {}
    self._mesh_format = {
        {location = 3, name = "position_velocity", format = "floatvec4"},
        {location = 4, name = "color", format = "floatvec3"},
        {location = 5, name = "magnitude_scale", format = "floatvec2"}
    }

    for i = 1, self._n_particles do
        local velocity = rt.random.number(0, 100)
        local hue = rt.random.number(0, 1)
        local r, g, b = rt.lcha_to_rgba(0.8, 1, hue, 1)
        table.insert(self._mesh_data, {
            rt.random.number(0, love.graphics.getWidth()), -- x
            rt.random.number(0, love.graphics.getHeight()), -- y
            rt.random.number(-1, 1), -- vx
            rt.random.number(-1, 1), -- vy
            r,
            g,
            b,
            velocity, -- velocity magnitude
            rt.random.number(0.1, 1) -- scale
        })
    end

    self._data_mesh = rt.Mesh(
        self._mesh_data,
        rt.MeshDrawMode.TRIANGLE_FAN,
        self._mesh_format,
        rt.GraphicsBufferUsage.DYNAMIC
    )

    self._particle_mesh = rt.MeshRectangle(-canvas_w, -canvas_w, 2 * canvas_w, 2 * canvas_w)
    self._particle_mesh:set_texture(self._particle_texture)
    self._particle_mesh:get_native():attachAttribute("position_velocity", self._data_mesh:get_native(), "perinstance")
    self._particle_mesh:get_native():attachAttribute("color", self._data_mesh:get_native(), "perinstance")
    self._particle_mesh:get_native():attachAttribute("magnitude_scale", self._data_mesh:get_native(), "perinstance")

end

function ParticleTexture:update(delta)
    local screen_width, screen_height = love.graphics.getWidth(), love.graphics.getHeight()
    for i = 1, self._n_particles do
        local particle = self._mesh_data[i]

        particle[_position_x] = particle[_position_x] + particle[_velocity_x] * particle[_velocity_magnitude] * delta
        particle[_position_y] = particle[_position_y] + particle[_velocity_y] * particle[_velocity_magnitude] * delta

        if particle[_position_x] < 0 or particle[_position_x] > screen_width then
            particle[_velocity_x] = -particle[_velocity_x]
        end
        if particle[_position_y] < 0 or particle[_position_y] > screen_height then
            particle[_velocity_y] = -particle[_velocity_y]
        end
    end
    self._data_mesh:replace_data(self._mesh_data)
end

function ParticleTexture:draw()
    --rt.graphics.set_blend_mode(rt.BlendMode.ADD)
    --love.graphics.setBlendMode("add", "premultiplied")
    _draw_shader:bind()
    local t = 1--0.05
    love.graphics.setColor(t, t, t, 1)
    love.graphics.drawInstanced(self._particle_mesh:get_native(), self._n_particles)
    _draw_shader:unbind()
    rt.graphics.set_blend_mode(nil)
end

local texture = ParticleTexture()
texture:initialize()
]]--

local pathological = {}
pathological[pathological] = 1
println(serialize(rt.GameState))

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
    rt.SceneManager:push(ow.StageTitleCardScene, "tutorial")
end

love.update = function(delta)
    rt.SceneManager:update(delta)
    --texture:update(delta)
end

love.draw = function()
    rt.SceneManager:draw()
    --love.graphics.origin()
    --texture:draw()
end

love.resize = function(width, height)
    rt.SceneManager:resize(width, height)
end

