local factor = 80
rt.settings.overworld.reveal_particle_effect = {
    min_impulse = 0 * factor,
    max_impulse = 5 * factor,
    gravity = 20 * factor,

    min_mass = 0.6,
    max_mass = 1,
    gravity = 100,
    radius = 7,

    particle_density = 0.5, -- per px
    max_n_particles = 2000
}

--- @class ow.RevealParticleEffect
ow.RevealParticleEffect = meta.class("RevealParticleEffect")

local _particle_texture
local _particle_texture_padding = 20

--- @brief
function ow.RevealParticleEffect:instantiate(...)
    self._batches = {}
    if select("#", ...) > 0 then self:emit(...) end

    if _particle_texture == nil then
        local w, h = 200, 200
        local mesh

        do
            local radius = 0.5 * w
            local border = 0.05 * radius -- anti-aliasing outer ring
            local n_outer_vertices = 32
            mesh = rt.MeshRing(0, 0, radius - border, radius, true, n_outer_vertices)
            local n = mesh:get_n_vertices()
            mesh:set_vertex_color(1, 1, 1, 1, 0)
            for i = n, n - n_outer_vertices + 1, -1 do -- outer aliasing
                mesh:set_vertex_color(i, 1, 1, 1, 0)
            end
            mesh:set_vertex_color(1, 1, 1, 1)
        end

        local canvas_w, canvas_h = w + 2 * _particle_texture_padding, h + 2 * _particle_texture_padding
        _particle_texture = rt.RenderTexture(canvas_w, canvas_h, 4)
        love.graphics.push("all")
        love.graphics.reset()
        _particle_texture:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.translate(0.5 * canvas_w, 0.5 * canvas_h)
        mesh:draw()
        _particle_texture:unbind()
        love.graphics.pop()
    end
end

local _x = 1
local _y = 2
local _velocity_x = 3
local _velocity_y = 4
local _mass = 5
local _color_r = 6
local _color_g = 7
local _color_b = 8
local _rotation = 9
local _n_segments = 10

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

    local batch = {
        particles = {},
        gravity_x = -normal_x,
        gravity_y = -normal_y,
        ax = ax,
        ay = ay,
        bx = bx,
        by = by,
        side = side > 0
    }


    for i = 1, n_particles do
        self._total_n_particles = self._total_n_particles + 1
        if self._total_n_particles < settings.max_n_particles then
            local t = (i - 1) / n_particles
            local x, y = math.mix2(ax, ay, bx, by, t)
            local magnitude = rt.random.number(settings.min_impulse, settings.max_impulse) * rt.get_pixel_scale()
            local mass = rt.random.number(settings.min_mass, settings.max_mass)
            local hue = rt.random.number(0, 1)
            local r, g, b, _ = rt.lcha_to_rgba(0.8, 1, hue, 1)
            local particle = {
                [_x] = x,
                [_y] = y,
                [_velocity_x] = normal_x * magnitude * (1 + mass),
                [_velocity_y] = normal_y * magnitude * (1 + mass),
                [_mass] = mass,
                [_color_r] = r,
                [_color_g] = g,
                [_color_b] = b,
                [_rotation] = rt.random.number(0, 2 * math.pi),
                [_n_segments] = rt.random.choose(3, 4, 5, 6),
                [_segments] = points
            }

            table.insert(batch.particles, particle)
        end
    end

    table.insert(self._batches, batch)
end

local _get_side = function(vx, vy, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local cross = abx * vy - aby * vx
    return cross > 0
end

--- @brief
function ow.RevealParticleEffect:update(delta)
    local noise = function(x, y)
        return rt.random.noise(x, y) * 2 - 1
    end

    local gravity = rt.settings.overworld.reveal_particle_effect.gravity

    local batch_to_remove = {}
    for batch_i, batch in ipairs(self._batches) do
        local particle_to_remove = {}
        for particle_i, particle in ipairs(batch.particles) do
            particle[_x] = particle[_x] + particle[_velocity_x] * delta
            particle[_y] = particle[_y] + particle[_velocity_y] * delta

            particle[_velocity_x] = particle[_velocity_x] + (batch.gravity_x * gravity / particle[_mass]) * delta
            particle[_velocity_y] = particle[_velocity_y] + (batch.gravity_y * gravity / particle[_mass]) * delta

            if _get_side(particle[_x], particle[_y], batch.ax, batch.ay, batch.bx, batch.by) ~= batch.side then
                table.insert(particle_to_remove, 1, particle_i)
            end
        end

        for i in values(particle_to_remove) do
            table.remove(batch, i)
            self._total_n_particles = self._total_n_particles - 1
        end

        if #batch.particles == 0 then
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
    local radius = rt.settings.overworld.reveal_particle_effect.radius * rt.get_pixel_scale()
    local texture, texture_w, texture_h = _particle_texture:get_native(), _particle_texture:get_size()

    local line_width = 1

    love.graphics.push()
    love.graphics.origin()
    love.graphics.draw(texture)
    love.graphics.pop()

    love.graphics.clear(0.5, 0.5, 0.5, 1)
    love.graphics.push()

    love.graphics.setLineWidth(line_width)

    --rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.NORMAL)
    local damping = 0.05
    for batch in values(self._batches) do
        for particle in values(batch.particles) do
            local particle_radius = radius * particle[_mass] * rt.get_pixel_scale()

            --[[
            local scale_x, scale_y = particle_radius / (texture_w - _particle_texture_padding), particle_radius / (texture_h - _particle_texture_padding)
            love.graphics.setColor(particle[_color_r] * damping, particle[_color_g] * damping, particle[_color_b] * damping, 1)
            love.graphics.draw(
                texture,
                particle[_x], particle[_y], 0,
                scale_x, scale_y,
                0.5 * texture_w, 0.5 * texture_h
            )
            ]]--
            love.graphics.push()
            love.graphics.translate(particle[_x], particle[_y])
            love.graphics.rotate(particle[_rotation])

            rt.Palette.BLACK:bind()
            love.graphics.circle("fill",
                0, 0, particle_radius, particle[_n_segments]
            )

            love.graphics.setColor(particle[_color_r], particle[_color_g], particle[_color_b])
            love.graphics.circle("line",
                0, 0, particle_radius, particle[_n_segments]
            )

            love.graphics.pop()

        end
    end

    --rt.graphics.set_blend_mode(nil)

    love.graphics.pop()
end