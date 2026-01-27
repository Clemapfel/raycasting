require "common.interpolation_functions"
require "common.random"

rt.settings.overworld.fireworks = {
    radius = 5,
    rocket_initial_speed = 500,
    rocket_acceleration = 600,
    rocket_gravity = 0,
    --rocket_restitution = 0.05, -- when colliding with player

    particle_air_resistance = 0.99,
    particle_gravity = 500,
    particle_restitution = 1,
    particle_fade_out_duration = 0.025,
    particle_burn_rate = 0.8,
    particle_velocity_inheritance = 0.6,
    particle_z_damping = 0.5,

    min_mass = 1,
    max_mass = 10,
    min_radius = 0.5,
    max_radius = 1,
    min_lifetime = 1.5,
    max_lifetime = 3,
    min_explosion_force = 300,
    max_explosion_force = 400,

    min_explosion_force_multiplier = 1,
    max_explosion_force_multiplier = 1.33,

    mass_easing = rt.InterpolationFunctions.SINUSOID_EASE_IN,
}

ow.Fireworks = meta.class("Fireworks")

--- @signal done (self, batch_id)
meta.add_signal(ow.Fireworks, "done")

local _data_mesh_format = {
    { location = 3, name = "position", format = "floatvec3" },
    { location = 4, name = "radius", format = "float" },
    { location = 5, name = "color", format = "floatvec4" },
}

local _particle_shader = rt.Shader("overworld/fireworks.glsl")

function ow.Fireworks:instantiate(player)
    self._batches = {}
    self._player = player
    self._batch_id = 0
end

local _position_x_offset = 0
local _position_y_offset = 1
local _position_z_offset = 2
local _velocity_x_offset = 3
local _velocity_y_offset = 4
local _velocity_z_offset = 5
local _explosion_direction_x_offset = 6
local _explosion_direction_y_offset = 7
local _explosion_direction_z_offset = 8
local _explosion_force_offset = 9
local _mass_offset = 10
local _radius_offset = 11
local _lifetime_offset = 12
local _color_r_offset = 13
local _color_g_offset = 14
local _color_b_offset = 15
local _color_a_offset = 16

local _stride = _color_a_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1
end

local _settings = rt.settings.overworld.fireworks
local _golden_ratio = (1 + math.sqrt(5)) / 2
local _rng = rt.random.number

