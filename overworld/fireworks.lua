rt.settings.overworld.fireworks = {
    radius = 7,
    rocket_initial_speed = 50,
    rocket_acceleration = 300,
    rocket_max_speed = 400,
    particle_air_resistance = 0.98,
    particle_gravity = 10,
    particle_restitution = 0.5,

    min_mass = 0.8,
    max_mass = 1.2,
    min_radius = 0.5,
    max_radius = 1,
    min_lifetime = 1,
    max_lifetime = 2,
    min_explosion_force = 150,
    max_explosion_force = 250
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

function ow.Fireworks:instantiate(scene)
    if _particle_shader == nil then _particle_shader = rt.Shader("overworld/fireworks.glsl") end
    self._batches = {}
    self._scene = scene
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
        -- fibonacci spiral for distribution on 3-sphere
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
        particle_mesh = particle_mesh,
        data_mesh_data = data_mesh_data,
        data_mesh = data_mesh,
        is_exploded = false
    })
end

function ow.Fireworks:update(delta)
    local to_remove = {}
    for batch_i, batch in ipairs(self._batches) do
        if not batch.is_exploded then
            batch.rocket_velocity_x = batch.rocket_velocity_x + batch.rocket_acceleration_x * delta
            batch.rocket_velocity_y = batch.rocket_velocity_y + batch.rocket_acceleration_y * delta

            local current_speed = math.magnitude(batch.rocket_velocity_x, batch.rocket_velocity_y)
            if current_speed > _settings.rocket_max_speed then
                local scale_factor = _settings.rocket_max_speed / current_speed
                batch.rocket_velocity_x = batch.rocket_velocity_x * scale_factor
                batch.rocket_velocity_y = batch.rocket_velocity_y * scale_factor
            end

            batch.rocket_x = batch.rocket_x + batch.rocket_velocity_x * delta
            batch.rocket_y = batch.rocket_y + batch.rocket_velocity_y * delta

            -- get progress of rocket on line segment
            local line_dx = batch.end_x - batch.start_x
            local line_dy = batch.end_y - batch.start_y
            local rocket_dx = batch.rocket_x - batch.start_x
            local rocket_dy = batch.rocket_y - batch.start_y
            if math.dot(rocket_dx, rocket_dy, line_dx, line_dy) / math.magnitude(line_dx, line_dy)^2 >= 1 then
                batch.is_exploded = true
            end

            -- rotated rectangle segment with tapering end
            local left_x, left_y = math.normalize(math.turn_left(rocket_dx, rocket_dy))
            local right_x, right_y = math.normalize(math.turn_right(rocket_dx, rocket_dy))

            local rocket_length = 4 * _settings.radius
            local rocket_end_width = _settings.radius
            local rocket_start_width = rocket_end_width * 0.25

            local ndx, ndy = math.normalize(rocket_dx, rocket_dy)
            local start_x = batch.rocket_x - ndx * rocket_length
            local start_y = batch.rocket_y - ndy * rocket_length
            local end_x = batch.rocket_x
            local end_y = batch.rocket_y

            batch.rocket_vertices = {
                end_x + left_x * rocket_end_width, end_y,
                end_x + right_x * rocket_end_width, end_y,
                start_x + right_x * rocket_start_width, start_y,
                start_x + left_x * rocket_start_width, start_y
            }

            for particle in values(batch.data_mesh_data) do
                particle[_position_x] = batch.rocket_x
                particle[_position_y] = batch.rocket_y

                if batch.is_exploded then
                    particle[_velocity_x] = particle[_explosion_direction_x] * particle[_explosion_force]
                    particle[_velocity_y] = particle[_explosion_direction_y] * particle[_explosion_force]
                    particle[_velocity_z] = particle[_explosion_direction_z] * particle[_explosion_force]
                end
            end
        else
            local air_resistance = _settings.particle_air_resistance
            local gravity = _settings.particle_gravity
            local restitution = _settings.particle_restitution

            local player_x, player_y, player_r
            if self._scene ~= nil then
                player_x, player_y = self._scene:get_player():get_position()
                player_r = self._scene:get_player():get_radius()
            end

            batch.elapsed = batch.elapsed + delta
            local is_done = true

            for particle in values(batch.data_mesh_data) do
                local fraction = batch.elapsed / particle[_lifetime]
                local t = 1 - fraction;
                particle[_color_a] = t
                particle[_radius] = t

                local mass = particle[_mass] * t

                particle[_velocity_x] = particle[_velocity_x] * (air_resistance ^ delta)
                particle[_velocity_y] = particle[_velocity_y] * (air_resistance ^ delta) + gravity * delta * mass
                particle[_velocity_z] = particle[_velocity_z] * (air_resistance ^ delta)

                particle[_position_x] = particle[_position_x] + particle[_velocity_x] * delta
                particle[_position_y] = particle[_position_y] + particle[_velocity_y] * delta
                particle[_position_z] = particle[_position_z] + particle[_velocity_z] * delta

                if self._scene ~= nil then
                    local particle_r =particle[_radius]
                    if math.distance(particle[_position_x], particle[_position_y], player_x, player_y) < (player_r + particle_r) then
                        local delta_x, delta_y = math.normalize(particle[_position_x] - player_x, particle[_position_y] - player_y)
                        particle[_position_x] = player_x + delta_x * (player_r + particle_r)
                        particle[_position_y] = player_y + delta_y * (player_r + particle_r)

                        particle[_velocity_x] = delta_x * math.abs(particle[_velocity_x]) * restitution
                        particle[_velocity_y] = delta_y * math.abs(particle[_velocity_y]) * restitution
                    end
                end

                if fraction < 1 then is_done = false end
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
    love.graphics.setColor(1, 1, 1, 1)

    for batch in values(self._batches) do
        if batch.is_exploded == false then
            love.graphics.circle("fill", batch.rocket_x, batch.rocket_y, _settings.radius)
            love.graphics.polygon("fill", batch.rocket_vertices)
        else
            _particle_shader:bind()
            batch.particle_mesh:draw_instanced(batch.n_particles)
            _particle_shader:unbind()
        end
    end

    love.graphics.setLineWidth(1)
    for batch in values(self._batches) do
        love.graphics.line(batch.start_x, batch.start_y, batch.end_x, batch.end_y)
    end
end