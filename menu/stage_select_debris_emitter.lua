require "common.random"

local max_velocity = 1000
rt.settings.menu.stage_select_debris_emitter = {
    spawn_frequency = 5, -- particles per seconds
    min_radius = 5,
    max_radius = 12,
    min_velocity = 0.1 * max_velocity, -- px / s
    max_velocity = 1 * max_velocity,
    min_angular_velocity = 0.2 * 2 * math.pi,
    max_angular_velocity = 0.4 * 2 * math.pi,
    max_n_particles = math.huge,
    max_angle_perturbation = 0.01 * math.pi,
    trail_max_scale = 3,
    collision_duration = 0.2, -- seconds
    draw_trails = true,
    player_collision_radius_threshold = 0.5 -- fraction
}

--- @class mn.StageSelectDebrisEmitter
--- @signal collisiong (mn.StageSelectDebrisEmitter, position_x, position_y) -> nil
mn.StageSelectDebrisEmitter = meta.class("StageSelectDebrisEmitter", rt.Widget)
meta.add_signals(mn.StageSelectDebrisEmitter, "collision")

local _trail_texture = nil

--- @brief
function mn.StageSelectDebrisEmitter:instantiate()
    if _trail_texture == nil then
        -- generate particle texture, only needs to happen once
        _trail_texture = rt.RenderTexture(rt.settings.menu.stage_select_debris_emitter.max_radius * 2, 100)

        local shader = rt.Shader("menu/stage_select_debris_emitter_trail.glsl")
        love.graphics.push()
        love.graphics.origin()
        _trail_texture:bind()
        shader:bind()
        love.graphics.rectangle("fill", 0, 0, _trail_texture:get_size())
        shader:unbind()
        _trail_texture:unbind()
        love.graphics.pop()
    end

    self._spawn_elapsed = 0
    self._speedup = 1
    self._next_spawn = 0
    self._hitbox_x, self._hitbox_y, self._hitbox_radius = math.huge, math.huge, 0
    self._particles = {}
    self._collision = {}
    self._bounds = rt.AABB(0, 0, love.graphics.getDimensions())
    self._offset_x, self._offset_y = 0, 0
end

--- @brief
function mn.StageSelectDebrisEmitter:size_allocate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)
end