--- @return batch_id
function ow.Fireworks:spawn(n_particles, start_x, start_y, end_x, end_y, hue_min, hue_max)
    if end_x == nil then end_x = start_x end
    if end_y == nil then end_y = start_y end
    if hue_min == nil then hue_min = 0 end
    if hue_max == nil then hue_max = 1 end

    meta.assert(n_particles, "Number", start_x, "Number", start_y, "Number", end_x, "Number", end_y, "Number", hue_min, "Number", hue_max, "Number")

    local data_mesh_data = {}
    local data = {}

    for particle_i = 1, n_particles do
        local idx = particle_i - 0.5 - 1
        local z = 1 - 2 * idx / n_particles
        local theta = 2 * math.pi * idx / _golden_ratio

        local radius = math.sqrt(1 - z * z)
        local x = radius * math.cos(theta)
        local y = radius * math.sin(theta)

        local perturbation = _rng(0.2, 0.5)
        local angle = _rng(0, 2 * math.pi)
        local offset = _rng(0, perturbation)
        x = x + offset * math.cos(angle)
        y = y + offset * math.sin(angle)
        z = z + offset * math.sin(angle) * 0.3

        x, y, z = math.normalize3(x, y, z)

        local hue = _rng(hue_min, hue_max)
        local r, g, b, _ = rt.lcha_to_rgba(0.8, 1, hue, 1)

        local i = #data + 1
        data[i + _position_x_offset] = start_x
        data[i + _position_y_offset] = start_y
        data[i + _position_z_offset] = 0
        data[i + _velocity_x_offset] = 0
        data[i + _velocity_y_offset] = 0
        data[i + _velocity_z_offset] = 0
        data[i + _explosion_direction_x_offset] = x
        data[i + _explosion_direction_y_offset] = y
        data[i + _explosion_direction_z_offset] = z
        data[i + _explosion_force_offset] = _rng(_settings.min_explosion_force, _settings.max_explosion_force)
        data[i + _mass_offset] = _rng(_settings.min_mass, _settings.max_mass)
        data[i + _radius_offset] = _rng(_settings.min_radius, _settings.max_radius)
        data[i + _lifetime_offset] = _rng(_settings.min_lifetime, _settings.max_lifetime)
        data[i + _color_r_offset] = r
        data[i + _color_g_offset] = g
        data[i + _color_b_offset] = b
        data[i + _color_a_offset] = 1

        table.insert(data_mesh_data, {
            data[i + _position_x_offset],
            data[i + _position_y_offset],
            data[i + _position_z_offset],
            data[i + _radius_offset],
            data[i + _color_r_offset],
            data[i + _color_g_offset],
            data[i + _color_b_offset],
            data[i + _color_a_offset]
        })
    end

    local n_outer_vertices = 8
    local center_x, center_y = 0, 0

    local ring_fraction = 0.15
    local outer_radius = _settings.radius
    local inner_radius = outer_radius - outer_radius * ring_fraction

    local inner_color = function() return 1, 1, 1, 1  end
    local outer_color = function() return 1, 1, 1, 1  end

    local particle_mesh_data = {
        { center_x, center_y, 0, 0, outer_color() }
    }

    -- inner disk
    for i = 1, n_outer_vertices do
        local angle = (i - 1) / n_outer_vertices * (2 * math.pi)
        local cx, cy = math.cos(angle), math.sin(angle)
        table.insert(particle_mesh_data, {
            center_x + cx * inner_radius,
            center_y + cy * inner_radius,
            cx,
            cy,
            inner_color()
        })
    end

    -- outer rim
    for i = 1, n_outer_vertices do
        local angle = (i - 1) / n_outer_vertices * (2 * math.pi)
        local cx, cy = math.cos(angle), math.sin(angle)
        table.insert(particle_mesh_data, {
            center_x + cx * outer_radius,
            center_y + cy * outer_radius,
            cx,
            cy,
            outer_color()
        })
    end

    local vertex_map = {}

    local center_index = 1
    local inner_start = 2
    local outer_start = 2 + n_outer_vertices

    for i = 0, n_outer_vertices - 1 do
        local inner_i = inner_start + i
        local inner_next = inner_start + ((i + 1) % n_outer_vertices)

        table.insert(vertex_map, center_index)
        table.insert(vertex_map, inner_i)
        table.insert(vertex_map, inner_next)
    end

    for i = 0, n_outer_vertices - 1 do
        local inner_i = inner_start + i
        local inner_next = inner_start + ((i + 1) % n_outer_vertices)
        local outer_i = outer_start + i
        local outer_next = outer_start + ((i + 1) % n_outer_vertices)

        table.insert(vertex_map, inner_i)
        table.insert(vertex_map, outer_i)
        table.insert(vertex_map, outer_next)

        table.insert(vertex_map, inner_i)
        table.insert(vertex_map, outer_next)
        table.insert(vertex_map, inner_next)
    end

    local particle_mesh = rt.Mesh(
        particle_mesh_data,
        rt.MeshDrawMode.TRIANGLES
    )
    particle_mesh:set_vertex_map(vertex_map)

    local data_mesh = rt.Mesh(
        data_mesh_data,
        rt.MeshDrawMode.POINTS,
        _data_mesh_format,
        rt.GraphicsBufferUsage.STREAM
    )

    for i = 1, #_data_mesh_format do
        particle_mesh:attach_attribute(
            data_mesh,
            _data_mesh_format[i].name,
            rt.MeshAttributeAttachmentMode.PER_INSTANCE
        )
    end

    local rocket_velocity_x, rocket_velocity_y = math.normalize(end_x - start_x, end_y - start_y)
    rocket_velocity_x = rocket_velocity_x * _settings.rocket_initial_speed
    rocket_velocity_y = rocket_velocity_y * _settings.rocket_initial_speed

    local batch = {
        elapsed = 0,
        n_particles = n_particles,
        start_x = start_x,
        start_y = start_y,
        end_x = end_x,
        end_y = end_y,
        rocket_x = start_x,
        rocket_y = start_y,
        rocket_vertices = { 0, 0, 1, 1, 0, 0, 1, 1 },
        rocket_velocity_x = rocket_velocity_x,
        rocket_velocity_y = rocket_velocity_y,
        rocket_acceleration_x = rocket_velocity_x / _settings.rocket_initial_speed * _settings.rocket_acceleration,
        rocket_acceleration_y = rocket_velocity_y / _settings.rocket_initial_speed * _settings.rocket_acceleration,
        rocket_color = { rt.lcha_to_rgba(0.8, 1, math.mix(hue_min, hue_max, 0.5), 1) },
        explosion_force_multiplier = _rng(_settings.min_explosion_force_multiplier, _settings.max_explosion_force_multiplier),
        particle_mesh = particle_mesh,
        particle_data = data,
        data_mesh_data = data_mesh_data,
        data_mesh = data_mesh,
        is_exploded = false,
        target_distance = math.distance(start_x, start_y, end_x, end_y),
        explosion_rocket_velocity_x = 0,
        explosion_rocket_velocity_y = 0,
        n_done_particles = 0,
        batch_id = self._batch_id
    }
    table.insert(self._batches, batch)

    self._batch_id = self._batch_id + 1
    return batch.batch_id
