rt.settings.menu.menu_scene_background = {
    radius = 40,
    min_radius = 1,  -- factor of radius
    max_radius = 1.5,
    min_scale = 0.5,
    max_scale = 1.5,
    min_velocity = 1, -- px / s
    max_velocity = 10,
    min_angular_velocity = 0.0 * (2 * math.pi),
    max_angular_velocity = 0.1 * (2 * math.pi),
    scale_speed = 0.2,
    n_layers = 8,
    n_particles_per_layer = 100
}

--- @class mn.MenuSceneBackground
mn.MenuSceneBackground = meta.class("MenuSceneBackground", rt.Widget)

-- indices for particle indexing
local _x = 1
local _y = 2
local _r = 3
local _g = 4
local _b = 5
local _scale = 6
local _velocity_x = 7
local _velocity_y = 8
local _velocity_magnitude = 9
local _scale_x = 10
local _scale_y = 11
local _scale_velocity_x = 12
local _scale_velocity_y = 13
local _angle = 14

local _mesh_x = 1
local _mesh_y = 2
local _mesh_r = 3
local _mesh_g = 4
local _mesh_b = 5
local _mesh_radius = 6
local _mesh_scale_x = 7
local _mesh_scale_y = 8
local _mesh_angle = 9

-- indices for data mesh

local _mesh_format = {
    { location = 3, name = "offset", format = "floatvec2" },
    { location = 4, name = "color", format = "floatvec3" },
    { location = 5, name = "radius", format = "float" },
    { location = 6, name = "scale", format = "floatvec2" },
    { location = 7, name = "rotation", format = "float" }
}

local _texture_format = rt.TextureFormat.RGBA16F

local _shader = rt.Shader("menu/menu_scene_background.glsl")
local _particle_draw_shader = rt.Shader("menu/menu_scene_background_particle_draw.glsl")
local _particle_texture_shader = rt.Shader("menu/menu_scene_background_particle.glsl")
local _canvas_draw_shader = rt.Shader("menu/menu_scene_background.glsl")

