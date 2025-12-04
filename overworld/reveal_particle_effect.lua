rt.settings.overworld.reveal_particle_effect = {
    min_velocity = 20,
    max_velocity = 200,
    min_lifetime = 0.5,
    max_lifetime = 1,
    hue_variance = 0.25,
    min_radius = 4,
    max_radius = 6,

    particle_density = 0.25, -- per px
    max_n_particles = 2000
}

--- @class ow.RevealParticleEffect
ow.RevealParticleEffect = meta.class("RevealParticleEffect")

--- @brief
function ow.RevealParticleEffect:instantiate(...)
    self._batches = {}
    if select("#", ...) > 0 then self:emit(...) end
end

local _x = 1
local _y = 2
local _velocity_x = 3
local _velocity_y = 4
local _lifetime_elapsed = 5
local _lifetime = 6
local _color_r = 7
local _color_g = 8
local _color_b = 9
local _radius = 10


--- @brief
function ow.RevealParticleEffect:emit(ax, ay, bx, by, side)
    if side == nil then side = 1 end

    meta.assert(
        ax, "Number",
        ay, "Number",
        bx, "Number",
        by, "Number",
        side, "Number" -- -1, or 1, winding order
    )

    local settings = rt.settings.overworld.reveal_particle_effect

    self._total_n_particles = 0
    local n_particles = settings.particle_density * math.distance(ax, ay, bx, by)
    local dx, dy = math.normalize(bx - ax, by - ay)
    local normal_x, normal_y
    if side == 1 then
        normal_x, normal_y = math.turn_left(dx, dy)
    elseif side == -1 then
        normal_x, normal_y = math.turn_right(dx, dy)
    end

    local batch = {}
    for i = 1, n_particles do
        self._total_n_particles = self._total_n_particles + 1
        if self._total_n_particles < settings.max_n_particles then
            local t = (i - 1) / n_particles
            local x, y = math.mix2(ax, ay, bx, by, t)
            local magnitude = rt.random.number(settings.min_velocity, settings.max_velocity) * rt.get_pixel_scale()
            local hue = rt.random.number(0, 1)
            local r, g, b, _ = rt.lcha_to_rgba(0.8, 1, hue, 1)
            local particle = {
                [_x] = x,
                [_y] = y,
                [_velocity_x] = normal_x * magnitude,
                [_velocity_y] = normal_y * magnitude,
                [_color_r] = r,
                [_color_g] = g,
                [_color_b] = b,
                [_lifetime_elapsed] = 0,
                [_lifetime] = rt.random.number(settings.min_lifetime, settings.max_lifetime),
                [_radius] = rt.random.number(settings.min_radius, settings.max_radius)
            }

            table.insert(batch, particle)
        end
    end

    table.insert(self._batches, batch)
end

--- @brief
function ow.RevealParticleEffect:update(delta)
    local batch_to_remove = {}
    for batch_i, batch in ipairs(self._batches) do
        local particle_to_remove = {}
        for particle_i, particle in ipairs(batch) do
            particle[_x] = particle[_x] + particle[_velocity_x] * delta
            particle[_y] = particle[_y] + particle[_velocity_y] * delta
            particle[_lifetime_elapsed] = particle[_lifetime_elapsed] + delta

            if particle[_lifetime_elapsed] > particle[_lifetime] then
                table.insert(particle_to_remove, 1, particle_i)
            end
        end

        for i in values(particle_to_remove) do
            table.remove(batch, i)
            self._total_n_particles = self._total_n_particles - 1
        end

        if #batch == 0 then
            table.insert(batch_to_remove, batch_i)
        end
    end

    for i in values(batch_to_remove) do
        table.remove(self._batches, i)
    end
end

--- @brief
function ow.RevealParticleEffect:draw()
    local black_r, black_g, black_b = rt.Palette.BLACK:unpack()
    love.graphics.setLineWidth(1)
    for batch in values(self._batches) do
        for particle in values(batch) do
            local t = 1 - math.min(1, particle[_lifetime_elapsed] / particle[_lifetime])
            local opacity = rt.InterpolationFunctions.SINUSOID_EASE_OUT(t)
            love.graphics.setColor(black_r, black_g, black_b, opacity)
            love.graphics.circle("fill", particle[_x], particle[_y], particle[_radius])

            love.graphics.setColor(particle[_color_r], particle[_color_g], particle[_color_b], opacity)
            rt.Palette.FOREGROUND:bind()
            love.graphics.circle("line", particle[_x], particle[_y], particle[_radius])

        end
    end
end