require "common.random"
require "common.color"

rt.settings.overworld.checkpoint_particles = {
    min_radius = 5,
    max_radius = 7,
    min_velocity = 400,
    max_velocity = 550,
    gravity = 200,
    velocity_influence = 0.7,
    min_mass = 1,
    max_mass = 1, -- fraction
    min_angle = 0,
    max_angle = 2 * math.pi,
    min_damping = 1,
    max_damping = 1,
    n_path_points = 20,
    n_particles = 200,
    min_hue = 0,
    max_hue = 1,
    min_lifetime = math.huge,
    max_lifetime = math.huge
}

--- @class ow.CheckpointParticles
ow.CheckpointParticles = meta.class("CheckpointParticles")

--- @brief
function ow.CheckpointParticles:instantiate()
    self._batches = {}
    self._bounds = {
        -math.huge,
        -math.huge,
        math.huge,
        math.huge
    }

    self._target_velocity_x = nil -- ignore if unset
    self._target_velocity_y = nil
    self._target_position_x = nil
    self._target_position_y = nil

    self._gravity_factor = 1
end

--- @brief
function ow.CheckpointParticles:spawn(origin_x, origin_y, settings)
    settings = settings or {}

    local batch = {}
    table.insert(self._batches, batch)

    for key, value in pairs(rt.settings.overworld.checkpoint_particles) do
        if settings[key] == nil then
            settings[key] = value
        end
    end

    self:_init_batch(batch, origin_x, origin_y, settings)
end

--- @brief update screen bounds, use to determine when a batch should despawn
function ow.CheckpointParticles:set_screen_bounds(aabb_or_x, y, width, height)
    local aabb
    if meta.is_number(aabb_or_x) then
        aabb = rt.AABB(aabb_or_x, y, width, height)
    else
        aabb = aabb_or_x
    end

    self._bounds[1] = aabb.x
    self._bounds[2] = aabb.y
    self._bounds[3] = aabb.x + aabb.width
    self._bounds[4] = aabb.y + aabb.height
end

--- @brief
function ow.CheckpointParticles:set_target_velocity(vx, vy)
    self._target_velocity_x = vx
    self._target_velocity_y = vy
end

--- @brief
function ow.CheckpointParticles:set_target_position(px, py)
    self._target_position_x = px
    self._target_position_y = py
end

--- @brief
function ow.CheckpointParticles:set_gravity_factor(t)
    self._gravity_factor = t
end

--- @brief
function ow.CheckpointParticles:update(delta)
    local to_remove = {}
    for batch_i, batch in ipairs(self._batches) do
        local is_done = self:_update_batch(batch, delta)
        if is_done then table.insert(to_remove, 1, batch_i) end
    end

    for i in values(to_remove) do table.remove(self._batches, i) end
end

--- @brief
function ow.CheckpointParticles:draw()
    for batch in values(self._batches) do
        self:_draw_batch(batch, false) -- no bloom
    end
end

--- @brief
function ow.CheckpointParticles:draw_bloom()
    for batch in values(self._batches) do
        self:_draw_batch(batch, true)
    end
end

--- @brief
function ow.CheckpointParticles:clear()
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
local _damping = 11
local _gravity = 12
local _lifetime_elapsed = 13
local _lifetime = 14
local _path = 15
local _polygon = 16
local _arc_min = 17
local _arc_max = 18