--- @brief
function mn.MenuSceneBackground:instantiate(scene)
    meta.assert(scene, mn.MenuScene)
    self._scene = scene
    self._fraction = 0
    self._speedup = 1
    self._canvas_needs_update = false
    self._elapsed = 0

    do -- particle texture
        local canvas_w = rt.get_pixel_scale() * (rt.settings.menu.menu_scene_background.radius + 5) -- padding
        self._particle_texture = rt.RenderTexture(canvas_w, canvas_w, 0, _texture_format)
        love.graphics.push("all")
        love.graphics.reset()
        self._particle_texture:bind()
        love.graphics.setColor(1, 1, 1, 1)
        _particle_texture_shader:bind()
        love.graphics.rectangle("fill", 0, 0, canvas_w, canvas_w)
        self._particle_texture:unbind()
        self._particle_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
        _particle_texture_shader:unbind()
        love.graphics.pop()
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
        local scale = layer_i / n_layers
        for i = 1, settings.n_particles_per_layer do
            local r, g, b = rt.lcha_to_rgba(0.8, 1, rt.random.number(0, 1), 1)
            local particle = {
                [_x] = rt.random.number(x, x + width),
                [_y] = rt.random.number(top_y, bottom_y),
                [_velocity_x] = math.cos(rt.random.number(0, 2 * math.pi)),
                [_velocity_y] = math.sin(rt.random.number(0, 2 * math.pi)),
                [_r] = r,
                [_g] = g,
                [_b] = b,
                [_scale] = scale * rt.random.number(settings.min_radius, settings.max_radius),
                [_velocity_magnitude] = scale * rt.random.number(-1, 1),
                [_scale_x] = rt.random.number(settings.min_scale, settings.max_scale),
                [_scale_y] = rt.random.number(settings.min_scale, settings.max_scale),
                [_scale_velocity_x] = rt.random.number(-1, 1),
                [_scale_velocity_y] = rt.random.number(-1, 1),
                [_angle] = rt.random.number(0, 2 * math.pi)
            }

            local data = {
                [_mesh_x] = particle[_x],
                [_mesh_y] = particle[_y],
                [_mesh_r] = particle[_r],
                [_mesh_g] = particle[_g],
                [_mesh_b] = particle[_b],
                [_mesh_radius] = particle[_scale] * self._radius,
                [_mesh_scale_x] = particle[_scale_x],
                [_mesh_scale_y] = particle[_scale_y],
                [_mesh_angle] = particle[_angle],
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
            rt.GraphicsBufferUsage.STREAM
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
function mn.MenuSceneBackground:set_speedup(v)
    self._speedup = v
end

--- @brief
function mn.MenuSceneBackground:update(delta)
    self._elapsed = self._elapsed * self._speedup

    if self._fraction >= 1 then return end

    local top_y = self._bounds.y - 2 * self._radius
    local bottom_y = self._bounds.y + self._bounds.height + 2 * self._radius

    local settings = rt.settings.menu.menu_scene_background
    local min_velocity, max_velocity = settings.min_velocity, settings.max_velocity
    local min_angular_velocity, max_angular_velocity = settings.min_angular_velocity, settings.max_angular_velocity
    local min_scale, max_scale = settings.min_scale, settings.max_scale
    local scale_speed = settings.scale_speed

    for i = 1, self._n_particles do
        local particle = self._particles[i]

        local x, y, magnitude = particle[_x], particle[_y], particle[_velocity_magnitude]
        y = y - delta * math.mix(min_velocity, max_velocity, magnitude)

        local velocity =  math.mix(min_velocity, max_velocity, magnitude)
        x = x + delta * particle[_velocity_x] * velocity
        y = y + delta * particle[_velocity_y] * velocity

        if y < top_y then y = bottom_y end
        if y > bottom_y then y = top_y end
        particle[_x] = x
        particle[_y] = y

        particle[_angle] = particle[_angle] + delta * math.mix(min_angular_velocity, max_angular_velocity, magnitude)

        local scale_x, scale_y = particle[_scale_x], particle[_scale_y]
        local scale_vx, scale_vy = particle[_scale_velocity_x], particle[_scale_velocity_y]

        scale_x = scale_x + delta * scale_speed * particle[_scale_velocity_x]
        scale_y = scale_y + delta * scale_speed * particle[_scale_velocity_y]

        if scale_x > max_scale then
            scale_x = max_scale
            scale_vx = -scale_vx
        end

        if scale_x < min_scale then
            scale_x = min_scale
            scale_vx = - scale_vx
        end

        if scale_y > max_scale then
            scale_y = max_scale
            scale_vy = -scale_vy
        end

        if scale_y < min_scale then
            scale_y = min_scale
            scale_vy = - scale_vy
        end

        particle[_scale_x] = scale_x
        particle[_scale_y] = scale_y
        particle[_scale_velocity_x] = scale_vx
        particle[_scale_velocity_y] = scale_vy

        local data = self._data_mesh_data[i]
        data[_mesh_x] = particle[_x]
        data[_mesh_y] = particle[_y]
        data[_mesh_scale_x] = particle[_scale_x]
        data[_mesh_scale_y] = particle[_scale_y]
        data[_mesh_angle] = particle[_angle]
    end

    self._data_mesh:replace_data(self._data_mesh_data)
    self._canvas_needs_update = true
end

--- @brief
function mn.MenuSceneBackground:draw()
    local player = self._scene:get_player()
    local camera = self._scene:get_camera()
    local offset_x, offset_y = camera:get_offset()

    if self._fraction < 1 then
        if self._canvas_needs_update == true then
            love.graphics.push("all")
            love.graphics.origin()
            self._canvas:bind()
            love.graphics.clear(0, 0, 0, 0)
            _particle_draw_shader:bind()
            rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.ADD)
            local value = 1
            love.graphics.setColor(value, value, value, value)

            local w, h = self._canvas:get_size()
            --love.graphics.translate(offset_x - 0.5 * w, offset_y - 0.5 * h)

            self._particle_mesh:draw_instanced(self._n_particles)
            rt.graphics.set_blend_mode()
            _particle_draw_shader:unbind()
            self._canvas:unbind()
            love.graphics.pop()
            self._canvas_needs_update = false
        end
    end

    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "premultiplied")
    _canvas_draw_shader:bind()
    _canvas_draw_shader:send("bloom", false)
    _canvas_draw_shader:send("black", { rt.Palette.BLACK:unpack() })
    _canvas_draw_shader:send("elapsed", self._elapsed)
    _canvas_draw_shader:send("camera_offset", { offset_x, offset_y })
    _canvas_draw_shader:send("camera_scale", camera:get_final_scale())
    _canvas_draw_shader:send("fraction", self._fraction)
    love.graphics.setColor(1, 1, 1, 1)
    self._canvas:draw()
    _canvas_draw_shader:unbind()
    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

--- @brief
function mn.MenuSceneBackground:draw_bloom()
    love.graphics.push("all")
    love.graphics.reset()
    _canvas_draw_shader:bind()
    _canvas_draw_shader:send("bloom", true)
    love.graphics.setColor(1, 1, 1, 1)
    self._canvas:draw()
    _canvas_draw_shader:unbind()
    love.graphics.pop()
end