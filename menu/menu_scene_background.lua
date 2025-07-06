rt.settings.menu.menu_scene_background = {
    radius = 15,
    min_scale = 0.1,
    max_scale = 1,
    max_scale_speed = 0.5, -- fraction per second
    gravity = -0.5, -- normalize y velocity

    n_layers = 8,
    n_particles_per_layer = 50
}

--- @class mn.MenuSceneBackground
mn.MenuSceneBackground = meta.class("MenuSceneBackground", rt.Widget)

local _shader

-- indices for particle indexing
local _position_x = 1
local _position_y = 2
local _r = 3
local _g = 4
local _b = 5
local _scale = 6
local _velocity_x = 7
local _velocity_y = 8
local _velocity_magnitude = 9
local _scale_direction = 10 -- radius change
local _scale_speed = 11 -- radius change speed

local _mesh_radius = _scale

-- indices for data mesh

local _particle_draw_shader, _particle_texture_shader, _canvas_draw_shader

local _mesh_format = {
    { location = 3, name = "offset", format = "floatvec2" },
    { location = 4, name = "color", format = "floatvec3" },
    { location = 5, name = "radius", format = "float" }
}

local _texture_format = rt.TextureFormat.RGBA16F

--- @brief
function mn.MenuSceneBackground:instantiate(scene)
    if _shader == nil then _shader = rt.Shader("menu/menu_scene_background.glsl") end
    if _particle_draw_shader == nil then _particle_draw_shader = rt.Shader("menu/menu_scene_background_particle_draw.glsl") end
    if _particle_texture_shader == nil then _particle_texture_shader = rt.Shader("menu/menu_scene_background_particle.glsl") end
    if _canvas_draw_shader == nil then _canvas_draw_shader = rt.Shader("menu/menu_scene_background_canvas_draw.glsl") end

    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            _particle_texture_shader:recompile()
            _canvas_draw_shader:recompile()

            local canvas_w = rt.get_pixel_scale() * (rt.settings.menu.menu_scene_background.radius + 5) -- padding
            self._particle_texture:bind()
            love.graphics.setColor(1, 1, 1, 1)
            _particle_texture_shader:bind()
            love.graphics.rectangle("fill", 0, 0, canvas_w, canvas_w)
            self._particle_texture:unbind()

        end
    end)

    meta.assert(scene, mn.MenuScene)
    self._scene = scene
    self._fraction = 0
    self._canvas_needs_update = false

    do -- particle texture
        local canvas_w = rt.get_pixel_scale() * (rt.settings.menu.menu_scene_background.radius + 5) -- padding
        self._particle_texture = rt.RenderTexture(canvas_w, canvas_w, 0, _texture_format)
        self._particle_texture:bind()
        love.graphics.setColor(1, 1, 1, 1)
        _particle_texture_shader:bind()
        love.graphics.rectangle("fill", 0, 0, canvas_w, canvas_w)
        self._particle_texture:unbind()
        self._particle_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
    end

    self._particles = {}
    self._n_particles = 0

    self._data_mesh_data = {}
    self._data_mesh = nil
    self._particle_mesh = rt.MeshRectangle(-1, -1, 2, 2)
    self._particle_mesh:set_texture(self._particle_texture)
end

