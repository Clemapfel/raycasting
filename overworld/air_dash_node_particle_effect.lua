require "common.random"
require "common.color"

rt.settings.overworld.air_dash_node_particle_effect = {
    min_radius = 5,
    max_radius = 10,
    min_initial_velocity = 1,
    max_initial_velocity = 2,
    min_acceleration = 50,
    max_acceleration = 300,
    min_lifetime = 10 / 60 * 2,
    max_lifetime = 40 / 60 * 2,
    min_hue_velocity = 0.2 / 2,
    max_hue_velocity = 0.5 / 2,
    opacity_fade_duration = 10 / 60,

    min_air_resistance = 0,
    max_air_resistance = 0.6,

    cone_arc = math.degrees_to_radians(30),

    max_n_particles = 5000,
    particle_density = 0.5, -- fraction
}

--- @class ow.AirDashNodeParticleEffect
ow.AirDashNodeParticleEffect = meta.class("AirDashNodeParticleEffect")

--- @brief
function ow.AirDashNodeParticleEffect:instantiate()
    self._batches = {}
end

local _n_particles = 0 -- global count

--- @brief
function ow.AirDashNodeParticleEffect:emit(
    path,
    velocity_x, velocity_y,
    color_r, color_g, color_b, color_a
)
    meta.assert(path, rt.Path)

    if velocity_x == nil then velocity_x = 0 end
    if velocity_y == nil then velocity_y = 0 end

    local batch = {}
    table.insert(self._batches, batch)
    self:_init_batch(batch,
        path,
        velocity_x, velocity_y,
        color_r, color_g, color_b, color_a
    )

    local radius, padding = 20, 3
    self._particle_texture = rt.RenderTexture(
        2 * (radius + padding),
        2 * (radius + padding)
    )

    love.graphics.push("all")
    love.graphics.reset()

    local n_vertices = 32
    local center_x, center_y = 0.5 * self._particle_texture:get_width(), 0.5 * self._particle_texture:get_height()
    self._particle_texture:bind()
    local mesh = rt.MeshRing(
        center_x, center_y,
        0.5 * radius,
        radius,
        true,
        n_vertices,
        rt.RGBA(1, 1, 1, 1),
        rt.RGBA(1, 1, 1, 0)
    )

    mesh:set_vertex_color( -- center vertex for hole
        1,
        1, 1, 1, 0
    )
    mesh:draw()

    self._particle_texture:unbind()
end

--- @brief
function ow.AirDashNodeParticleEffect:update(delta)
    local to_remove = {}
    for batch_i, batch in ipairs(self._batches) do
        local is_done = self:_update_batch(batch, delta)
        if is_done then table.insert(to_remove, 1, batch_i) end
    end

    for i in values(to_remove) do table.remove(self._batches, i) end
end

--- @brief
function ow.AirDashNodeParticleEffect:draw()
    for batch in values(self._batches) do
        self:_draw_batch(batch, false) -- no bloom
    end
end

--- @brief
function ow.AirDashNodeParticleEffect:draw_bloom()
    for batch in values(self._batches) do
        self:_draw_batch(batch, true)
    end
end

--- @brief
function ow.AirDashNodeParticleEffect:clear()
    self._batches = {}
end

--- @brief
function ow.AirDashNodeParticleEffect:get_is_active()
    return #self._batches > 0
end

local _position_x_offset = 0
local _position_y_offset = 1
local _velocity_x_offset = 2
local _velocity_y_offset = 3
local _acceleration_offset = 4
local _color_r_offset = 5
local _color_g_offset = 6
local _color_b_offset = 7
local _color_a_offset = 8
local _radius_offset = 9
local _radius_factor_offset = 10
local _lifetime_elapsed_offset = 11
local _lifetime_offset = 12
local _hue_offset = 13
local _hue_velocity_offset = 14
local _hue_velocity_direction_offset = 15

local _stride = _hue_velocity_direction_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1
end