end

function ow.Fireworks:update(delta)
    if #self._batches == 0 then return end

    local to_remove = {}
    for batch_i, batch in ipairs(self._batches) do
        local n_done_particles = 0
        if not batch.is_exploded then
            batch.rocket_velocity_x = batch.rocket_velocity_x + batch.rocket_acceleration_x * delta
            batch.rocket_velocity_y = batch.rocket_velocity_y + batch.rocket_acceleration_y * delta
            batch.rocket_velocity_y = batch.rocket_velocity_y + _settings.rocket_gravity * delta

            batch.rocket_x = batch.rocket_x + batch.rocket_velocity_x * delta
            batch.rocket_y = batch.rocket_y + batch.rocket_velocity_y * delta

            --[[
            -- player deflects rocket
            if self._player ~= nil then
                local player_x, player_y = self._player:get_position()
                local player_r = self._player:get_radius()
                local rocket_r = _settings.radius

                local distance_to_player = math.distance(batch.rocket_x, batch.rocket_y, player_x, player_y)
                if distance_to_player < (player_r + rocket_r) then
                    local deflection_x, deflection_y = math.normalize(
                        batch.rocket_x - player_x,
                        batch.rocket_y - player_y
                    )

                    batch.rocket_x = player_x + deflection_x * (player_r + rocket_r)
                    batch.rocket_y = player_y + deflection_y * (player_r + rocket_r)

                    local velocity_magnitude = math.magnitude(batch.rocket_velocity_x, batch.rocket_velocity_y)
                    batch.rocket_velocity_x = deflection_x * velocity_magnitude * _settings.rocket_restitution
                    batch.rocket_velocity_y = deflection_y * velocity_magnitude * _settings.rocket_restitution

                    local new_direction_x, new_direction_y = math.normalize(batch.rocket_velocity_x, batch.rocket_velocity_y)
                    batch.rocket_acceleration_x = new_direction_x * _settings.rocket_acceleration
                    batch.rocket_acceleration_y = new_direction_y * _settings.rocket_acceleration
                end
            end
            ]]--

            local distance_traveled = math.distance(batch.start_x, batch.start_y, batch.rocket_x, batch.rocket_y)
            local distance_to_target = math.distance(batch.rocket_x, batch.rocket_y, batch.end_x, batch.end_y)

            if distance_traveled >= batch.target_distance * 0.9 or distance_to_target < _settings.radius * 2 then
                batch.is_exploded = true
                batch.explosion_rocket_velocity_x = batch.rocket_velocity_x
                batch.explosion_rocket_velocity_y = batch.rocket_velocity_y
            end

            local velocity_magnitude = math.magnitude(batch.rocket_velocity_x, batch.rocket_velocity_y)
            if velocity_magnitude > 0 then
                local left_x, left_y = math.normalize(-batch.rocket_velocity_y, batch.rocket_velocity_x)
                local right_x, right_y = math.normalize(batch.rocket_velocity_y, -batch.rocket_velocity_x)

                local rocket_length = 4 * _settings.radius
                local rocket_end_width = _settings.radius
                local rocket_start_width = rocket_end_width * 0.25

                local ndx, ndy = math.normalize(batch.rocket_velocity_x, batch.rocket_velocity_y)
                local start_x = batch.rocket_x - ndx * rocket_length
                local start_y = batch.rocket_y - ndy * rocket_length
                local end_x = batch.rocket_x
                local end_y = batch.rocket_y

                batch.rocket_vertices = {
                    end_x + left_x * rocket_end_width, end_y + left_y * rocket_end_width,
                    end_x + right_x * rocket_end_width, end_y + right_y * rocket_end_width,
                    start_x + right_x * rocket_start_width, start_y + right_y * rocket_start_width,
                    start_x + left_x * rocket_start_width, start_y + left_y * rocket_start_width
                }
            end

            local data = batch.particle_data
            for particle_i = 1, batch.n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                data[i + _position_x_offset] = batch.rocket_x
                data[i + _position_y_offset] = batch.rocket_y

                if batch.is_exploded then
                    local inherited_velocity_x = batch.explosion_rocket_velocity_x * _settings.particle_velocity_inheritance
                    local inherited_velocity_y = batch.explosion_rocket_velocity_y * _settings.particle_velocity_inheritance

                    data[i + _velocity_x_offset] = data[i + _explosion_direction_x_offset] * data[i + _explosion_force_offset] * batch.explosion_force_multiplier + inherited_velocity_x
                    data[i + _velocity_y_offset] = data[i + _explosion_direction_y_offset] * data[i + _explosion_force_offset] * batch.explosion_force_multiplier + inherited_velocity_y
                    data[i + _velocity_z_offset] = data[i + _explosion_direction_z_offset] * data[i + _explosion_force_offset] * batch.explosion_force_multiplier * _settings.particle_z_damping
                end
            end
        else
            local air_resistance = _settings.particle_air_resistance
            local gravity = _settings.particle_gravity
            local restitution = _settings.particle_restitution
            local burn_rate = _settings.particle_burn_rate

            local player_x, player_y, player_r
            if self._player ~= nil then
                player_x, player_y = self._player:get_position()
                player_r = self._player:get_radius()
            end

            batch.elapsed = batch.elapsed + delta
            local is_done = true

            local data = batch.particle_data

            for particle_i = 1, batch.n_particles do
                local i = _particle_i_to_data_offset(particle_i)

                local lifetime = data[i + _lifetime_offset]
                local fraction = batch.elapsed / lifetime

                if fraction >= 1 then
                    n_done_particles = n_done_particles + 1
                    goto continue
                end

                local opacity = 1
                local fade_out = _settings.particle_fade_out_duration
                if batch.elapsed > lifetime - fade_out then
                    opacity = (lifetime - batch.elapsed) / fade_out
                end
                data[i + _color_a_offset] = opacity

                local radius = 1 - fraction
                data[i + _radius_offset] = radius

                local burn_factor = _settings.mass_easing(1 - fraction)
                local velocity_burn_factor = math.mix(burn_rate, 1, burn_factor)
                local mass_factor = math.mix(0.2, 1, burn_factor)

                local vx = data[i + _velocity_x_offset] * (velocity_burn_factor * air_resistance ^ delta)
                local vy = data[i + _velocity_y_offset] * (velocity_burn_factor * air_resistance ^ delta)
                local vz = data[i + _velocity_z_offset] * (velocity_burn_factor * air_resistance ^ delta)

                vy = vy + mass_factor * gravity * delta

                local px = data[i + _position_x_offset] + vx * delta
                local py = data[i + _position_y_offset] + vy * delta
                local pz = data[i + _position_z_offset] + vz * delta

                if self._player ~= nil then
                    if math.distance(px, py, player_x, player_y) < (player_r + radius) then
                        local delta_x, delta_y = math.normalize(px - player_x, py - player_y)
                        px = player_x + delta_x * (player_r + radius)
                        py = player_y + delta_y * (player_r + radius)
                        vx = delta_x * math.abs(vx) * restitution
                        vy = delta_y * math.abs(vy) * restitution
                    end
                end

                data[i + _velocity_x_offset] = vx
                data[i + _velocity_y_offset] = vy
                data[i + _velocity_z_offset] = vz

                data[i + _position_x_offset] = px
                data[i + _position_y_offset] = py
                data[i + _position_z_offset] = pz

                if opacity > 0 then is_done = false end

                -- update data mesh

                local data_mesh_data_data = batch.data_mesh_data[particle_i]
                data_mesh_data_data[1] = px
                data_mesh_data_data[2] = py
                data_mesh_data_data[3] = px
                data_mesh_data_data[4] = radius
                data_mesh_data_data[5] = data[i + _color_r_offset]
                data_mesh_data_data[6] = data[i + _color_g_offset]
                data_mesh_data_data[7] = data[i + _color_b_offset]
                data_mesh_data_data[8] = data[i + _color_a_offset]

                ::continue::
            end

            if is_done then
                table.insert(to_remove, batch_i)
            end
        end

        batch.n_done_particles = n_done_particles
        batch.data_mesh:replace_data(batch.data_mesh_data)
    end

    if #to_remove > 0 then
        table.sort(to_remove, function(a, b) return a > b end)
        for batch_i in values(to_remove) do
            self:signal_emit("done", self._batches[batch_i].batch_id)
            table.remove(self._batches, batch_i)
        end
    end
end

function ow.Fireworks:draw()
    if #self._batches == 0 then return end

    for batch in values(self._batches) do
        if batch.is_exploded == false then
            love.graphics.setColor(batch.rocket_color)
            love.graphics.circle("fill", batch.rocket_x, batch.rocket_y, _settings.radius)
            love.graphics.polygon("fill", batch.rocket_vertices)
        else
            love.graphics.setColor(1, 1, 1, 1)
            _particle_shader:bind()
            batch.particle_mesh:draw_instanced(batch.n_particles)
            _particle_shader:unbind()
        end
    end
end

--- @brief
function ow.Fireworks:set_player(player)
    self._player = player
end

--- @brief
function ow.Fireworks:get_is_done()
    return #self._batches == 0
end

--- @brief
function ow.Fireworks:get_n_rockets()
    return #self._batches
end

--- @brief
function ow.Fireworks:get_n_particles()
    local n = 0
    for batch in values(self._batches) do
        n = n + (batch.n_particles - batch.n_done_particles)
    end
    return n
end

--- @brief
function ow.Fireworks:reset()
    self._batches = {}
end