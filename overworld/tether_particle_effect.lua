require "common.random"
require "common.color"

rt.settings.overworld.tether_particle_effect = {
    min_radius = 2,
    max_radius = 3,
    min_initial_velocity = 2,
    max_initial_velocity = 3,
    min_acceleration = 200,
    max_acceleration = 300,
    min_lifetime = 0.4,
    max_lifetime = 0.6,
    min_hue_velocity = 0.2,
    max_hue_velocity = 0.5,
    gravity_x = 0,
    gravity_y = 0,
    min_mass = 1, -- fraction
    max_mass = 1,
    velocity_offset = 0.25 * math.pi,
    velocity_influence = 0.7,
    opacity_fade_duration = 20 / 60,
    turbulence_strength = 1,
    turbulence_scale = 1,

    max_n_particles = 5000,
    particle_density = 0.75 -- fraction
}

--- @class ow.TetherParticleEffect
ow.TetherParticleEffect = meta.class("TetherParticleEffect")

--- @brief
function ow.TetherParticleEffect:instantiate()
    self._batches = {}
end

local _n_particles = 0 -- global count

--- @brief
function ow.TetherParticleEffect:emit(
    path,
    color_r, color_g, color_b, color_a,
    velocity_x, velocity_y
)
    meta.assert(path, rt.Path)

    if velocity_x == nil then velocity_x = 0 end
    if velocity_y == nil then velocity_y = 0 end

    local batch = {}
    table.insert(self._batches, batch)
    self:_init_batch(batch,
        path,
        color_r, color_g, color_b, color_a,
        velocity_x, velocity_y
    )
end

--- @brief
function ow.TetherParticleEffect:update(delta)
    local to_remove = {}
    for batch_i, batch in ipairs(self._batches) do
        local is_done = self:_update_batch(batch, delta)
        if is_done then table.insert(to_remove, 1, batch_i) end
    end

    for i in values(to_remove) do table.remove(self._batches, i) end
end

--- @brief
function ow.TetherParticleEffect:draw()
    for batch in values(self._batches) do
        self:_draw_batch(batch, false) -- no bloom
    end
end

--- @brief
function ow.TetherParticleEffect:draw_bloom()
    for batch in values(self._batches) do
        self:_draw_batch(batch, true)
    end
end

--- @brief
function ow.TetherParticleEffect:clear()
    self._batches = {}
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
local _mass_offset = 9
local _radius_offset = 10
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
function ow.TetherParticleEffect:_init_batch(
    batch, path,
    color_r, color_g, color_b, color_a,
    velocity_x, velocity_y
)
    require "table.new"

    local length = path:get_length()
    local n_particles = length * rt.settings.overworld.tether_particle_effect.particle_density

    local hue = select(1, rt.rgba_to_hsva(color_r, color_g, color_b, color_a))

    local settings = rt.settings.overworld.tether_particle_effect

    local min_acceleration, max_acceleration = settings.min_acceleration, settings.max_acceleration
    local min_mass, max_mass = settings.min_mass, settings.max_mass
    local min_radius, max_radius = settings.min_radius, settings.max_radius
    local min_lifetime, max_lifetime = settings.min_lifetime, settings.max_lifetime
    local min_initial_velocity, max_initial_velocity = settings.min_initial_velocity, settings.max_initial_velocity
    local min_hue_velocity, max_hue_velocity = settings.min_hue_velocity, settings.max_hue_velocity

    batch.particle_data = {}
    batch.n_particles = 0

    local data = batch.particle_data
    for particle_i = 1, n_particles do
        if _n_particles > settings.max_n_particles then break end

        local t = (particle_i - 1) / n_particles
        local position_x, position_y = path:at(t)
        local dx, dy = path:tangent_at(t)
        local up_x, up_y = math.normalize(math.turn_left(dx, dy))
        local down_x, down_y = math.normalize(math.turn_right(dx, dy))

        local mass_t = rt.random.number(0, 1)
        local mass = math.mix(min_mass, max_mass, mass_t)
        local radius = math.mix(min_radius, max_radius, mass)
        local magnitude = math.mix(min_initial_velocity, max_initial_velocity, mass_t)

        local vx, vy
        if particle_i % 2 == 0 then
            vx, vy = up_x, up_y
        else
            vx, vy = down_x, down_y
        end

        local i = #batch.particle_data + 1
        data[i + _position_x_offset] = position_x
        data[i + _position_y_offset] = position_y
        data[i + _velocity_x_offset] = (vx + velocity_x) * magnitude
        data[i + _velocity_y_offset] = (vy + velocity_y) * magnitude
        data[i + _acceleration_offset] = math.mix(min_acceleration, max_acceleration, mass_t)
        data[i + _color_r_offset] = color_r
        data[i + _color_g_offset] = color_g
        data[i + _color_b_offset] = color_b
        data[i + _color_a_offset] = 1
        data[i + _mass_offset] = mass
        data[i + _radius_offset] = radius
        data[i + _lifetime_elapsed_offset] = 0
        data[i + _lifetime_offset] = rt.random.number(min_lifetime, max_lifetime)
        data[i + _hue_offset] = hue
        data[i + _hue_velocity_offset] = math.mix(min_hue_velocity, max_hue_velocity, mass_t)
        data[i + _hue_velocity_direction_offset] = rt.random.choose(-1, 1)

        batch.n_particles = batch.n_particles + 1
        _n_particles = _n_particles + 1
    end

    self:_update_batch(batch, 0) -- builds particle polygons
