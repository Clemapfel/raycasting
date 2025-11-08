require "common.random"
require "common.color"

rt.settings.player_particles = {
    min_radius = 5,
    max_radius = 7,
    min_velocity = 200,
    max_velocity = 550,
    min_lifetime = 0.5,
    max_lifetime = 1,
    gravity_x = 0,
    gravity_y = 0,
    velocity_influence = 0.7,
    min_mass = 1,
    max_mass = 1, -- fraction
    hue_offset = 0.4,
    velocity_offset = 0.25 * math.pi,
    n_path_points = 20,
    opacity_fade_duration = 20 / 60
}

--- @class rt.PlayerParticles
rt.PlayerParticles = meta.class("CheckpointParticles")

--- @brief
function rt.PlayerParticles:instantiate()
    self._batches = {}
end

--- @brief
function rt.PlayerParticles:spawn(n_particles, origin_x, origin_y, hue, player_velocity_x, player_velocity_y)
    local batch = {}
    table.insert(self._batches, batch)
    self:_init_batch(batch, origin_x, origin_y, hue, player_velocity_x or 0, player_velocity_y or 0)
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
local _color_r = 5
local _color_g = 6
local _color_b = 7
local _color_a = 8
local _mass = 9
local _radius = 10
local _path = 11
local _polygon = 12
local _arc_min = 13
local _arc_max = 14
local _lifetime_elapsed = 15
local _lifetime = 16

--- @brief
function rt.PlayerParticles:_init_batch(batch, origin_x, origin_y, hue, player_vx, player_vy)
    require "table.new"

    local settings = rt.settings.player_particles
    local n_path_points = settings.n_path_points

    local hue_offset = settings.hue_offset
    local min_velocity, max_velocity = settings.min_velocity, settings.max_velocity
    local min_mass, max_mass = settings.min_mass, settings.max_mass
    local min_radius, max_radius = settings.min_radius, settings.max_radius
    local min_lifetime, max_lifetime = settings.min_lifetime, settings.max_lifetime
    local velocity_influence = settings.velocity_influence
    local offset = 2 * rt.settings.player.radius
    local velocity_angle = math.angle(player_vx, player_vy)
    local min_angle = math.normalize_angle(velocity_angle - settings.velocity_offset)
    local max_angle = math.normalize_angle(velocity_angle + settings.velocity_offset)

    batch.particles = {}
    for i = 1, rt.settings.overworld.goal.n_particles do
        local vx, vy = math.normalize(rt.random.number(-1, 1), rt.random.number(-1, 1))

        local mass_t = rt.random.number(0, 1)
        local mass = math.mix(min_mass, max_mass, mass_t)
        local magnitude = math.mix(min_velocity, max_velocity, mass_t)
        local particle_hue = hue + rt.random.number(-hue_offset, hue_offset)
        local r, g, b, _ = rt.lcha_to_rgba(0.8, 1, particle_hue, 1)
        local radius = math.mix(min_radius, max_radius, mass)

        local angle = math.mix(min_angle, max_angle, rt.random.number(0, 1))
        local dx = math.cos(angle)
        local dy = math.sin(angle)
        local position_x = origin_x + dx * offset
        local position_y = origin_y + dy * offset

        local particle = {
            [_position_x] = position_x,
            [_position_y] = position_y,
            [_velocity_x] = magnitude * dx + player_vx * velocity_influence * (1 - mass),
            [_velocity_y] = magnitude * dy + player_vy * velocity_influence * (1 - mass),
            [_color_r] = r,
            [_color_g] = g,
            [_color_b] = b,
            [_color_a] = 1,
            [_mass] = mass,
            [_radius] = radius,
            [_arc_min] = 0,
            [_arc_max] = 0,
            [_path] = {},
            [_polygon] = {},
            [_lifetime_elapsed] = 0,
            [_lifetime] = rt.random.number(min_lifetime, max_lifetime)
        }

        for _ = 1, n_path_points do
            table.insert(particle[_path], position_x - dx * radius)
            table.insert(particle[_path], position_y - dy * radius)
        end

        table.insert(batch.particles, particle)
    end

    self:_update_batch(batch, 0) -- build polygons