--- @brief
function ow.AirDashNodeParticleEffect:_init_batch(
    batch, path,
    velocity_x, velocity_y,
    color_r, color_g, color_b, color_a
)
    require "table.new"

    local length = path:get_length()

    local hue = select(1, rt.rgba_to_hsva(color_r, color_g, color_b, color_a))

    local settings = rt.settings.overworld.air_dash_node_particle_effect
    local n_particles = length * settings.particle_density

    local min_acceleration, max_acceleration = settings.min_acceleration, settings.max_acceleration
    local min_radius, max_radius = settings.min_radius, settings.max_radius
    local min_lifetime, max_lifetime = settings.min_lifetime, settings.max_lifetime
    local min_initial_velocity, max_initial_velocity = settings.min_initial_velocity, settings.max_initial_velocity
    local min_hue_velocity, max_hue_velocity = settings.min_hue_velocity, settings.max_hue_velocity

    batch.particle_data = {}
    batch.current_n_particles = 0

    local cone_arc = settings.cone_arc
    local norm_velocity_x, norm_velocity_y = math.normalize(velocity_x, velocity_y)
    -- emission direction is opposite to batch velocity

    local data = batch.particle_data
    for particle_i = 1, n_particles do
        if _n_particles > settings.max_n_particles then break end

        local t = (particle_i - 1) / n_particles
        local position_x, position_y = path:at(t)

        local mass_t = rt.random.number(0, 1)
        local radius = math.mix(min_radius, max_radius, mass_t)
        local magnitude = math.mix(min_initial_velocity, max_initial_velocity, mass_t)

        local angle = rt.random.number(-cone_arc / 2, cone_arc / 2)
        local emission_x, emission_y = math.flip(path:tangent_at(t))
        local particle_velocity_x, particle_velocity_y = math.rotate2(emission_x, emission_y, angle)

        local i = #batch.particle_data + 1
        data[i + _position_x_offset] = position_x
        data[i + _position_y_offset] = position_y
        data[i + _velocity_x_offset] = particle_velocity_x * magnitude
        data[i + _velocity_y_offset] = particle_velocity_y * magnitude
        data[i + _acceleration_offset] = math.mix(min_acceleration, max_acceleration, 1 - t)
        data[i + _color_r_offset] = color_r
        data[i + _color_g_offset] = color_g
        data[i + _color_b_offset] = color_b
        data[i + _color_a_offset] = 1
        data[i + _radius_offset] = radius
        data[i + _radius_factor_offset] = 1
        data[i + _lifetime_elapsed_offset] = 0
        data[i + _lifetime_offset] = math.mix(min_lifetime, max_lifetime, mass_t)
        data[i + _hue_offset] = hue
        data[i + _hue_velocity_offset] = math.mix(min_hue_velocity, max_hue_velocity, mass_t)
        data[i + _hue_velocity_direction_offset] = rt.random.choose(-1, 1)

        assert(#data - i == _stride - 1)

        batch.current_n_particles = batch.current_n_particles + 1
        _n_particles = _n_particles + 1
    end

    batch.start_n_particles = batch.current_n_particles
    self:_update_batch(batch, 0)
end

--- @brief
function ow.AirDashNodeParticleEffect:_update_batch(batch, delta)
    local settings = rt.settings.overworld.air_dash_node_particle_effect

    local to_remove = {}
    local n_updated = 0

    local air_resistance_easing = function(t)
        return math.mix(
            settings.min_air_resistance,
            settings.max_air_resistance,
            math.clamp(rt.InterpolationFunctions.LINEAR(1 - t), 0, 1)
        )
    end

    local data = batch.particle_data
    for particle_i = 1, batch.current_n_particles do
        local i = _particle_i_to_data_offset(particle_i)

        local lifetime = data[i + _lifetime_offset]
        local lifetime_elapsed = data[i + _lifetime_elapsed_offset] + delta
        local lifetime_t = math.min(1, lifetime_elapsed / lifetime)
        data[i + _lifetime_elapsed_offset] = lifetime_elapsed

        local alpha = math.clamp((lifetime - lifetime_elapsed) / settings.opacity_fade_duration, 0, 1)
        data[i + _color_a_offset] = alpha

        if lifetime_t >= 1 then
            table.insert(to_remove, 1, particle_i)
        end

        data[i + _radius_factor_offset] = 1 + rt.InterpolationFunctions.SINUSOID_EASE_IN(lifetime_t)

        local air_resistance = air_resistance_easing(lifetime_t)
        local acceleration = data[i + _acceleration_offset]
        data[i + _acceleration_offset] = acceleration

        local vx = data[i + _velocity_x_offset]
        local vy = data[i + _velocity_y_offset]

        data[i + _position_x_offset] = data[i + _position_x_offset] + vx * acceleration * delta * air_resistance
        data[i + _position_y_offset] = data[i + _position_y_offset] + vy * acceleration * delta * air_resistance

        local hue = data[i + _hue_offset] + data[i + _hue_velocity_direction_offset] * data[i + _hue_velocity_offset] * delta
        hue = hue - math.floor(hue)
        data[i + _hue_offset] = hue

        local r, g, b = rt.lcha_to_rgba(0.8, 1, hue, 1)
        data[i + _color_r_offset] = r
        data[i + _color_g_offset] = g
        data[i + _color_b_offset] = b

        n_updated = n_updated + 1

        ::continue::
    end

    for i in values(to_remove) do
        local offset = _particle_i_to_data_offset(i)
        for _ = 1, _stride do
            table.remove(batch.particle_data, offset)
        end
        batch.current_n_particles = batch.current_n_particles - 1
        _n_particles = _n_particles - 1
    end

    return n_updated == 0
end

--- @brief
function ow.AirDashNodeParticleEffect:_draw_batch(batch, is_bloom)
    if is_bloom == nil then is_bloom = false end

    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "premultiplied")
    local native = self._particle_texture:get_native()
    local texture_r = self._particle_texture:get_width() -- is square

    local data = batch.particle_data
    for particle_i = 1, batch.current_n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        local radius = data[i + _radius_offset] * data[i + _radius_factor_offset]
        if radius > 1 then
            local alpha = data[i + _color_a_offset]
            love.graphics.setColor(
                alpha * data[i + _color_r_offset],
                alpha * data[i + _color_g_offset],
                alpha * data[i + _color_b_offset],
                data[i + _color_a_offset]
            )

            local scale = radius / texture_r
            love.graphics.draw(native,
                data[i + _position_x_offset], data[i + _position_y_offset],
                0,
                scale, scale,
                0.5 * texture_r, 0.5 * texture_r
            )
        end
    end

    love.graphics.pop()
end

--- @brief
function ow.AirDashNodeParticleEffect:collect_point_lights(callback)
    for batch in values(self._batches) do
        local data = batch.particle_data
        for particle_i = 1, batch.current_n_particles do
            local i = _particle_i_to_data_offset(particle_i)
            callback(
                data[i + _position_x_offset], data[i + _position_y_offset],
                data[i + _radius_offset] * data[i + _radius_factor_offset],
                data[i + _color_r_offset],
                data[i + _color_g_offset],
                data[i + _color_b_offset],
                data[i + _color_a_offset]
            )
        end
    end
end

--- @brief
function ow.AirDashNodeParticleEffect:get_fraction()
    local sum, n = 0, 0
    for batch in values(self._batches) do
        sum = sum + batch.current_n_particles / batch.start_n_particles
        n = n + 1
    end

    if n == 0 then
        return 0
    else
        return sum / n
    end
end 