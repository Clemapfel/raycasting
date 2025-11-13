require "common.random"
require "common.color"

rt.settings.player_particles = {
    ring_thickness = 7,
    ring_n_outer_vertices = 32,
    ring_max_radius = 32,
    ring_lifetime = 0.5, -- seconds
    ring_inner_opacity = 0.9,
    ring_compression = 0.5,

    min_radius = 3,
    max_radius = 5,
    min_velocity = 100,
    max_velocity = 350,
    min_lifetime = 0.25,
    max_lifetime = 0.5,
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
function rt.PlayerParticles:spawn(n_particles, origin_x, origin_y, hue, direction_x, direction_y, player_velocity_x, player_velocity_y)
    local batch = {}
    table.insert(self._batches, batch)
    self:_init_batch(batch,
        n_particles,
        origin_x, origin_y,
        hue,
        direction_x, direction_y,
        player_velocity_x, player_velocity_y
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
function rt.PlayerParticles:_init_batch(
    batch, n_particles,
    origin_x, origin_y,
    hue,
    direction_x, direction_y,
    player_vx, player_vy
)
    require "table.new"

    batch.origin_x = origin_x
    batch.origin_y = origin_y

    local settings = rt.settings.player_particles
    local n_path_points = settings.n_path_points

    local hue_offset = settings.hue_offset
    local min_velocity, max_velocity = settings.min_velocity, settings.max_velocity
    local min_mass, max_mass = settings.min_mass, settings.max_mass
    local min_radius, max_radius = settings.min_radius, settings.max_radius
    local min_lifetime, max_lifetime = settings.min_lifetime, settings.max_lifetime
    local velocity_influence = settings.velocity_influence
    local offset = 2 * rt.settings.player.radius
    local velocity_angle = math.angle(direction_x, direction_y)
    local min_angle = math.normalize_angle(velocity_angle - settings.velocity_offset)
    local max_angle = math.normalize_angle(velocity_angle + settings.velocity_offset)

    batch.particles = {}
    for i = 1, n_particles do
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

    do
        local data = {}
        local indices = {}
        local function add_vertex(x, y, opacity)
            table.insert(data, { x, y, 0, 0, 1, 1, 1, opacity })
        end

        local center_x, center_y = origin_x, origin_y
        local thickness = rt.settings.player_particles.ring_thickness
        local n_segments = rt.settings.player_particles.ring_n_outer_vertices
        local radius = 1

        local outer_radius = radius + thickness / 2
        local inner_radius = radius - thickness / 2

        for i = 0, n_segments - 1 do
            local angle = (i / n_segments) * math.pi * 2
            local cos_angle = math.cos(angle)
            local sin_angle = math.sin(angle)

            local outer_x = center_x + cos_angle * outer_radius
            local outer_y = center_y + sin_angle * outer_radius
            add_vertex(outer_x, outer_y, 1)

            local inner_x = center_x + cos_angle * inner_radius
            local inner_y = center_y + sin_angle * inner_radius
            add_vertex(inner_x, inner_y,  0)
        end

        for i = 0, n_segments - 1 do
            local next_i = (i + 1) % n_segments

            local outer_current = i * 2 + 1
            local inner_current = i * 2 + 2
            local outer_next = next_i * 2 + 1
            local inner_next = next_i * 2 + 2

            table.insert(indices, outer_current)
            table.insert(indices, inner_current)
            table.insert(indices, outer_next)

            table.insert(indices, outer_next)
            table.insert(indices, inner_current)
            table.insert(indices, inner_next)
        end

        batch.ring_mesh_data = data
        batch.ring_elapsed = 0
        batch.ring_angle = math.angle(player_vx, player_vy)
        batch.ring_color = { rt.lcha_to_rgba(0.8, 1, hue, 1) }

        batch.ring_mesh = rt.Mesh(
            data,
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STREAM
        )
        batch.ring_mesh:set_vertex_map(indices)
    end

    self:_update_batch(batch, 0) -- builds particle polygons
end

--- @brief
function rt.PlayerParticles:_update_batch(batch, delta)
    local settings = rt.settings.player_particles

    batch.ring_elapsed = batch.ring_elapsed + delta

    do -- update halo
        local center_x, center_y = batch.origin_x, batch.origin_y
        local thickness = rt.settings.player_particles.ring_thickness
        local n_segments = rt.settings.player_particles.ring_n_outer_vertices

        local fraction = math.min(1, batch.ring_elapsed / settings.ring_lifetime)
        local radius = fraction * settings.ring_max_radius
        local opacity = rt.InterpolationFunctions.SINUSOID_EASE_OUT(1 - fraction)

        local outer_radius = radius + thickness / 2
        local inner_radius = radius - thickness / 2

        local function set_vertex(i, x, y, t)
            local data = batch.ring_mesh_data[i]
            data[1] = x
            data[2] = y
            data[8] = t -- alpha
        end

        local cos_ring = math.cos(batch.ring_angle)
        local sin_ring = math.sin(batch.ring_angle)

        local vertex_i = 1
        for i = 0, n_segments - 1 do
            local angle = (i / n_segments) * math.pi * 2
            local cos_angle = math.cos(angle)
            local sin_angle = math.sin(angle) * settings.ring_compression

            local outer_x = cos_angle * outer_radius
            local outer_y = sin_angle * outer_radius
            local rotated_outer_x = center_x + outer_x * cos_ring - outer_y * sin_ring
            local rotated_outer_y = center_y + outer_x * sin_ring + outer_y * cos_ring
            set_vertex(vertex_i + 0, rotated_outer_x, rotated_outer_y, opacity)

            local inner_x = cos_angle * inner_radius
            local inner_y = sin_angle * inner_radius
            local rotated_inner_x = center_x + inner_x * cos_ring - inner_y * sin_ring
            local rotated_inner_y = center_y + inner_x * sin_ring + inner_y * cos_ring
            set_vertex(vertex_i + 1, rotated_inner_x, rotated_inner_y, opacity * settings.ring_inner_opacity)

            vertex_i = vertex_i + 2
        end

        batch.ring_mesh:replace_data(batch.ring_mesh_data)
    end

    -- update particles
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
    return n_updated == 0 and batch.ring_elapsed > settings.ring_lifetime
end

--- @brief
function rt.PlayerParticles:_draw_batch(batch, is_bloom)
    if is_bloom == nil then is_bloom = false end

    love.graphics.setLineWidth(1)
    local alpha = ternary(is_bloom, 0.4, 1)

    love.graphics.push("all")

    love.graphics.setColor(batch.ring_color)
    batch.ring_mesh:draw()

    for particle in values(batch.particles) do
        local radius = particle[_radius] * particle[_mass]
        local path = particle[_path]
        local px, py = path[#path - 3], path[#path - 2]
        if radius > 1 then
            love.graphics.setColor(particle[_color_r], particle[_color_g], particle[_color_b], alpha * particle[_color_a])
            love.graphics.polygon("fill", particle[_polygon])
            love.graphics.arc("fill", "open",
                px, py, radius,
                particle[_arc_min], particle[_arc_max]
            )

            love.graphics.setBlendMode("add", "premultiplied")
            local t = 0.3
            love.graphics.setColor(
                t * particle[_color_r],
                t * particle[_color_g],
                t * particle[_color_b],
            1)
            love.graphics.arc("line", "open",
                px, py, radius,
                particle[_arc_min], particle[_arc_max]
            )
            love.graphics.line(particle[_polygon])
        end
    end

    love.graphics.pop()
end