end

--- @brief
function ow.TetherParticleEffect:_update_batch(batch, delta)
    local settings = rt.settings.overworld.tether_particle_effect

    -- update particles
    local gravity_x = settings.gravity_x * delta
    local gravity_y = settings.gravity_y * delta

    local to_remove = {}
    local n_updated = 0

    local turbulence_strength = settings.turbulence_strength
    local turbulence_scale = settings.turbulence_scale
    local time_offset = rt.current_time or 0

    local data = batch.particle_data
    for particle_i = 1, batch.n_particles do
        local i = _particle_i_to_data_offset(particle_i)

        local px = data[i + _position_x_offset]
        local py = data[i + _position_y_offset]
        local vx = data[i + _velocity_x_offset]
        local vy = data[i + _velocity_y_offset]

        local lifetime_elapsed = data[i + _lifetime_elapsed_offset] + delta
        local lifetime = data[i + _lifetime_offset]
        data[i + _lifetime_elapsed_offset] = lifetime_elapsed

        local alpha = (lifetime - lifetime_elapsed) / settings.opacity_fade_duration
        if alpha < 0 then alpha = 0 elseif alpha > 1 then alpha = 1 end
        data[i + _color_a_offset] = alpha

        if lifetime_elapsed > lifetime then
            table.insert(to_remove, 1, particle_i)
            goto continue
        end

        local mass = data[i + _mass_offset]
        local acceleration = data[i + _acceleration_offset]

        local dx, dy = math.normalize(vx, vy)
        vx = vx + (mass * gravity_x + dx * acceleration) * delta
        vy = vy + (mass * gravity_y + dy * acceleration) * delta

        local angle = rt.random.noise(px * turbulence_scale, px * turbulence_scale) * 2 * math.pi
        local noise_x = math.cos(angle)
        local noise_y = math.sin(angle)

        local t = turbulence_strength * delta * acceleration
        vx = vx + noise_x * t
        vy = vy + noise_y * t

        px = px + vx * delta
        py = py + vy * delta

        data[i + _position_x_offset] = px
        data[i + _position_y_offset] = py
        data[i + _velocity_x_offset] = vx
        data[i + _velocity_y_offset] = vy

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
        batch.n_particles = batch.n_particles - 1
        _n_particles = _n_particles - 1
    end

    return n_updated == 0
end

--- @brief
function ow.TetherParticleEffect:_draw_batch(batch, is_bloom)
    if is_bloom == nil then is_bloom = false end

    love.graphics.setLineWidth(1.2)
    local alpha = ternary(is_bloom, 0.4, 1)
    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
    local data = batch.particle_data
    for particle_i = 1, batch.n_particles do
        local i = _particle_i_to_data_offset(particle_i)
        local radius = data[i + _radius_offset] * data[i + _mass_offset]
        if radius > 1 then
            love.graphics.setColor(data[i + _color_r_offset], data[i + _color_g_offset], data[i + _color_b_offset], alpha * data[i + _color_a_offset])
            love.graphics.circle("fill", data[i + _position_x_offset], data[i + _position_y_offset], data[i + _radius_offset])
        end
    end
end
