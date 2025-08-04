rt.settings.menu.stage_select_page_indicator_ring = {
    min_radius = 0.7, -- factor of thickness
    max_radius = 1,
    min_velocity = 0.2,
    max_velocity = 1, -- factors of dxy
    linear_velocity = 5, -- px / s
    noise_velocity = 0.05, -- cycles per second
    max_noise_offset = 0.25, -- factor of thickness
    coverage = 4
}

--- @class mn.StageSelectPageIndicatorRing
mn.StageSelectPageIndicatorRing = meta.class("StageSelectPageIndicatorRing")

local _x = 1
local _y = 2
local _radius = 3
local _angle = 4
local _velocity = 5
local _direction = 6
local _noise_dx = 7
local _noise_dy = 8

local _mesh_x = _x
local _mesh_y = _y
local _mesh_radius = _radius
local _mesh_r = 4
local _mesh_g = 5
local _mesh_b = 6

local _particle_mesh_format = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.COLOR, name = rt.VertexAttribute.COLOR, format = "floatvec4" },
}

local _data_mesh_format = {
    { location = 3, name = "offset", format = "floatvec2" },
    { location = 4, name = "radius", format = "float" },
}

local _particle_shader, _outline_shader

--- @brief
function mn.StageSelectPageIndicatorRing:instantiate(radius, thickness)
    if _particle_shader == nil then _particle_shader = rt.Shader("menu/stage_select_page_indicator_ring_particle.glsl") end
    if _outline_shader == nil then _outline_shader = rt.Shader("menu/stage_select_page_indicator_ring.glsl") end

    meta.assert(radius, "Number", thickness, "Number")

    thickness = math.max(thickness, 1)
    self._thickness = thickness
    self._x, self._y = 0, 0
    self._radius = radius
    self._hue = 0

    local settings = rt.settings.menu.stage_select_page_indicator_ring
    local min_radius, max_radius = settings.min_radius * thickness, settings.max_radius * thickness
    local min_velocity, max_velocity = settings.min_velocity, settings.max_velocity

    local max_offset = rt.settings.menu.stage_select_page_indicator_ring.max_noise_offset * thickness
    local padding = (max_offset + 2 * max_radius) + rt.get_pixel_scale() * 20
    self._canvas = rt.RenderTexture(2 * radius + 2 * padding, 2 * radius + 2 * padding)
    self._canvas_padding = padding
    self._canvas_needs_update = true

    local max_hue_offset = settings.max_hue_offset
    local n_particles = math.ceil(((2 * math.pi * radius) / max_radius)) * settings.coverage -- intentionally over-cover

    self._data_mesh_data = {}

    self._particles = {}
    self._n_particles = 0
    for angle = 0, 2 * math.pi, (2 * math.pi) / n_particles do
        local particle_x, particle_y = math.cos(angle), math.sin(angle)
        local radius_fraction = rt.random.number(min_radius, max_radius)
        local particle = {
            [_x] = particle_x * radius,
            [_y] = particle_y * radius,
            [_radius] = rt.random.number(min_radius, max_radius), -- factor
            [_angle] = angle,
            [_velocity] = rt.random.choose(min_velocity, max_velocity), -- direction along ring
            [_direction] = rt.random.choose(-1, 1), -- direction along ring
            [_noise_dx] = math.cos(rt.random.number(0, 2 * math.pi)),
            [_noise_dy] = math.sin(rt.random.number(0, 2 * math.pi))
        }

        table.insert(self._particles, particle)

        table.insert(self._data_mesh_data, {
            [_mesh_x] = particle_x * radius,
            [_mesh_y] = particle_y * radius,
            [_mesh_radius] = math.mix(min_radius, max_radius, radius_fraction)
        })

        self._n_particles = self._n_particles + 1
    end

    -- init meshes
    local particle_mesh_data
    do
        particle_mesh_data = {
            { 0, 0, 1, 1, 1, 1 }
        }

        local step = (2 * math.pi) / 16
        for angle = 0, 2 * math.pi + step, step  do
            table.insert(particle_mesh_data, {
                math.cos(angle),
                math.sin(angle),
                0, 0, 0, 0
            })
        end
    end

    self._particle_mesh = rt.Mesh(
        particle_mesh_data,
        rt.MeshDrawMode.TRIANGLE_FAN,
        _particle_mesh_format,
        rt.GraphicsBufferUsage.STATIC
    )

    self._data_mesh = rt.Mesh(
        self._data_mesh_data,
        rt.MeshDrawMode.POINTS,
        _data_mesh_format,
        rt.GraphicsBufferUsage.STREAM
    )

    self._particle_mesh:attach_attribute(self._data_mesh, _data_mesh_format[1].name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
    self._particle_mesh:attach_attribute(self._data_mesh, _data_mesh_format[2].name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
end

--- @brief
function mn.StageSelectPageIndicatorRing:update(delta)
    local center_x, center_y, radius = 0, 0, self._radius

    local noise_offset = rt.settings.menu.stage_select_page_indicator_ring.max_noise_offset * self._thickness
    local noise_velocity = rt.settings.menu.stage_select_page_indicator_ring.noise_velocity
    local elapsed = rt.SceneManager:get_elapsed()
    local max_radius = rt.settings.menu.stage_select_page_indicator_ring.max_radius * self._thickness

    local linear_velocity = rt.settings.menu.stage_select_page_indicator_ring.linear_velocity * rt.get_pixel_scale()
    local angular_velocity = linear_velocity / radius
    for i = 1, self._n_particles do
        local particle = self._particles[i]
        local direction = particle[_direction] -- -1 or 1

        local current = particle[_angle] -- radians
        local magnitude = particle[_velocity] -- factor

        -- move along circle
        current = current + delta * magnitude * direction * angular_velocity

        -- offset based on onise
        local offset =  noise_offset * (rt.random.noise(
            particle[_noise_dx] * elapsed * noise_velocity,
            particle[_noise_dy] * elapsed * noise_velocity
        ) * 2) -- sic, not -1 so particles don't overlap center element

        local dx, dy = math.cos(current), math.sin(current)
        local x = center_y + dx * (radius + offset + max_radius) -- max radius to also prevent overlap
        local y = center_x + dy * (radius + offset + max_radius)

        particle[_angle] = current
        particle[_x] = x
        particle[_y] = y

        local data = self._data_mesh_data[i]
        data[_x] = x
        data[_y] = y
    end

    self._data_mesh:replace_data(self._data_mesh_data)
    self._canvas_needs_update = true
end

--- @brief
function mn.StageSelectPageIndicatorRing:set_hue(hue)
    self._hue = hue
end

--- @brief
function mn.StageSelectPageIndicatorRing:draw()

    local w, h = self._canvas:get_size()

    if self._canvas_needs_update then
        love.graphics.push()
        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.origin()
        love.graphics.translate(0.5 * w, 0.5 * h)
        _particle_shader:bind()
        love.graphics.setBlendMode("add", "premultiplied")
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.drawInstanced(self._particle_mesh:get_native(), self._n_particles)
        _particle_shader:unbind()
        self._canvas:unbind()
        love.graphics.pop()
        self._canvas_needs_update = false
    end

    love.graphics.push()
    _outline_shader:bind()
    _outline_shader:send("black", { rt.Palette.BLACK:unpack() })
    _outline_shader:send("hue", self._hue)
    _outline_shader:send("elapsed", rt.SceneManager:get_elapsed())
    love.graphics.translate(self._x - 0.5 * w, self._y - 0.5 * h)
    local r, g, b, a = love.graphics.getColor()
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._canvas:get_native())
    love.graphics.setBlendMode("alpha")
    _outline_shader:unbind()
    love.graphics.pop()
end