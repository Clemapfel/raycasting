
local _settings_n_sub_steps = 4
local _settings_n_constraint_iterations = 4

local _settings_distance_compliance = 2e-6
local _settings_volume_compliance = 1e-7
local _settings_line_compliance = 0
local _settings_bending_compliance = 1e-5
local _settings_angular_compliance = 0
local _settings_particle_collision_compliance = 0

local _settings_damping = 0.9998
local _settings_gravity = 5000

local _settings_texture_zoom = 1 / 1.25
local _settings_texture_path = "jam/assets/barboach.png"
local _settings_draw_line_width = 3

local _x_offset = 0
local _y_offset = 1
local _previous_x_offset = 2
local _previous_y_offset = 3
local _draw_x_offset = 4
local _draw_y_offset = 5
local _velocity_x_offset = 6
local _velocity_y_offset = 7
local _radius_offset = 8
local _mass_offset = 9
local _inverse_mass_offset = 10
local _distance_lambda_offset = 11
local _bending_lambda_offset = 12
local _polygon_lambda_offset = 13

local _stride = _polygon_lambda_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1
end

--- @class Boob
Boob_t = "boob"

boob_new = function()
    return object_new(Boob_t, {
        is_initialized = false
    })
end

boob_init = function(self, center_x, center_y, radius, n_contour_nodes)
    log_typecheck(
        self, Boob_t,
        center_x, Float_t,
        center_y, Float_t,
        radius, Float_t,
        n_contour_nodes, Integer_t
    )

    local cos, sin, tau = math_cos, math_sin, math_tau

    -- particles
    log_assert(n_contour_nodes >= 5, "In boob_init: need at least 5 contour nodes")

    local n_particles = 0
    local data = {}

    for particle_i = 1, n_contour_nodes do
        local angle = (particle_i - 1) / n_contour_nodes * tau
        local px = center_x + radius * cos(angle)
        local py = center_y + radius * sin(angle)
        local mass = 1

        local base = _particle_i_to_data_offset(particle_i)
        n_particles = n_particles + 1

        data[base + _x_offset] = px
        data[base + _y_offset] = py
        data[base + _previous_x_offset] = px
        data[base + _previous_y_offset] = py
        data[base + _draw_x_offset] = px
        data[base + _draw_y_offset] = py
        data[base + _velocity_x_offset] = 0
        data[base + _velocity_y_offset] = 0
        data[base + _radius_offset] = 1
        data[base + _mass_offset] = mass
        data[base + _inverse_mass_offset] = 1 / mass
        data[base + _distance_lambda_offset] = 0
        data[base + _bending_lambda_offset] = 0
        data[base + _polygon_lambda_offset] = 0

        log_assert(#data == n_particles * _stride)
    end

    local wrap, cross = math_wrap, math_cross

    -- volume
    local area = 0
    for particle_i = 1, n_particles do
        local ai = _particle_i_to_data_offset(wrap(particle_i, n_particles))
        local bi = _particle_i_to_data_offset(wrap(particle_i + 1, n_particles))
        local ax, ay = data[ai + _x_offset], data[ai + _y_offset]
        local bx, by = data[bi + _x_offset], data[bi + _y_offset]
        area = area + 0.5 * cross(ax, ay, bx, by)
    end

    local segment_length = 2 * radius * sin(math.pi / n_particles)
    local rest_area = area

    -- drawing
    local mesh_data = {}
    local draw_contour = {}
    local zoom = _settings_texture_zoom

    for particle_i = 1, n_particles do
        local a_particle_i = particle_i
        local b_particle_i = particle_i % n_particles + 1

        local angle_a = (a_particle_i - 1) / n_particles * tau
        local angle_b = (b_particle_i - 1) / n_particles * tau
        local u_a = 0.5 + 0.5 * zoom * cos(angle_a)
        local v_a = 0.5 + 0.5 * zoom * sin(angle_a)
        local u_b = 0.5 + 0.5 * zoom * cos(angle_b)
        local v_b = 0.5 + 0.5 * zoom * sin(angle_b)

        local ai = _particle_i_to_data_offset(a_particle_i)
        local bi = _particle_i_to_data_offset(b_particle_i)
        local ax, ay = data[ai + _x_offset], data[ai + _y_offset]
        local bx, by = data[bi + _x_offset], data[bi + _y_offset]

        table.insert(mesh_data, { center_x, center_y, 0.5, 0.5, 1, 1, 1, 1 })
        table.insert(mesh_data, { ax, ay, u_a, v_a, 1, 1, 1, 1 })
        table.insert(mesh_data, { bx, by, u_b, v_b, 1, 1, 1, 1 })

        table.insert(draw_contour, ax)
        table.insert(draw_contour, ay)
    end

    local mesh = love.graphics.newMesh(mesh_data, "triangles", "stream")
    local mesh_texture = love.graphics.newImage(_settings_texture_path)

    self.particles = data
    self.n_particles = n_particles

    self.volume = rest_area
    self.volume_lambda = 0
    self.segment_length = segment_length

    self.mesh = mesh
    self.mesh_data = mesh_data
    self.mesh_texture = mesh_texture
    self.draw_contour = draw_contour

    self.is_initialized = true

    return self
end

boob_is_initialized = function(self)
    return object_isa(self, Boob_t) and self.is_initialized == true
end

boob_draw = function(self)
    log_typecheck(self, Boob_t)

    if boob_is_initialized(self) ~= true then
        log_warning("In boob_draw: trying to draw instance before `boob_init` was called")
        return
    end

    graphics_push_state()

    graphics_set_color(1, 1, 1, 1)
    graphics_set_line_state(_settings_draw_line_width)
    graphics_draw_mesh(self.mesh)
    graphics_draw_line(self.draw_contour)

    graphics_pop_state()
end

boob_update = function(self)
    log_typecheck(self, Boob_t)
end

