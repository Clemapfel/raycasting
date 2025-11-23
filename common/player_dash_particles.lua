rt.settings.player_dash_particles = {
    segment_lifetime = 1,

    particle = {
        spawn_density = 0.25,
        min_radius = 3,
        max_radius = 5,
        min_lifetime = 1,
        max_lifetime = 1,
        min_velocity = 30,
        max_velocity = 50,

        position_jitter_offset = 4, -- px
        velocity_decay = 20 -- (px / s) / s
    },

    gravity = 20
}

--- @class rt.PlayerDashParticles
rt.PlayerDashParticles = meta.class("PlayerDashParticles")

--- @brief
function rt.PlayerDashParticles:instantiate()
    self._batches = {}
    self._current_batch = nil
end

local _x = 1
local _y = 2
local _velocity_x = 3
local _velocity_y = 4
local _lifetime_elapsed = 5
local _lifetime = 6
local _scale = 7
local _radius = 8

--- @brief
function rt.PlayerDashParticles:_add(
    start_or_append, -- whether to create a new batch or add to current
    x, y,
    normal_x, normal_y,
    hue
)
    if self._current_batch == nil then start_or_append = true end

    local r, g, b = rt.lcha_to_rgba(0.8, 1, hue, 1)
    local segment = {
        x = x,
        y = y,
        normal_x = normal_x,
        normal_y = normal_y,
        hue = hue,
        timestamp = love.timer.getTime(),
        r = r,
        g = g,
        b = b,
        opacity = 1,
        particles = {}
    }

    local batch
    if start_or_append == true then
        batch = {
            segments = { segment }
        }

        table.insert(self._batches, batch)
        self._current_batch = batch
    else
        batch = self._current_batch
        table.insert(batch.segments, segment)
    end

    if #batch.segments > 1 then
        local settings = rt.settings.player_dash_particles.particle
        local n_particles = math.ceil(settings.spawn_density)

        local last = batch.segments[#batch.segments - 1]
        local current = batch.segments[#batch.segments - 0]

        local dx, dy = math.normalize(current.x - last.x, current.y - last.y)

        for particle_i = 1, n_particles do
            local t = (particle_i - 1) / n_particles
            local particle_x, particle_y = math.mix2(current.x, current.y, last.x, last.y, t)
            local particle_velocity = rt.random.number(settings.min_velocity, settings.max_velocity)
            local radius = rt.random.number(settings.min_radius, settings.max_radius)
            local offset = rt.random.number(-settings.position_jitter_offset, settings.position_jitter_offset)

            local particle = {
                [_x] = particle_x + dx * offset + normal_x * radius, -- prevent overlap with ground
                [_y] = particle_y + dy * offset + normal_y * radius,
                [_velocity_x] = 0, --normal_x * particle_velocity,
                [_velocity_y] = 0, --normal_y * particle_velocity,
                [_lifetime_elapsed] = 0,
                [_lifetime] = rt.random.number(settings.min_lifetime, settings.max_lifetime),
                [_radius] = radius,
                [_scale] = 0
            }

            table.insert(segment.particles, particle)
        end
    end
end

--- @brief
function rt.PlayerDashParticles:start(...)
    self:_add(true, ...)
end

--- @brief
function rt.PlayerDashParticles:append(...)
    self:_add(false, ...)
end

--- @brief
function rt.PlayerDashParticles:update(delta)
    local now = love.timer.getTime()
    local to_remove = {}

    local scale_easing = function(t)
        return rt.InterpolationFunctions.SINUSOID_EASE_OUT(t, 15)
    end

    local settings = rt.settings.player_dash_particles

    for batch_i, batch in ipairs(self._batches) do
        local is_done = true
        for segment_i = 1, #batch.segments do
            local segment = batch.segments[segment_i]

            local time_fraction = (now - segment.timestamp) / rt.settings.player_dash_particles.segment_lifetime
            segment.opacity = 1 - math.min(1, time_fraction)
            segment.r, segment.g, segment.b = rt.lcha_to_rgba(0.8, 1, segment.hue, 1)

            if time_fraction <= 1 then is_done = false end

            -- update particles
            local velocity_decay = rt.settings.player_dash_particles.particle.velocity_decay
            for particle in values(segment.particles) do
                local vx, vy = particle[_velocity_x], particle[_velocity_y]
                particle[_x] = particle[_x] + vx * delta
                particle[_y] = particle[_y] + vy * delta

                local magnitude = math.magnitude(vx, vy)
                magnitude = magnitude - velocity_decay * delta
                vx, vy = math.normalize(vx, vy)
                vx = vx * magnitude
                vy = vy * magnitude

                particle[_velocity_x] = vx + settings.gravity * delta
                particle[_velocity_y] = vy + settings.gravity * delta

                particle[_lifetime_elapsed] = particle[_lifetime_elapsed] + delta
                particle[_scale] = scale_easing(math.min(1, particle[_lifetime_elapsed] / particle[_lifetime]))
            end
        end

        if is_done then
            table.insert(to_remove, 1, batch_i)
        end
    end

    for batch_i in values(to_remove) do
        table.remove(self._batches, batch_i)
    end
end

--- @brief
function rt.PlayerDashParticles:draw()
    love.graphics.setLineWidth(1)

    local now = love.timer.getTime()
    for batch in values(self._batches) do
        if #batch.segments >= 2 then
            for i = 1, #batch.segments - 1 do
                local current = batch.segments[i+0]
                local next = batch.segments[i+1]

                local r, g, b, a = math.mix4(
                    current.r, current.g, current.b, current.opacity,
                    next.r, next.g, next.b, next.opacity,
                    0.5
                )
                love.graphics.setColor(r, g, b, a)
                --love.graphics.line(current.x, current.y, next.x, next.y)

                local black_r, black_g, black_b = rt.Palette.BLACK:unpack()

                love.graphics.setColor(black_r, black_g, black_b, a)
                for particle in values(current.particles) do
                    love.graphics.circle("fill", particle[_x], particle[_y], particle[_radius] * particle[_scale])
                end

                love.graphics.setColor(r, g, b, a)
                for particle in values(current.particles) do
                    love.graphics.circle("line", particle[_x], particle[_y], particle[_radius] * particle[_scale])
                end
            end
        end
    end
end