--- @brief
function ow.CheckpointParticles:_init_batch(batch, origin_x, origin_y, settings)
    require "table.new"

    local n_path_points = settings.n_path_points

    local min_velocity, max_velocity = settings.min_velocity, settings.max_velocity
    local min_mass, max_mass = settings.min_mass, settings.max_mass
    local min_radius, max_radius = settings.min_radius, settings.max_radius

    local velocity_influence = settings.velocity_influence
    local offset = 2 * rt.settings.player.radius

    batch.particles = {}
    batch.settings = settings
    for i = 1, settings.n_particles do
        local vx, vy = math.normalize(rt.random.number(-1, 1), rt.random.number(-1, 1))

        local mass_t = rt.random.number(0, 1)
        local mass = math.mix(min_mass, max_mass, mass_t)
        local magnitude = math.mix(min_velocity, max_velocity, mass_t)
        local particle_hue = rt.random.number(settings.min_hue, settings.max_hue)
        local r, g, b, _ = rt.lcha_to_rgba(0.8, 1, particle_hue, 1)
        local radius = math.mix(min_radius, max_radius, mass)

        local angle = rt.random.number(settings.min_angle, settings.max_angle)
        local dx = math.cos(angle)
        local dy = math.sin(angle)
        local position_x = origin_x + dx * offset
        local position_y = origin_y + dy * offset

        local particle = {
            [_position_x] = position_x,
            [_position_y] = position_y,
            [_velocity_x] = magnitude * dx,
            [_velocity_y] = magnitude * dy,
            [_color_r] = r,
            [_color_g] = g,
            [_color_b] = b,
            [_color_a] = 1,
            [_mass] = mass,
            [_radius] = radius,
            [_lifetime_elapsed] = 0,
            [_lifetime] = rt.random.number(settings.min_lifetime, settings.max_lifetime),
            [_arc_min] = 0,
            [_arc_max] = 0,
            [_path] = {},
            [_gravity] = settings.gravity,
            [_damping] = rt.random.number(settings.min_damping, settings.max_damping),
            [_polygon] = {}
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
function ow.CheckpointParticles:_update_batch(batch, delta)
    local to_remove = {}
    local n_updated = 0
    local min_x, min_y, max_x, max_y = table.unpack(self._bounds)

    local arc_offset = math.pi / 2

    local target_nvx, target_nvy
    if self._target_velocity_x ~= nil and self._target_velocity_y ~= nil then
        target_nvx, target_nvy = math.normalize(self._target_velocity_x, self._target_velocity_y)
    end

    local left, right = {}, {} -- buffered
    for particle_i, particle in ipairs(batch.particles) do
        local px, py = particle[_position_x], particle[_position_y]

        px = px + particle[_velocity_x] * delta
        py = py + particle[_velocity_y] * delta

        local path = particle[_path]

        local last_x, last_y = path[1], path[2]
        if (px < min_x or px > max_x or py < min_y or py > max_y)
            and (last_x < min_x or last_x > max_x or last_y < min_y or last_y > max_y)
        then
            table.insert(to_remove, 1, particle_i)
            goto continue
        end

        local mass = particle[_mass]
        local vx, vy = particle[_velocity_x], particle[_velocity_y]

        local angle = math.angle(vx, vy)
        particle[_arc_min] = angle - arc_offset
        particle[_arc_max] = angle + arc_offset

        local gravity_x = particle[_gravity] * delta
        local gravity_y = particle[_gravity] * delta

        vx = vx + mass * gravity_x * self._gravity_factor
        vy = vy + mass * gravity_y * self._gravity_factor

        table.insert(path, px)
        table.insert(path, py)
        table.remove(path, 1)
        table.remove(path, 1)

        particle[_position_x] = px
        particle[_position_y] = py
        particle[_velocity_x] = vx * particle[_damping]
        particle[_velocity_y] = vy * particle[_damping]

        particle[_lifetime_elapsed] = particle[_lifetime_elapsed] + delta

        if particle[_lifetime_elapsed] > particle[_lifetime] then
            table.insert(to_remove, particle_i)
            goto continue
        end

        if particle[_lifetime_elapsed] == math.huge or particle[_lifetime] == math.huge then
            particle[_color_a] = 1
        else
            particle[_color_a] = rt.InterpolationFunctions.SINUSOID_EASE_OUT(
                1 - math.min(1, particle[_lifetime_elapsed] / particle[_lifetime])
            )
        end

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
function ow.CheckpointParticles:_draw_batch(batch, is_bloom)
    if is_bloom == nil then is_bloom = false end

    love.graphics.setLineWidth(1)
    local alpha = ternary(is_bloom, 0.4, 1)

    for particle in values(batch.particles) do
        local radius = particle[_radius] * particle[_mass]
        local path = particle[_path]
        local px, py = path[#path - 3], path[#path - 2]
        if radius > 1 then
            if is_bloom == false then
                rt.Palette.BLACK:bind()
                love.graphics.circle("fill",
                    px, py, radius
                )
            end

            love.graphics.setColor(particle[_color_r], particle[_color_g], particle[_color_b], particle[_color_a] * alpha)
            love.graphics.arc("line", "open",
                px, py, radius,
                particle[_arc_min], particle[_arc_max]
            )
        end
    end

    if is_bloom == false then
        local black_r, black_g, black_b, black_a = rt.Palette.BLACK:unpack()
        for particle in values(batch.particles) do
            local radius = particle[_radius] * particle[_mass]
            if radius > 1 then
                love.graphics.setColor(black_r, black_g, black_b, black_a * particle[_color_a])
                love.graphics.polygon("fill", particle[_polygon])
            end
        end
    end

    for particle in values(batch.particles) do
        local radius = particle[_radius] * particle[_mass]
        if radius > 1 then
            love.graphics.setColor(particle[_color_r], particle[_color_g], particle[_color_b], particle[_color_a] * alpha)
            love.graphics.line(particle[_polygon])
        end
    end
end


--- @brief
function ow.CheckpointParticles:collect_point_lights(callback)
    for batch in values(self._batches) do
        for particle in values(batch.particles) do
            --callback(particle[_position_x], particle[_position_y], particle[_radius], particle[_color_r], particle[_color_g], particle[_color_b], particle[_color_a])
        end
    end
end