--- @brief
function mn.MenuSceneBackground:size_allocate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)

    self._particles = {}
    self._data_mesh_data = {}

    local settings = rt.settings.menu.menu_scene_background
    self._radius = settings.radius * rt.get_pixel_scale()

    if self._canvas == nil or self._canvas:get_width() ~= width or self._canvas:get_height() ~= height then
        self._canvas = rt.RenderTexture(width, height, 0, _texture_format)
    end

    local top_y = self._bounds.y - 2 * self._radius
    local bottom_y = self._bounds.y + self._bounds.height + 2 * self._radius

    local particle_i = 1
    local n_layers = settings.n_layers
    self._n_particles = n_layers * settings.n_particles_per_layer

    for layer_i = 1, n_layers do
        local scale = 1 + ((layer_i - 1) / n_layers)
        local r, g, b = rt.lcha_to_rgba(0.8, 1, rt.random.number(0, 1), 1)
        for i = 1, settings.n_particles_per_layer do
            local particle = {
                [_position_x] = rt.random.number(x, x + width),
                [_position_y] = rt.random.number(top_y, bottom_y),
                [_velocity_x] = math.cos(rt.random.number(0, 2 * math.pi)),
                [_velocity_y] = math.sin(rt.random.number(0, 2 * math.pi)),
                [_r] = r,
                [_g] = g,
                [_b] = b,
                [_scale] = rt.random.number(settings.min_scale, settings.max_scale) * scale,
                [_velocity_magnitude] = rt.random.number(0.5, 1) * rt.InterpolationFunctions.EXPONENTIAL_ACCELERATION(scale - 1) + 1
            }

            local data = {
                [_position_x] = particle[_position_x],
                [_position_y] = particle[_position_y],
                [_r] = particle[_r],
                [_g] = particle[_g],
                [_b] = particle[_b],
                [_mesh_radius] = particle[_scale] * self._radius
            }

            self._particles[particle_i] = particle
            self._data_mesh_data[particle_i] = data
            particle_i = particle_i + 1
        end
    end

    if self._data_mesh == nil then
        self._data_mesh = rt.Mesh(
            self._data_mesh_data,
            rt.MeshDrawMode.POINTS,
            _mesh_format,
            rt.GraphicsBufferUsage.DYNAMIC
        )
        for i = 1, #_mesh_format do
            self._particle_mesh:attach_attribute(self._data_mesh, _mesh_format[i].name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
        end
    else
        self._data_mesh:replace_data(self._data_mesh_data)
    end

    self._canvas_needs_update = true
end

--- @brief
function mn.MenuSceneBackground:set_fraction(fraction)
    self._fraction = fraction
end

--- @brief
function mn.MenuSceneBackground:update(delta)
    local top_y = self._bounds.y - 2 * self._radius
    local bottom_y = self._bounds.y + self._bounds.height + 2 * self._radius
    for i = 1, self._n_particles do
        local particle = self._particles[i]

        local x, y = particle[_position_x], particle[_position_y]
        y = y - delta * 100 * particle[_velocity_magnitude]

        if y < top_y then y = bottom_y end

        particle[_position_x] = x
        particle[_position_y] = y

        local data = self._data_mesh_data[i]
        data[_position_x] = particle[_position_x]
        data[_position_y] = particle[_position_y]
    end

    self._data_mesh:replace_data(self._data_mesh_data)
    self._canvas_needs_update = true
end

--- @brief
function mn.MenuSceneBackground:draw()
    local player = self._scene:get_player()
    local camera = self._scene:get_camera()

    _shader:bind()
    _shader:send("black", { rt.Palette.BLACK:unpack() })
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("camera_offset", { camera:get_offset() })
    _shader:send("camera_scale", camera:get_final_scale())
    _shader:send("fraction", self._fraction)
    love.graphics.rectangle("fill", self._bounds:unpack())
    _shader:unbind()

    if self._fraction < 1 then
        if self._canvas_needs_update == true then
            love.graphics.push()
            love.graphics.origin()
            self._canvas:bind()
            love.graphics.clear(0, 0, 0, 0)
            _particle_draw_shader:bind()
            rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.ADD)
            local value = 1
            love.graphics.setColor(value, value, value, value)
            self._particle_mesh:draw_instanced(self._n_particles)
            rt.graphics.set_blend_mode()
            _particle_draw_shader:unbind()
            self._canvas:unbind()
            love.graphics.pop()
            self._canvas_needs_update = false
        end

        love.graphics.setBlendMode("alpha", "premultiplied")
        _canvas_draw_shader:bind()
        _canvas_draw_shader:send("opacity", 1 - self._fraction)
        self._canvas:draw()
        _canvas_draw_shader:unbind()
        love.graphics.setBlendMode("alpha")
    end
end