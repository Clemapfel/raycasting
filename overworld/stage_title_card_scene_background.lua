ow.StageTitleCardSceneBackground = meta.class("ow.StageTitleCardSceneBackground", rt.Widget)

local padding = 5

-- indices for array indexing
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
local _max_size = rt.get_pixel_scale() * 30

function ow.StageTitleCardSceneBackground:realize()
    if _draw_shader == nil then _draw_shader = rt.Shader("overworld/stage_title_card_scene_background.glsl") end

    local canvas_w = _max_size + padding

    -- draw circle to texture
    local radius = 0.5 * _max_size
    local particle_mesh = rt.MeshCircle(0, 0, radius)
    local inner = 0.3
    local outer = 0.0
    particle_mesh:set_vertex_color(1, inner, inner, inner, 1)
    for i = 2, particle_mesh:get_n_vertices() do
        particle_mesh:set_vertex_color(i, outer, outer, outer, outer)
    end

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
        {location = 5, name = "magnitude_radius", format = "floatvec3"}
    }

    self._data_mesh = nil
    self._particle_mesh = rt.MeshRectangle(-1, -1, 2, 2)
    self._particle_mesh:set_texture(self._particle_texture)
end

function ow.StageTitleCardSceneBackground:size_allocate(x, y, width, height)
    for i = 1, self._n_particles do
        local velocity = rt.random.number(0, 100)
        local hue = rt.random.number(0, 1)
        local r, g, b = rt.lcha_to_rgba(0.8, 1, hue, 1)
        self._mesh_data[i] = {
            rt.random.number(x, x + width), -- x
            rt.random.number(y, y + height), -- y
            rt.random.number(-1, 1), -- vx
            rt.random.number(-1, 1), -- vy
            r,
            g,
            b,
            velocity, -- velocity magnitude
            rt.random.number(2, 3) * _max_size -- radius
        }
    end

    if self._data_mesh == nil then
        self._data_mesh = rt.Mesh(
            self._mesh_data,
            rt.MeshDrawMode.TRIANGLE_FAN,
            self._mesh_format,
            rt.GraphicsBufferUsage.DYNAMIC
        )
        self._particle_mesh:get_native():attachAttribute("position_velocity", self._data_mesh:get_native(), "perinstance")
        self._particle_mesh:get_native():attachAttribute("color", self._data_mesh:get_native(), "perinstance")
        self._particle_mesh:get_native():attachAttribute("magnitude_radius", self._data_mesh:get_native(), "perinstance")
    else
        self._data_mesh:replace_data(self._mesh_data)
    end
end

function ow.StageTitleCardSceneBackground:update(delta)
    local screen_width, screen_height = self._bounds.width, self._bounds.height
    local padding = 0.5 * _max_size
    for i = 1, self._n_particles do
        local particle = self._mesh_data[i]

        particle[_position_x] = particle[_position_x] + particle[_velocity_x] * particle[_velocity_magnitude] * delta
        particle[_position_y] = particle[_position_y] + particle[_velocity_y] * particle[_velocity_magnitude] * delta

        if particle[_position_x] < -padding or particle[_position_x] > screen_width + padding then
            particle[_velocity_x] = -particle[_velocity_x]
        end
        if particle[_position_y] < -padding or particle[_position_y] > screen_height + padding then
            particle[_velocity_y] = -particle[_velocity_y]
        end
    end
    self._data_mesh:replace_data(self._mesh_data)
end

function ow.StageTitleCardSceneBackground:draw()
    if self._data_mesh == nil then return end

    rt.graphics.set_blend_mode(rt.BlendMode.ADD)
    --love.graphics.setBlendMode("add", "premultiplied")
    _draw_shader:bind()
    _draw_shader:send("center", { 0, 0 })
    local t = 1--0.05
    love.graphics.setColor(t, t, t, 1)
    love.graphics.drawInstanced(self._particle_mesh:get_native(), self._n_particles)
    _draw_shader:unbind()
    rt.graphics.set_blend_mode(nil)
end