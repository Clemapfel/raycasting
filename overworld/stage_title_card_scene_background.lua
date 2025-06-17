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
local _scale_direction = 10 -- radius change
local _scale_speed = 11 -- radius change speed

local _draw_shader, _particle_texture_shader
local _max_size = rt.get_pixel_scale() * 30
local _min_scale, _max_scale = 0.5, 4
local _max_scale_speed = 0.5 -- fraction per second
local _n_particles = 800
local _gravity = 0.5 -- normalize y velocity

function ow.StageTitleCardSceneBackground:instantiate(n_particles)
    self._n_particles = n_particles or _n_particles
end

function ow.StageTitleCardSceneBackground:realize()
    if _draw_shader == nil or true then _draw_shader = rt.Shader("overworld/stage_title_card_scene_background.glsl") end
    if _particle_texture_shader == nil or true then _particle_texture_shader = rt.Shader("overworld/stage_title_card_scene_background_particle.glsl") end
    local canvas_w = rt.get_pixel_scale() * _max_size + padding

    -- draw circle to texture
    self._particle_texture = rt.RenderTexture(canvas_w, canvas_w, 4)
    self._particle_texture:bind()
    love.graphics.setColor(1, 1, 1, 1)
    _particle_texture_shader:bind()
    love.graphics.rectangle("fill", 0, 0, canvas_w, canvas_w)
    self._particle_texture:unbind()
    self._particle_texture:set_scale_mode(rt.TextureScaleMode.LINEAR)

    self._mesh_data = {}
    self._mesh_format = {
        {location = 3, name = "position_velocity", format = "floatvec4"},
        {location = 4, name = "color", format = "floatvec3"},
        {location = 5, name = "velocity_magnitude_scale_scale_direction_scale_speed", format = "floatvec4"}
    }

    self._data_mesh = nil
    self._particle_mesh = rt.MeshRectangle(-1, -1, 2, 2)
    self._particle_mesh:set_texture(self._particle_texture)
end

function ow.StageTitleCardSceneBackground:size_allocate(x, y, width, height)
    for i = 1, self._n_particles do
        local velocity = rt.random.number(0, 100)
        local hue = rt.random.number(0, 1)
        local r, g, b = rt.lcha_to_rgba(0.8, 1, math.mix(0.4, 1, hue), 1)
        self._mesh_data[i] = {
            [_position_x] = rt.random.number(x, x + width), -- x
            [_position_y] = rt.random.number(y - _gravity * _max_size, y + height), -- y
            [_velocity_x] = rt.random.number(-1, 1), -- vx
            [_velocity_y] = rt.random.number(-1, 1), -- vy
            [_r] = r,
            [_g] = g,
            [_b] = b,
            [_velocity_magnitude] = velocity, -- velocity magnitude
            [_scale] = rt.random.number(_min_scale, _max_scale),
            [_scale_direction] = rt.random.choose({ -1, 1}), -- size_velocity
            [_scale_speed] = rt.random.number(0, 1) * _max_scale_speed
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
        self._particle_mesh:get_native():attachAttribute("velocity_magnitude_scale_scale_direction_scale_speed", self._data_mesh:get_native(), "perinstance")
    else
        self._data_mesh:replace_data(self._mesh_data)
    end
end

function ow.StageTitleCardSceneBackground:update(delta)
    local screen_width, screen_height = self._bounds.width, self._bounds.height
    local padding = 0.5 * _max_size
    local radius_speed = 1
    local noise_scale = 1

    for i = 1, self._n_particles do
        local particle = self._mesh_data[i]

        particle[_position_x] = particle[_position_x] + particle[_velocity_x] * particle[_velocity_magnitude] * delta
        particle[_position_y] = particle[_position_y] + math.mix(particle[_velocity_y], _gravity, math.clamp(particle[_scale], 0.4, 1))  * particle[_velocity_magnitude] * delta

        particle[_velocity_x], particle[_velocity_y] = math.rotate(particle[_velocity_x], particle[_velocity_y],
            rt.random.noise(
                (particle[_position_x] / self._bounds.width) * noise_scale,
                (particle[_position_y] / self._bounds.height) * noise_scale,
                self._elapsed
            ) * 2 * math.pi * 0.003 * particle[_scale_direction]
        )

        if particle[_position_x] < -padding or particle[_position_x] > screen_width + padding then
            particle[_velocity_x] = -particle[_velocity_x]
        end

        if particle[_position_y] < -padding then
            particle[_velocity_y] = -particle[_velocity_y]
        end

        -- warp back up top
        if particle[_position_y] > screen_height + padding then
            particle[_position_y] = -padding - particle[_scale] * _max_size
        end

        local current = particle[_scale]
        local direction = particle[_scale_direction]
        local speed = particle[_scale_speed]

        local step = delta * speed * direction
        current = current + step
        if current > _max_scale then
            current = _max_scale
            direction = -direction
        elseif current < _min_scale then
            current = _min_scale
            direction = -direction
        end

        particle[_scale] = current
        particle[_scale_direction] = direction
        particle[_scale_speed] = speed
    end

    self._data_mesh:replace_data(self._mesh_data)
end

function ow.StageTitleCardSceneBackground:draw()
    if self._data_mesh == nil then return end

    rt.Palette.BLACK:bind()
    love.graphics.rectangle("fill", self._bounds:unpack())

    rt.graphics.set_blend_mode(rt.BlendMode.ADD)
    --love.graphics.setBlendMode("add", "premultiplied")
    _draw_shader:bind()
    _draw_shader:send("radius", _max_size * rt.get_pixel_scale())
    _draw_shader:send("min_scale", _min_scale)
    _draw_shader:send("max_scale", _max_scale)
    local t = _n_particles / 2000
    love.graphics.setColor(t, t, t, 1)
    love.graphics.drawInstanced(self._particle_mesh:get_native(), self._n_particles)
    _draw_shader:unbind()
    rt.graphics.set_blend_mode(nil)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.printf(self._n_particles, 5, 5, math.huge)
end