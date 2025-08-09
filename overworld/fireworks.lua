rt.settings.overworld.fireworks = {
    radius = 7,
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
    radius_easing = rt.InterpolationFunctions.LINEAR,
    opacity_easing = rt.InterpolationFunctions.LINEAR
}

ow.Fireworks = meta.class("Fireworks")

local _data_mesh_format = {
    { location = 3, name = "position", format = "floatvec3" },
    { location = 4, name = "color", format = "floatvec4" },
    { location = 5, name = "velocity", format = "floatvec3" },
    { location = 6, name = "explosion_direction", format = "floatvec3" },
    { location = 7, name = "explosion_force", format = "float" },
    { location = 8, name = "mass", format = "float" },
    { location = 9, name = "radius", format = "float" },
    { location = 10, name = "lifetime", format = "float" }
}

local _particle_shader = nil

function ow.Fireworks:instantiate(player)
    if _particle_shader == nil then _particle_shader = rt.Shader("overworld/fireworks.glsl") end
    self._batches = {}
    self._player = player
end

local _position_x = 1
local _position_y = 2
local _position_z = 3
local _color_r = 4
local _color_g = 5
local _color_b = 6
local _color_a = 7
local _velocity_x = 8
local _velocity_y = 9
local _velocity_z = 10
local _explosion_direction_x = 11
local _explosion_direction_y = 12
local _explosion_direction_z = 13
local _explosion_force = 14
local _mass = 15
local _radius = 16
local _lifetime = 17

local _settings = rt.settings.overworld.fireworks
local _golden_ratio = (1 + math.sqrt(5)) / 2
local _rng = rt.random.number

function ow.Fireworks:spawn(n_particles, start_x, start_y, end_x, end_y, hue_min, hue_max)
    if end_x == nil then end_x = start_x end
    if end_y == nil then end_y = start_y end
    if hue_min == nil then hue_min = 0 end
    if hue_max == nil then hue_max = 1 end

    meta.assert(n_particles, "Number", start_x, "Number", start_y, "Number", end_x, "Number", end_y, "Number", hue_min, "Number", hue_max, "Number")

    local data_mesh_data = {}
    for i = 1, n_particles do
        local idx = i - 0.5 - 1
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

        table.insert(data_mesh_data, {
            [_position_x] = start_x,
            [_position_y] = start_y,
            [_position_z] = 0,
            [_color_r] = r,
            [_color_g] = g,
            [_color_b] = b,
            [_color_a] = 1,
            [_velocity_x] = 0,
            [_velocity_y] = 0,
            [_velocity_z] = 0,
            [_explosion_direction_x] = x,
            [_explosion_direction_y] = y,
            [_explosion_direction_z] = z,
            [_explosion_force] = _rng(_settings.min_explosion_force, _settings.max_explosion_force),
            [_mass] = _rng(_settings.min_mass, _settings.max_mass),
            [_radius] = _rng(_settings.min_radius, _settings.max_radius),
            [_lifetime] = _rng(_settings.min_lifetime, _settings.max_lifetime)
        })
    end

    local particle_mesh = rt.MeshCircle(
        0, 0,
        _settings.radius, _settings.radius,
        8
    )

    for i = 2, particle_mesh:get_n_vertices() do
        particle_mesh:set_vertex_color(i, 1, 1, 1, 0)
    end

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

    table.insert(self._batches, {
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
        data_mesh_data = data_mesh_data,
        data_mesh = data_mesh,
        is_exploded = false,
        target_distance = math.distance(start_x, start_y, end_x, end_y),
        explosion_rocket_velocity_x = 0,
        explosion_rocket_velocity_y = 0,
    })
end

function ow.Fireworks:update(delta)
    local to_remove = {}
    for batch_i, batch in ipairs(self._batches) do
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

            for particle in values(batch.data_mesh_data) do
                particle[_position_x] = batch.rocket_x
                particle[_position_y] = batch.rocket_y

                if batch.is_exploded then
                    local inherited_velocity_x = batch.explosion_rocket_velocity_x * _settings.particle_velocity_inheritance
                    local inherited_velocity_y = batch.explosion_rocket_velocity_y * _settings.particle_velocity_inheritance

                    particle[_velocity_x] = particle[_explosion_direction_x] * particle[_explosion_force] * batch.explosion_force_multiplier + inherited_velocity_x
                    particle[_velocity_y] = particle[_explosion_direction_y] * particle[_explosion_force] * batch.explosion_force_multiplier + inherited_velocity_y
                    particle[_velocity_z] = particle[_explosion_direction_z] * particle[_explosion_force] * batch.explosion_force_multiplier * _settings.particle_z_damping
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

            for particle in values(batch.data_mesh_data) do
                local lifetime = particle[_lifetime]
                local fraction = batch.elapsed / lifetime

                local fade_out = _settings.particle_fade_out_duration
                local opacity = 1
                if batch.elapsed > lifetime - fade_out then
                    opacity = _settings.opacity_easing((lifetime - batch.elapsed) / fade_out)
                end
                particle[_color_a] = opacity

                particle[_radius] = _settings.radius_easing(1 - fraction)

                local burn_factor = _settings.mass_easing(1 - fraction)
                local velocity_burn_factor = math.mix(burn_rate, 1, burn_factor)
                local mass_factor = math.mix(0.2, 1, burn_factor)

                particle[_velocity_x] = particle[_velocity_x] * (velocity_burn_factor * air_resistance ^ delta)
                particle[_velocity_y] = particle[_velocity_y] * (velocity_burn_factor * air_resistance ^ delta)
                particle[_velocity_z] = particle[_velocity_z] * (velocity_burn_factor * air_resistance ^ delta)

                particle[_velocity_y] = particle[_velocity_y] + mass_factor * gravity * delta

                particle[_position_x] = particle[_position_x] + particle[_velocity_x] * delta
                particle[_position_y] = particle[_position_y] + particle[_velocity_y] * delta
                particle[_position_z] = particle[_position_z] + particle[_velocity_z] * delta

                if self._player ~= nil then
                    local particle_r = particle[_radius]
                    if math.distance(particle[_position_x], particle[_position_y], player_x, player_y) < (player_r + particle_r) then
                        local delta_x, delta_y = math.normalize(particle[_position_x] - player_x, particle[_position_y] - player_y)
                        particle[_position_x] = player_x + delta_x * (player_r + particle_r)
                        particle[_position_y] = player_y + delta_y * (player_r + particle_r)

                        particle[_velocity_x] = delta_x * math.abs(particle[_velocity_x]) * restitution
                        particle[_velocity_y] = delta_y * math.abs(particle[_velocity_y]) * restitution
                    end
                end

                if opacity > 0 then is_done = false end
            end

            if is_done then
                table.insert(to_remove, batch_i)
            end
        end

        batch.data_mesh:replace_data(batch.data_mesh_data)
    end

    if #to_remove > 0 then
        table.sort(to_remove, function(a, b) return a > b end)
        for batch_i in values(to_remove) do
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