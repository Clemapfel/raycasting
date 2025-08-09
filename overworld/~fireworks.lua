rt.settings.overworld.fireworks = {
    duration = 2.5,  -- Extended for more realistic timing
    fade_out_duration = 0.25,
    rocket_fraction = 0.8,
    gravity = 300
}

--- @brief ow.Fireworks
ow.Fireworks = meta.class("Fireworks")

--- @brief
function ow.Fireworks:instantiate(scene)
    meta.install(self, {
        _particles = {},
        _active = false,
        _elapsed = math.huge,
        _explosion_time = 0.8,  -- When the firework explodes
        _has_exploded = false
    })
end

local _golden_ratio = (1 + math.sqrt(5)) / 2
local _rng = rt.random.number

--- @brief
function ow.Fireworks:spawn(n_particles, position_x, position_y, direction_x, direction_y, hue_min, hue_max)
    if direction_x == nil then direction_x = 0 end
    if direction_y == nil then direction_y = -1 end
    if hue_min == nil then hue_min = 0 end
    if hue_max == nil then hue_max = 1 end

    self._origin_x, self._origin_y = position_x, position_y
    meta.assert(n_particles, "Number", position_x, "Number", position_y, "Number", direction_x, "Number", direction_y, "Number", hue_min, "Number", hue_max, "Number")

    -- Reset explosion state
    self._has_exploded = false
    self._explosion_time = rt.settings.overworld.fireworks.rocket_fraction * rt.settings.overworld.fireworks.duration

    -- Create the initial rocket particle (invisible, just for physics)
    self._rocket = {
        position_x = position_x,
        position_y = position_y,
        velocity_x = direction_x * 400,  -- Slight horizontal drift
        velocity_y = direction_y * 400  -- Strong upward velocity with variation
    }

    self._particles = {}
    for i = 1, n_particles do
        -- Fibonacci lattice for sphere distribution
        local idx = i - 0.5 - 1
        local z = 1 - 2 * idx / n_particles
        local theta = 2 * math.pi * idx / _golden_ratio

        local r = math.sqrt(1 - z * z)
        local x = r * math.cos(theta)
        local y = r * math.sin(theta)

        -- Add some randomness for more organic look
        local perturbation = _rng(0.2, 0.5)
        local angle = _rng(0, 2 * math.pi)
        local offset = _rng(0, perturbation)
        x = x + offset * math.cos(angle)
        y = y + offset * math.sin(angle)
        z = z + offset * math.sin(angle) * 0.3  -- Less z perturbation

        -- Normalize
        local norm = math.sqrt(x * x + y * y + z * z)
        x, y, z = x / norm, y / norm, z / norm

        -- Create particle with initial state (hidden until explosion)
        local hue = _rng(hue_min, hue_max)
        local to_push = {
            -- Position starts at rocket position (will be updated)
            position_x = position_x,
            position_y = position_y,
            position_z = 0,

            -- Color with variation
            color = { rt.lcha_to_rgba(0.8, 1, hue, 1) },

            -- Velocity will be set at explosion
            velocity_x = 0,
            velocity_y = 0,
            velocity_z = 0,

            -- Direction for explosion
            explosion_direction_x = x,
            explosion_direction_y = y,
            explosion_direction_z = z,

            -- Explosion strength varies by particle
            explosion_force = _rng(150, 250),

            -- Physical properties
            mass = _rng(0.8, 1.2),
            radius = _rng(1.5, 3.5),

            -- Lifecycle
            visible = false,
            lifetime = 0,
            max_lifetime = _rng(1.5, 2.5)
        }

        table.insert(self._particles, to_push)
    end

    self._active = true
    self._elapsed = 0
end