local _shapes = {
    [6] = { -- octagon
        vertices = {
            [1] = { math.pi / 2, 0 },               -- Top vertex
            [2] = { math.pi / 2, math.pi / 2 },     -- Right vertex
            [3] = { math.pi / 2, math.pi },         -- Bottom vertex
            [4] = { math.pi / 2, 3 * math.pi / 2 }, -- Left vertex
            [5] = { 0, 0 },                         -- North pole
            [6] = { math.pi, 0 }                    -- South pole
        },

        edges = {
            { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, -- Equatorial edges
            { 5, 1 }, { 5, 2 }, { 5, 3 }, { 5, 4 }, -- Edges connecting to the North pole
            { 6, 1 }, { 6, 2 }, { 6, 3 }, { 6, 4 }  -- Edges connecting to the South pole
        }
    },

    [4] = { -- tetrahedron
        vertices = {
            { math.acos(1 / math.sqrt(3)), 0 },                  -- Vertex 1
            { math.acos(1 / math.sqrt(3)), 2 * math.pi / 3 },    -- Vertex 2
            { math.acos(1 / math.sqrt(3)), 4 * math.pi / 3 },    -- Vertex 3
            { math.pi, 0 }                                       -- Vertex 4 (South pole)
        },

        edges = {
            { 1, 2 }, { 2, 3 }, { 3, 1 }, -- Base edges
            { 1, 4 }, { 2, 4 }, { 3, 4 }  -- Edges connecting to the apex
        }
    },

    [8] = { -- cube
        vertices = {
            { math.acos(1 / math.sqrt(3)), math.pi / 4 },
            { math.acos(1 / math.sqrt(3)), 3 * math.pi / 4 },
            { math.acos(1 / math.sqrt(3)), 5 * math.pi / 4 },
            { math.acos(1 / math.sqrt(3)), 7 * math.pi / 4 },
            { math.pi - math.acos(1 / math.sqrt(3)), math.pi / 4 },
            { math.pi - math.acos(1 / math.sqrt(3)), 3 * math.pi / 4 },
            { math.pi - math.acos(1 / math.sqrt(3)), 5 * math.pi / 4 },
            { math.pi - math.acos(1 / math.sqrt(3)), 7 * math.pi / 4 }
        },

        edges = {
            { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, -- Top face edges
            { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 }, -- Bottom face edges
            { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 }  -- Vertical edges
        }
    }
}

local _hue_step, _n_hue_steps = 0, 13

local _new_particle = function(particle_x, particle_y)
    local shape = _shapes[rt.random.choose(4, 6)]

    local hue = (_hue_step % _n_hue_steps) / _n_hue_steps
    _hue_step = _hue_step + 1

    local radius = rt.random.number(0, 1)
    local particle = {
        x = particle_x,
        y = particle_y,
        last_x = particle_x,
        last_y = particle_y,

        velocity = rt.random.number(0, 1),
        angular_velocity = rt.random.number(0, 1) * (rt.random.toss_coin() and 1 or -1),
        rotation = 0,
        radius = radius,
        angles = {},
        edges = shape.edges,
        color = { rt.lcha_to_rgba(0.8, 1, hue, 1) },

        -- axis of rotation
        axis_x = rt.random.number(-1, 1),
        axis_y = rt.random.number(-1, 1),
        axis_z = rt.random.number(-1, 1),

        trail_scale_x = 0,
        trail_scale_y = 0
    }

    particle.axis_x, particle.axis_y, particle.axis_z = math.normalize3(particle.axis_x, particle.axis_y, particle.axis_z)
    local perturbation = rt.settings.menu.stage_select_debris_emitter.max_angle_perturbation

    for i = 1, #shape.vertices do
        local phi, theta = shape.vertices[i][1], shape.vertices[i][2]

        phi = phi + rt.random.number(-perturbation, perturbation)
        theta = theta + rt.random.number(-perturbation, perturbation)

        phi = math.clamp(phi, 0, math.pi)
        theta = theta % (2 * math.pi)

        table.insert(particle.angles, phi)
        table.insert(particle.angles, theta)
    end

    return particle
end

local function _rotate_around_axis_3d(x, y, z, angle, ux, uy, uz)
    local cos_angle = math.cos(angle)
    local sin_angle = math.sin(angle)

    local new_x = (cos_angle + ux^2 * (1 - cos_angle)) * x +
        (ux * uy * (1 - cos_angle) - uz * sin_angle) * y +
        (ux * uz * (1 - cos_angle) + uy * sin_angle) * z

    local new_y = (uy * ux * (1 - cos_angle) + uz * sin_angle) * x +
        (cos_angle + uy^2 * (1 - cos_angle)) * y +
        (uy * uz * (1 - cos_angle) - ux * sin_angle) * z

    local new_z = (uz * ux * (1 - cos_angle) - uy * sin_angle) * x +
        (uz * uy * (1 - cos_angle) + ux * sin_angle) * y +
        (cos_angle + uz^2 * (1 - cos_angle)) * z

    return new_x, new_y, new_z
end

function _rectangle_circle_overlap(rx, ry, rw, rh, cx, cy, crx)
    local closest_x = math.max(rx - rw, math.min(cx, rx + rw))
    local closest_y = math.max(ry - rh, math.min(cy, ry + rh))

    local dx = (closest_x - cx) / crx
    local dy = (closest_y - cy) / crx

    return (dx * dx + dy * dy) <= 1
end

local _n_particles = 0

function mn.StageSelectDebrisEmitter:update(delta)
    self._update_needed = true
    local settings = rt.settings.menu.stage_select_debris_emitter

    local min_velocity, max_velocity = settings.min_velocity, settings.max_velocity
    local min_angular_velocity, max_angular_velocity = settings.min_angular_velocity, settings.max_angular_velocity
    local min_radius, max_radius = settings.min_radius, settings.max_radius
    local trail_w, trail_h = _trail_texture:get_size()

    -- collision animations
    for collision in values(self._collision) do
        collision.elapsed = collision.elapsed + delta
    end

    -- spawn new particles
    self._spawn_elapsed = self._spawn_elapsed + delta
    local effective_speedup = math.max(self._speedup or 1, 0.0001) -- avoid division by zero
    while self._spawn_elapsed >= self._next_spawn and _n_particles < settings.max_n_particles do
        table.insert(self._particles, _new_particle(
            rt.random.number(
                self._bounds.x + max_radius - self._offset_x,
                self._bounds.x + self._bounds.width - max_radius - self._offset_x
            ),
            self._bounds.y + self._bounds.height + 2 * max_radius - self._offset_y
        ))

        _n_particles = _n_particles + 1
        self._spawn_elapsed = self._spawn_elapsed - self._next_spawn
        -- Adjust spawn interval according to speedup: higher speedup = shorter interval
        self._next_spawn = rt.random.number(0, 1 / (settings.spawn_frequency * effective_speedup))
    end

    local to_despawn = {}
    for particle_i = 1, #self._particles do
        local particle = self._particles[particle_i]
        particle.last_x, particle.last_y = particle.x, particle.y

        local velocity = math.mix(min_velocity, max_velocity, particle.velocity) * self._speedup
        particle.y = particle.y - delta * velocity
        particle.rotation = particle.rotation + delta * math.mix(
            min_angular_velocity,
            max_angular_velocity,
            math.abs(particle.angular_velocity)
        ) * self._speedup

        -- despawn if particle leaves screen
        if particle.y < self._bounds.y - self._offset_y - 2 * max_radius - particle.trail_scale_y * trail_h or
            particle.x < self._bounds.x - self._offset_x - 2 * max_radius or
            particle.x > self._bounds.x + self._bounds.width - self._offset_x + 2 * max_radius
        then
            table.insert(to_despawn, particle_i)
        end

        -- despawn if in foreground and when colliding with player
        if particle.radius > rt.settings.menu.stage_select_debris_emitter.player_collision_radius_threshold
            and _rectangle_circle_overlap(
            self._hitbox_x - self._offset_x, self._hitbox_y - self._offset_y - 0.5 - self._hitbox_radius, 2 * self._hitbox_radius, 0.25 * self._hitbox_radius,
            particle.x, particle.y, math.mix(min_radius, max_radius, particle.radius)
        ) then
            table.insert(to_despawn, particle_i)
            table.insert(self._collision, {
                x = particle.x,
                y = particle.y,
                elapsed = 0,
                radius = math.mix(min_radius, max_radius, particle.radius) * 2,
                color = table.deepcopy(particle.color) -- because particle may be freed
            })
            self:signal_emit("collision", particle.x, particle.y)
        end

        local points = {}

        for angle_i = 1, #particle.angles, 2 do
            local phi = particle.angles[angle_i + 0]
            local theta = particle.angles[angle_i + 1]

            local x = math.sin(phi) * math.cos(theta)
            local y = math.sin(phi) * math.sin(theta)
            local z = math.cos(phi)

            x, y, z = _rotate_around_axis_3d(x, y, z, particle.rotation, particle.axis_x, particle.axis_y, particle.axis_z)
            table.insert(points, { x, y, z })
        end

        particle.to_draw = {}
        local radius = math.mix(min_radius, max_radius, particle.radius) * rt.get_pixel_scale()
        for i = 1, #particle.edges do
            local edge = particle.edges[i]
            local a = points[edge[1]]
            local b = points[edge[2]]

            table.insert(particle.to_draw, particle.x + a[1] * radius)
            table.insert(particle.to_draw, particle.y + a[2] * radius)
            table.insert(particle.to_draw, particle.x + b[1] * radius)
            table.insert(particle.to_draw, particle.y + b[2] * radius)
        end

        particle.trail_scale_x = radius / trail_w * 0.5

        local scale_fraction = math.clamp(math.abs(velocity) / max_velocity, 0, 1)
        scale_fraction = rt.InterpolationFunctions.SQUARE_ACCELERATION(scale_fraction)
        if scale_fraction < 0.05 then scale_fraction = 0 end
        particle.trail_scale_y = scale_fraction * settings.trail_max_scale
    end

    if #to_despawn > 0 then
        table.sort(to_despawn, function(a, b) return a > b end)
        for i = 1, #to_despawn do
            table.remove(self._particles, to_despawn[i])
            _n_particles = _n_particles - 1
        end
    end
end

function mn.StageSelectDebrisEmitter:draw_below_player()
    local interpolation = rt.SceneManager:get_frame_interpolation()

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1.5 * rt.get_pixel_scale())
    love.graphics.setLineJoin("none")

    love.graphics.setBlendMode("add", "premultiplied")

    if rt.settings.menu.stage_select_debris_emitter.draw_trails then
        local w, h = _trail_texture:get_size()
        local trail_a = 0.5
        for particle in values(self._particles) do
            local r, g, b, a = table.unpack(particle.color)
            love.graphics.setColor(
                r * trail_a,
                g * trail_a,
                b * trail_a,
                trail_a
            )

            -- Interpolated position
            local interp_x = math.mix(particle.last_x, particle.x, interpolation)
            local interp_y = math.mix(particle.last_y, particle.y, interpolation)

            love.graphics.draw(
                _trail_texture:get_native(),
                interp_x - 0.5 * w * particle.trail_scale_x,
                interp_y,
                0,
                particle.trail_scale_x,
                particle.trail_scale_y
            )
        end
    end

    love.graphics.setBlendMode("alpha")

    for particle in values(self._particles) do
        love.graphics.setColor(particle.color)
        -- Interpolate all points in to_draw
        local interp_points = {}
        for i = 1, #particle.to_draw, 4 do
            local ax = particle.to_draw[i]
            local ay = particle.to_draw[i + 1]
            local bx = particle.to_draw[i + 2]
            local by = particle.to_draw[i + 3]

            -- Offset relative to particle.x/y, so interpolate the center and add the offsets
            local interp_cx = math.mix(particle.last_x, particle.x, interpolation)
            local interp_cy = math.mix(particle.last_y, particle.y, interpolation)
            local offset_ax = ax - particle.x
            local offset_ay = ay - particle.y
            local offset_bx = bx - particle.x
            local offset_by = by - particle.y

            table.insert(interp_points, interp_cx + offset_ax)
            table.insert(interp_points, interp_cy + offset_ay)
            table.insert(interp_points, interp_cx + offset_bx)
            table.insert(interp_points, interp_cy + offset_by)
        end
        love.graphics.line(interp_points)
    end

    love.graphics.pop()
end

--- @brief
function mn.StageSelectDebrisEmitter:draw_above_player()
    -- disabled explosions
    --[[
    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)
    local time = rt.settings.menu.stage_select_debris_emitter.collision_duration
    for collision in values(self._collision) do
        local t = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT(math.min(collision.elapsed / time, 1))
        local r, g, b, a = table.unpack(collision.color)
        love.graphics.setColor(r, g, b, 1 - t)
        love.graphics.circle("fill", collision.x, collision.y, collision.radius)
    end
    love.graphics.pop()
    ]]--
end

--- @brief
function mn.StageSelectDebrisEmitter:set_player_position(x, y)
    love.graphics.push()
    self._hitbox_x, self._hitbox_y = x, y
    self._hitbox_radius = rt.settings.player.radius * rt.get_pixel_scale()
    love.graphics.pop()
end

--- @brief
function mn.StageSelectDebrisEmitter:reset()
    _n_particles = _n_particles - table.sizeof(self._particles)
    self._particles = {}
    self._collision = {}
end

--- @brief
function mn.StageSelectDebrisEmitter:set_offset(x, y)
    if math.distance(x, y, self._offset_x, self._offset_y) > 2 * rt.settings.menu.stage_select_debris_emitter.max_radius then
        self._spawn_spawn_elapsed = 0
    end
    self._offset_x, self._offset_y = x, y
end

--- @brief
function mn.StageSelectDebrisEmitter:set_speedup(fraction)
    self._speedup = fraction
end