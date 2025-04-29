rt.settings.overworld.checkpoint = {
    max_spawn_duration = 5,
    celebration_duration = 2,
    celebration_particles_n = 500,
    celebration_particles_radius_factor = 1, -- time player radius
}

--- @class ow.Checkpoint 
ow.Checkpoint = meta.class("Checkpoint")

--- @class ow.CheckpointBody
ow.CheckpointBody = meta.class("CheckpointBody") -- dummy for `body` property

--- @class ow.PlayerSpawn
ow.PlayerSpawn = function(object, stage, scene) -- alias for first checkpoint
    return ow.Checkpoint(object, stage, scene, true)
end

local _mesh, _mesh_fill, _mesh_h = nil, nil, nil

--- @brief
function ow.Checkpoint:instantiate(object, stage, scene, is_player_spawn)
    meta.install(self, {
        _scene = scene,
        _stage = stage,
        _is_player_spawn = is_player_spawn or false,

        _x = object.x,
        _y = object.y,

        _top_x = math.huge,
        _top_y = math.huge,
        _bottom_x = math.huge,
        _bottom_y = math.huge,

        _mesh_position_y = math.huge,
        _mesh_visible = false,
        _passed = false,

        _color = { rt.Palette.CHECKPOINT:unpack() },

        _celebration_elapsed = math.huge,
        _celebration_active = false,
        _celebration_n_particles = 0,
        _celebration_particles = {}
    })

    if _mesh == nil then
        _mesh_h = rt.settings.overworld.player.radius - 2
        _mesh = {}
        for angle = 0, 2 * math.pi, 2 * math.pi / 32 do
            table.insert(_mesh, 0 + math.cos(angle) * _mesh_h)
            table.insert(_mesh, 0 + math.sin(angle) * _mesh_h)
        end

        _mesh_fill = rt.MeshCircle(0, 0, _mesh_h)
        _mesh_fill:set_vertex_color(1, 0, 0, 0, 1)
        local outer = 0.65
        for i = 2, _mesh_fill:get_n_vertices() do
            _mesh_fill:set_vertex_color(i, outer, outer, outer, 1)
        end
        _mesh_fill = _mesh_fill:get_native()
    end

    stage:add_checkpoint(self, object.id, is_player_spawn)

    stage:signal_connect("initialized", function()
        local world = stage:get_physics_world()

        local inf = 10e9
        local bottom_x, bottom_y, nx, ny, body = world:query_ray(self._x, self._y, 0, inf)
        if bottom_x == nil then -- no ground
            rt.warning("In ow.Checkpoint: checkpoint `" .. object.id .. "` is not above solid ground")

            bottom_x = self._x
            bottom_y = self._y
        end

        local top_x, top_y, nx, ny, body = world:query_ray(self._x, self._y, 0, -inf)
        if top_x == nil then
            top_x = self._x
            top_y = self._y - inf
        end

        self._bottom_x, self._bottom_y = bottom_x, bottom_y
        self._top_x, self._top_y = top_x, top_y

        self._body = b2.Body(self._stage:get_physics_world(), b2.BodyType.STATIC,
            self._x, self._y,
            b2.Segment(
                top_x - self._x, top_y - self._y,
                bottom_x - self._x, bottom_y - self._y
            )
        )

        self._body:set_collides_with(rt.settings.overworld.player.player_collision_group)
        self._body:set_use_continuous_collision(true)
        self._body:set_is_sensor(true)
        self._body:signal_connect("collision_start", function()
            if self._passed == false then
                self:pass()
            end
        end)

        return meta.DISCONNECT_SIGNAL
    end)
end

local _MODE_ASCEND = 0
local _MODE_EXPLODE = 1

--- @brief
function ow.Checkpoint:pass()
    local player = self._scene:get_player()
    local player_x, player_y = player:get_position()

    local hue = player:get_hue()
    self._color = { rt.lcha_to_rgba(0.8, 1, hue, 1) }

    self._celebration_active = true
    self._celebration_elapsed = 0
    self._celebration_particles = {}
    self._celebration_n_particles = rt.settings.overworld.checkpoint.celebration_particles_n

    local goal_x = player_x + 30
    local goal_y = player_y - 100
    local n_particles_per_group = self._celebration_n_particles
    local perturbation = 0.5
    local hue_offset = 0.2
    local _rng = rt.random.number
    local golden_ratio = (1 + math.sqrt(5)) / 2

    local radius = rt.settings.overworld.checkpoint.celebration_particles_radius_factor * player:get_radius()

    for i = 1, n_particles_per_group do
        -- fibonacci lattice to generate random points on sphere
        local idx = i - 0.5 - 1
        local z = 1 - 2 * idx / n_particles_per_group
        local theta = 2 * math.pi * idx / golden_ratio

        local r = math.sqrt(1 - z * z)
        local x = r * math.cos(theta)
        local y = r * math.sin(theta)

        if perturbation > 0 then
            local angle = _rng(0, 2 * math.pi)
            local offset = _rng(0, perturbation)
            x = x + offset * math.cos(angle)
            y = y + offset * math.sin(angle)
            z = z + offset * math.sin(angle)
            local norm = math.sqrt(x * x + y * y + z * z)
            x, y, z = x / norm, y / norm, z / norm
        end

        local fraction = 0.7
        x, y, z = math.normalize3(x, y, z)

        local bias_x, bias_y = math.normalize(player:get_velocity())
        local bias_strength = 0.4

        local to_push = {
            position_x = player_x,
            position_y = player_y,
            position_z = 0,
            color = { rt.lcha_to_rgba(0.8, 1, _rng(hue - hue_offset, hue + hue_offset), 1) },
            velocity_x = 0,
            velocity_y = 0,
            velocity_z = 0,
            direction_x = math.mix(x, bias_x, bias_strength),
            direction_y = math.mix(y, bias_y, bias_strength),
            direction_z = z,
            direction_magnitude = radius,
            mass = _rng(0, 1),
            radius = _rng(2, 6),
        }

        table.insert(self._celebration_particles, to_push)
    end

    self._passed = true
