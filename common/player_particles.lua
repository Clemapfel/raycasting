require "common.random"
require "common.color"

rt.settings.player_particles = {
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

    max_n_particles = 10000
}

--- @class rt.PlayerParticles
rt.PlayerParticles = meta.class("CheckpointParticles")

--- @brief
function rt.PlayerParticles:instantiate()
    self._batches = {}
end

local _n_particles = 0

--- @brief
function rt.PlayerParticles:emit(
    n_particles,
    ax, ay, bx, by,
    color_r, color_g, color_b, color_a
)
    local batch = {}
    table.insert(self._batches, batch)
    self:_init_batch(batch,
        n_particles,
        ax, ay, bx, by,
        color_r, color_g, color_b, color_a
    )
end

--- @brief
function rt.PlayerParticles:update(delta)
    local to_remove = {}
    for batch_i, batch in ipairs(self._batches) do
        local is_done = self:_update_batch(batch, delta)
        if is_done then table.insert(to_remove, 1, batch_i) end
    end

    for i in values(to_remove) do table.remove(self._batches, i) end
end

--- @brief
function rt.PlayerParticles:draw()
    for batch in values(self._batches) do
        self:_draw_batch(batch, false) -- no bloom
    end
end

--- @brief
function rt.PlayerParticles:draw_bloom()
    for batch in values(self._batches) do
        self:_draw_batch(batch, true)
    end
end

--- @brief
function rt.PlayerParticles:clear()
    self._batches = {}
end

local _position_x = 1
local _position_y = 2
local _velocity_x = 3
local _velocity_y = 4
local _acceleration = 6
local _color_r = 7
local _color_g = 8
local _color_b = 9
local _color_a = 10
local _mass = 11
local _radius = 12
local _lifetime_elapsed = 13
local _lifetime = 14
local _hue = 15
local _hue_velocity = 16
local _hue_velocity_direction = 17

--- @brief
function rt.PlayerParticles:_init_batch(
    batch, n_particles,
    ax, ay, bx, by,
    color_r, color_g, color_b, color_a
)
    require "table.new"

    local hue = select(1, rt.rgba_to_hsva(color_r, color_g, color_b, color_a))

    local dx, dy = bx - ax, by - ay
    local length = math.magnitude(dx, dy)
    local up_x, up_y = math.normalize(math.turn_left(dx, dy))
    local down_x, down_y = math.normalize(math.turn_right(dx, dy))

    local settings = rt.settings.player_particles

    local min_acceleration, max_acceleration = settings.min_acceleration, settings.max_acceleration
    local min_mass, max_mass = settings.min_mass, settings.max_mass
    local min_radius, max_radius = settings.min_radius, settings.max_radius
    local min_lifetime, max_lifetime = settings.min_lifetime, settings.max_lifetime
    local min_initial_velocity, max_initial_velocity = settings.min_initial_velocity, settings.max_initial_velocity
    local min_hue_velocity, max_hue_velocity = settings.min_hue_velocity, settings.max_hue_velocity

    batch.particles = {}
    for i = 1, n_particles do
        if _n_particles > settings.max_n_particles then break end

        local mass_t = rt.random.number(0, 1)
        local mass = math.mix(min_mass, max_mass, mass_t)
        local radius = math.mix(min_radius, max_radius, mass)
        local magnitude = math.mix(min_initial_velocity, max_initial_velocity, mass_t)

        local t = (i - 1) / n_particles
        local position_x = ax + dx * t
        local position_y = ay + dy * t

        local vx, vy
        if i % 2 == 0 then
            vx, vy = up_x, up_y
        else
            vx, vy = down_x, down_y
        end

        local particle = {
            [_position_x] = position_x,
            [_position_y] = position_y,
            [_velocity_x] = vx * magnitude,
            [_velocity_y] = vy * magnitude,
            [_acceleration] = math.mix(min_acceleration, max_acceleration, mass_t),
            [_color_r] = color_r,
            [_color_g] = color_g,
            [_color_b] = color_b,
            [_color_a] = 1,
            [_mass] = mass,
            [_radius] = radius,
            [_lifetime_elapsed] = 0,
            [_lifetime] = rt.random.number(min_lifetime, max_lifetime),
            [_hue] = hue,
            [_hue_velocity] = math.mix(min_hue_velocity, max_hue_velocity, mass_t),
            [_hue_velocity_direction] = rt.random.choose(-1, 1)
        }

        table.insert(batch.particles, particle)
        _n_particles = _n_particles + 1
    end

    self:_update_batch(batch, 0) -- builds particle polygons
end

--- @brief
function rt.PlayerParticles:_update_batch(batch, delta)
    local settings = rt.settings.player_particles

    -- update particles
    local gravity_x = settings.gravity_x * delta
    local gravity_y = settings.gravity_y * delta

    local to_remove = {}
    local n_updated = 0

    local turbulence_strength = settings.turbulence_strength
    local turbulence_scale = settings.turbulence_scale
    local time_offset = rt.current_time or 0

    local left, right = {}, {} -- buffered
    for particle_i, particle in ipairs(batch.particles) do
        local px, py = particle[_position_x], particle[_position_y]

        particle[_lifetime_elapsed] = particle[_lifetime_elapsed] + delta
        particle[_color_a] = math.clamp(
            (particle[_lifetime] - particle[_lifetime_elapsed]) / settings.opacity_fade_duration,
            0, 1
        )

        if particle[_lifetime_elapsed] > particle[_lifetime] then
            table.insert(to_remove, 1, particle_i)
            goto continue
        end

        local mass = particle[_mass]
        local vx, vy = particle[_velocity_x], particle[_velocity_y]

        local dx, dy = math.normalize(vx, vy)
        local acceleration = particle[_acceleration]
        vx = vx + (mass * gravity_x + dx * acceleration) * delta
        vy = vy + (mass * gravity_y + dy * acceleration) * delta

        local angle = rt.random.noise(px * turbulence_scale, px * turbulence_scale) * 2 * math.pi
        local noise_x = math.cos(angle)
        local noise_y = math.sin(angle)

        local turbulence_x = noise_x * turbulence_strength * delta
        local turbulence_y = noise_y * turbulence_strength * delta

        vx = vx + turbulence_x * acceleration
        vy = vy + turbulence_y * acceleration

        px = px + vx * delta
        py = py + vy * delta

        particle[_position_x] = px
        particle[_position_y] = py
        particle[_velocity_x] = vx
        particle[_velocity_y] = vy

        particle[_hue] = math.fract(particle[_hue] + particle[_hue_velocity_direction] * particle[_hue_velocity] * delta)
        local r, g, b, a = rt.lcha_to_rgba(0.8, 1, particle[_hue], 1)

        particle[_color_r] = r
        particle[_color_g] = g
        particle[_color_b] = b

        n_updated = n_updated + 1

        ::continue::
    end

    for i in values(to_remove) do
        table.remove(batch.particles, i)
        _n_particles = _n_particles - 1
    end

    return n_updated == 0
end

--- @brief
function rt.PlayerParticles:_draw_batch(batch, is_bloom)
    if is_bloom == nil then is_bloom = false end

    love.graphics.setLineWidth(1)
    local alpha = ternary(is_bloom, 0.4, 1)

    for particle in values(batch.particles) do
        local radius = particle[_radius] * particle[_mass]
        if radius > 1 then
            love.graphics.setColor(particle[_color_r], particle[_color_g], particle[_color_b], alpha * particle[_color_a])
            love.graphics.circle("fill", particle[_position_x], particle[_position_y], particle[_radius])
        end
    end
end
