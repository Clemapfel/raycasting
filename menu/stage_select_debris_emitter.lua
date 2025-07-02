require "common.random"

rt.settings.menu.stage_select_debris_emitter = {
    spawn_frequency = 1, -- particles per seconds
    min_radius = 10,
    max_radius = 20,
    min_velocity = 40, -- px / s
    max_velocity = 100,
    min_angular_velocity = 0.2 * 2 * math.pi,
    max_angular_velocity = 0.4 * 2 * math.pi,
    max_n_particles = 100,
}

--- @class mn.StageSelectDebrisEmitter
mn.StageSelectDebrisEmitter = meta.class("StageSelectDebrisEmitter", rt.Widget)

--- @brief
function mn.StageSelectDebrisEmitter:instantiate()
    self._elapsed = 0
    self._next_spawn = 0
    self._particles = {}
    self._bounds = rt.AABB(0, 0, love.graphics.getDimensions())
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
            { math.acos(1 / math.sqrt(3)), math.pi / 4 },        -- Vertex 1
            { math.acos(1 / math.sqrt(3)), 3 * math.pi / 4 },    -- Vertex 2
            { math.acos(1 / math.sqrt(3)), 5 * math.pi / 4 },    -- Vertex 3
            { math.acos(1 / math.sqrt(3)), 7 * math.pi / 4 },    -- Vertex 4
            { math.pi - math.acos(1 / math.sqrt(3)), math.pi / 4 },  -- Vertex 5
            { math.pi - math.acos(1 / math.sqrt(3)), 3 * math.pi / 4 }, -- Vertex 6
            { math.pi - math.acos(1 / math.sqrt(3)), 5 * math.pi / 4 }, -- Vertex 7
            { math.pi - math.acos(1 / math.sqrt(3)), 7 * math.pi / 4 }  -- Vertex 8
        },

        edges = {
            { 1, 2 }, { 2, 3 }, { 3, 4 }, { 4, 1 }, -- Top face edges
            { 5, 6 }, { 6, 7 }, { 7, 8 }, { 8, 5 }, -- Bottom face edges
            { 1, 5 }, { 2, 6 }, { 3, 7 }, { 4, 8 }  -- Vertical edges
        }
    }
}

local _new_particle = function(particle_x, particle_y)
    local shape = _shapes[rt.random.choose({ 4, 6, 8 })]

    local particle = {
        x = particle_x,
        y = particle_y,
        velocity = rt.random.number(0, 1),
        angular_velocity = rt.random.number(0, 1) * (rt.random.toss_coin() and 1 or -1),
        rotation = 0,
        radius = rt.random.number(0, 1),
        angles = {},
        edges = shape.edges,
        points = {},
        to_draw = nil,

        -- axis of rotation
        axis_x = rt.random.number(-1, 1),
        axis_y = rt.random.number(-1, 1),
        axis_z = rt.random.number(-1, 1)
    }

    particle.axis_x, particle.axis_y, particle.axis_z = math.normalize3(particle.axis_x, particle.axis_y, particle.axis_z)
    local perturbation = 0.0 * math.pi

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

local _n_particles = 0

function mn.StageSelectDebrisEmitter:update(delta)
    local settings = rt.settings.menu.stage_select_debris_emitter

    local min_velocity, max_velocity = settings.min_velocity, settings.max_velocity
    local min_angular_velocity, max_angular_velocity = settings.min_angular_velocity, settings.max_angular_velocity
    local min_radius, max_radius = settings.min_radius, settings.max_radius

    -- spawn new particles
    self._elapsed = self._elapsed + delta
    if self._elapsed >= self._next_spawn and _n_particles < settings.max_n_particles then
        table.insert(self._particles, _new_particle(
            rt.random.number(self._bounds.x + max_radius, self._bounds.x + self._bounds.width - max_radius),
            self._bounds.y + self._bounds.height + 2 * max_radius
        ))

        _n_particles = _n_particles + 1
        self._next_spawn = rt.random.number(0, 1 / settings.spawn_frequency)
        self._elapsed = 0
    end

    local to_despawn = {}
    for particle_i = 1, #self._particles do
        local particle = self._particles[particle_i]

        particle.y = particle.y - delta * math.mix(min_velocity, max_velocity, particle.velocity)
        particle.rotation = particle.rotation + delta * math.mix(
            min_angular_velocity,
            max_angular_velocity,
            math.abs(particle.angular_velocity)
        )

        if particle.y < self._bounds.y - 2 * max_radius then
            table.insert(to_despawn, particle_i)
        end

        local points = {}

        for angle_i = 1, #particle.angles, 2 do
            local phi = particle.angles[angle_i + 0]
            local theta = particle.angles[angle_i + 1]

            local x = math.sin(phi) * math.cos(theta)
            local y = math.sin(phi) * math.sin(theta)
            local z = math.cos(phi)

            x, y, z = _rotate_around_axis_3d(x, y, z, particle.rotation, particle.axis_x, particle.axis_y, particle.axis_z)

            table.insert(points, { x, y }) -- orthographic projection
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
    end

    if #to_despawn > 0 then
        table.sort(to_despawn, function(a, b) return a > b end)
        for i = 1, #to_despawn do
            table.remove(self._particles, to_despawn[i])
            _n_particles = _n_particles - 1
        end
    end
end

function mn.StageSelectDebrisEmitter:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    love.graphics.setLineJoin("none")
    for _, particle in ipairs(self._particles) do
        love.graphics.line(particle.to_draw)
    end
end