end

--- @brief
function rt.PlayerParticles:_update_batch(batch, delta)
    local settings = rt.settings.player_particles
    local gravity_x = settings.gravity_x * delta
    local gravity_y = settings.gravity_y * delta

    local to_remove = {}
    local n_updated = 0

    local velocity_alignment = settings.velocity_alignment
    local position_alignment = settings.position_alignment

    local arc_offset = math.pi / 2

    local target_nvx, target_nvy

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

        px = px + particle[_velocity_x] * delta
        py = py + particle[_velocity_y] * delta

        local path = particle[_path]

        local last_x, last_y = path[1], path[2]

        local mass = particle[_mass]
        local vx, vy = particle[_velocity_x], particle[_velocity_y]

        local angle = math.angle(vx, vy)
        particle[_arc_min] = angle - arc_offset
        particle[_arc_max] = angle + arc_offset

        vx = vx + mass * gravity_x
        vy = vy + mass * gravity_y

        table.insert(path, px)
        table.insert(path, py)
        table.remove(path, 1)
        table.remove(path, 1)

        particle[_position_x] = px
        particle[_position_y] = py
        particle[_velocity_x] = vx
        particle[_velocity_y] = vy

        local radius = particle[_radius] * 0.5 * particle[_mass]

        local node_i, n_nodes = 1, math.floor(#path / 2)
        for i = 1, #path - 2, 2 do
            local t = (node_i - 1) / (n_nodes - 1)
            local x1, y1 = path[i+0], path[i+1]
            local x2, y2 = path[i+2], path[i+3]

            local dx, dy = math.normalize(x2 - x1, y2 - y1)
            local left_nx, left_ny = math.turn_left(dx, dy)
            local right_nx, right_ny = math.turn_right(dx, dy)

            left[node_i+0] = x1 + left_nx * radius * t
            left[node_i+1] = y1 + left_ny * radius * t

            right[node_i+0] = x1 + right_nx * radius * t
            right[node_i+1] = y1 + right_ny * radius * t

            node_i = node_i + 2
        end

        local polygon = particle[_polygon]

        node_i = 1
        for i = #left - 1, 1, -2 do
            polygon[node_i+0] = left[i+0]
            polygon[node_i+1] = left[i+1]
            node_i = node_i + 2
        end

        for i = 1, #right, 2 do
            polygon[node_i+0] = right[i+0]
            polygon[node_i+1] = right[i+1]
            node_i = node_i + 2
        end

        n_updated = n_updated + 1

        ::continue::
    end

    for i in values(to_remove) do table.remove(batch.particles, i) end
    return n_updated == 0
end

--- @brief
function rt.PlayerParticles:_draw_batch(batch, is_bloom)
    if is_bloom == nil then is_bloom = false end

    love.graphics.setLineWidth(1)
    local alpha = ternary(is_bloom, 0.4, 1)

    for particle in values(batch.particles) do
        local radius = particle[_radius] * particle[_mass]
        local path = particle[_path]
        local px, py = path[#path - 3], path[#path - 2]
        if radius > 1 then
            rt.Palette.BLACK:bind()
            love.graphics.polygon("fill", particle[_polygon])
            love.graphics.arc("fill", "open",
                px, py, radius,
                particle[_arc_min], particle[_arc_max]
            )

            love.graphics.setColor(particle[_color_r], particle[_color_g], particle[_color_b], alpha * particle[_color_a])
            love.graphics.arc("line", "open",
                px, py, radius,
                particle[_arc_min], particle[_arc_max]
            )
            love.graphics.line(particle[_polygon])
        end
    end
end