--- @brief
--- @return Boolean is_done
function ow.Fireworks:update(delta)
    if not self._active then return end

    local duration = rt.settings.overworld.fireworks.duration
    local gravity = rt.settings.overworld.fireworks.gravity

    -- Update rocket before explosion
    if not self._has_exploded then
        -- Update rocket physics
        self._rocket.velocity_y = self._rocket.velocity_y + gravity * delta * 0.5  -- Less gravity on the way up
        self._rocket.position_x = self._rocket.position_x + self._rocket.velocity_x * delta
        self._rocket.position_y = self._rocket.position_y + self._rocket.velocity_y * delta

        -- Check if it's time to explode
        if self._elapsed >= self._explosion_time then
            self._has_exploded = true

            -- Set explosion point for all particles
            for particle in values(self._particles) do
                particle.position_x = self._rocket.position_x
                particle.position_y = self._rocket.position_y
                particle.visible = true

                -- Add rocket's velocity to explosion for momentum conservation
                local inherited_velocity_factor = 0.3

                -- Set explosion velocities
                particle.velocity_x = particle.explosion_direction_x * particle.explosion_force +
                    self._rocket.velocity_x * inherited_velocity_factor
                particle.velocity_y = particle.explosion_direction_y * particle.explosion_force +
                    self._rocket.velocity_y * inherited_velocity_factor
                particle.velocity_z = particle.explosion_direction_z * particle.explosion_force * 0.7
            end
        end
    else
        -- Update exploded particles
        local player_x, player_y, player_r
        if self._scene ~= nil then
            player_x, player_y = self._scene:get_player():get_position()
            player_r = self._scene:get_player():get_radius()
        end

        for particle in values(self._particles) do
            if particle.visible then
                particle.lifetime = particle.lifetime + delta

                -- Air resistance (reduces velocity over time)
                local air_resistance = 0.98
                particle.velocity_x = particle.velocity_x * (air_resistance ^ delta)
                particle.velocity_y = particle.velocity_y * (air_resistance ^ delta)
                particle.velocity_z = particle.velocity_z * (air_resistance ^ delta)

                -- Apply gravity (increases over time for realistic arc)
                particle.velocity_y = particle.velocity_y + gravity * delta * particle.mass

                -- Update position
                particle.position_x = particle.position_x + particle.velocity_x * delta
                particle.position_y = particle.position_y + particle.velocity_y * delta
                particle.position_z = particle.position_z + particle.velocity_z * delta

                -- Player collision
                if self._scene ~= nil then
                    local particle_r = particle.radius
                    if math.distance(particle.position_x, particle.position_y, player_x, player_y) < (player_r + particle_r) then
                        local delta_x, delta_y = math.normalize(particle.position_x - player_x, particle.position_y - player_y)
                        particle.position_x = player_x + delta_x * (player_r + particle_r)
                        particle.position_y = player_y + delta_y * (player_r + particle_r)

                        -- Bounce off player
                        local bounce_factor = 0.5
                        particle.velocity_x = delta_x * math.abs(particle.velocity_x) * bounce_factor
                        particle.velocity_y = delta_y * math.abs(particle.velocity_y) * bounce_factor
                    end
                end

                -- Update visual effects
                local life_fraction = particle.lifetime / particle.max_lifetime

                -- Fade out based on lifetime
                local fade_out_fraction = rt.settings.overworld.fireworks.fade_out_duration / rt.settings.overworld.fireworks.duration
                if life_fraction > fade_out_fraction then
                    particle.color[4] = 1 - rt.InterpolationFunctions.SINUSOID_EASE_OUT((life_fraction - fade_out_fraction) / (1 - fade_out_fraction))
                else
                    particle.color[4] = 1
                end

                -- Size changes (particles shrink as they fade)
                particle.current_radius = particle.radius * (1 - life_fraction * 0.3)
            end
        end
    end

    self._elapsed = self._elapsed + delta
    if self._elapsed > duration then
        self._particles = {}
        self._active = false
    end
end

--- @brief
function ow.Fireworks:draw()
    if not self._active then return end

    -- Draw rocket trail before explosion

    -- Draw explosion particles
    for particle in values(self._particles) do
        if particle.visible then

            if self._has_exploded then
                local radius = particle.current_radius or particle.radius
                love.graphics.setColor(particle.color)
                love.graphics.circle("fill", particle.position_x, particle.position_y, radius)
            else
                local radius = particle.radius
                love.graphics.setColor(particle.color[1], particle.color[2], particle.color[3], 1)
                love.graphics.circle("fill", self._rocket.position_x, self._rocket.position_y, radius)
            end
        end
    end
end

--- @brief
function ow.Fireworks:get_is_done()
    return not self._active
end