end

--- @brief
function ow.Checkpoint:update(delta)
    if not self._passed then
        local player = self._scene:get_player()
        local player_x, player_y = player:get_position()
        self._mesh_position_y = player_y
        self._mesh_out_of_bounds = player_y < self._top_y + _mesh_h or player_y > self._bottom_y - _mesh_h
    end

    if self._celebration_active then
        local duration = rt.settings.overworld.checkpoint.celebration_duration
        local fraction = self._celebration_elapsed / duration
        local fade_out_duration = 0.1
        local gravity_per_second = 1000
        local gravity_x = 0
        local gravity_y = gravity_per_second * duration
        local gravity_z = -1 * gravity_per_second * duration

        for particle in values(self._celebration_particles) do
            local dx, dy, dz = particle.direction_x, particle.direction_y, particle.direction_z -- already normalized
            local vx, vy, vz = math.normalize3(particle.velocity_x, particle.velocity_y, particle.velocity_z)
            local alignment = math.abs(math.dot3(dx, dy, dz, vx, vy, vz))

            particle.velocity_x = particle.velocity_x + particle.direction_x * particle.direction_magnitude * particle.mass + delta * gravity_x * alignment * particle.mass * fraction
            particle.velocity_y = particle.velocity_y + particle.direction_y * particle.direction_magnitude * particle.mass + delta * gravity_y * alignment * particle.mass * fraction
            particle.velocity_z = particle.velocity_z + particle.direction_z * particle.direction_magnitude * particle.mass + delta * gravity_z * alignment * particle.mass * fraction

            particle.position_x = particle.position_x + particle.velocity_x * delta
            particle.position_y = particle.position_y + particle.velocity_y * delta
            particle.position_z = particle.position_z + particle.velocity_z * delta

            if fraction > 1 - fade_out_duration then
                particle.color[4] = 1 - (fraction - (1 - fade_out_duration)) / fade_out_duration
            end
        end

        self._celebration_elapsed = self._celebration_elapsed + delta
        if self._celebration_elapsed >  rt.settings.overworld.checkpoint.celebration_duration then
            self._celebration_active = false
            self._passed = false -- TODO
        end
    end

    if self._waiting_for_player then
        self._spawn_duration_elapsed = self._spawn_duration_elapsed + delta

        local player = self._scene:get_player()
        local player_x, player_y = player:get_position()

        -- spawn animation: once player reached location, unfreeze, with timer as failsafe
        if player_y >= (self._bottom_y - player:get_radius()) or self._spawn_duration_elapsed > rt.settings.overworld.checkpoint.max_spawn_duration then
            player:enable()
            player:set_trail_visible(true)
            self._scene:set_camera_mode(ow.CameraMode.AUTO)
            self._waiting_for_player = false
        end
    end
end

--- @brief
function ow.Checkpoint:spawn()
    self._scene:set_camera_mode(ow.CameraMode.MANUAL)

    if self._is_player_spawn == true then
        self._scene:get_camera():set_position(self._bottom_y, self._bottom_y) -- smash cut on spawn
    end

    local player = self._scene:get_player()
    player:disable()
    local vx, vy = player:get_velocity()
    player:set_velocity(0, rt.settings.overworld.player.air_target_velocity_x)
    player:set_trail_visible(false)
    player:teleport_to(self._x, self._y)
    self._waiting_for_player = true
    self._spawn_duration_elapsed = 0

    self._scene:get_camera():move_to(self._bottom_y, self._bottom_y - player:get_radius()) -- jump cut at start of level
    self._stage:set_active_checkpoint(self)
    player:signal_emit("respawn")
end

--- @brief
function ow.Checkpoint:draw()
    if self._scene:get_is_body_visible(self._body) then
        local mesh_x = self._top_x
        local mesh_y = self._mesh_position_y
        local stencil = rt.graphics.get_stencil_value()

        if self._mesh_out_of_bounds then
            rt.graphics.stencil(stencil, function()
                local inf = love.graphics.getWidth()

                love.graphics.rectangle("fill", self._bottom_x - inf, self._bottom_y, 2 * inf, inf)
                love.graphics.rectangle("fill", self._top_x - inf, self._top_y - inf, 2 * inf, inf)
            end)
            rt.graphics.set_stencil_test(rt.StencilCompareMode.NOT_EQUAL, stencil)
        end

        love.graphics.setColor(table.unpack(self._color))
        love.graphics.setLineWidth(2)
        love.graphics.line(self._top_x, self._top_y, self._bottom_x, self._bottom_y)

        love.graphics.push()
        love.graphics.translate(mesh_x, mesh_y)

        love.graphics.draw(_mesh_fill)
        love.graphics.polygon("line", _mesh)

        rt.graphics.set_stencil_test(nil)
        love.graphics.pop()
    end

    if self._celebration_active then
        local particle_opacity = 1
        for particle in values(self._celebration_particles) do
            local r, g, b, a = table.unpack(particle.color)
            love.graphics.setColor(r, g, b, a * particle_opacity)
            love.graphics.circle("fill", particle.position_x, particle.position_y, particle.radius)
        end
    end
end

--- @brief
function ow.Checkpoint:get_render_priority()
    return -math.huge
end