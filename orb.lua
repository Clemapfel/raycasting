local orb = {}

local particle_shader = rt.Shader("overworld/objects/fluid_particle_texture.glsl")

local new_float_array = function(n)
    local out = table.new(n, 0)
    for i = 1, n do
        out[i] = 0
    end

    return setmetatable(out, {
        __index = function(self, i)
            if type(i) == "number" then
                rt.error("In orb: trying to access out-of-range index `", i, "` for array of size `", #self, "`")
            end
            return nil
        end,

        __newindex = function(self, i)
            if type(i) == "number" then
                rt.error("In orb: trying to set out-of-range index `", i, "` for array of size `", #self, "`")
            end
            return nil
        end,
    })
end
local new_int_array = new_float_array

function orb.generate_particle_texture()
    local size_x, size_y = 64, 64

    local texture = rt.RenderTexture(size_x, size_y, rt.RGBA8)
    texture:bind()
    love.graphics.clear(0, 0, 0, 0)
    particle_shader:bind()
    love.graphics.rectangle("fill", 0, 0, size_x, size_y)
    texture:unbind()

    require "common.filesystem"
    local image = texture:download()

    local out_dir = "test"
    bd.mount_path(bd.join_path(bd.get_source_directory(), "website", "game", "public"), out_dir)
    image:save_to(bd.join_path(out_dir, "orb_particle_texture.png"))
    bd.unmount_path(out_dir)

    return texture
end

local _x_offset = 0
local _y_offset = 1
local _previous_x_offset = 2
local _previous_y_offset = 3
local _velocity_x_offset = 4
local _velocity_y_offset = 5
local _radius_offset = 6
local _inverse_mass_offset = 7
local _orb_lambda_offset = 8
local _r_offset = 9
local _g_offset = 10
local _b_offset = 11
local _a_offset = 12

function orb.mass_distribution(t)
    return math.exp(-math.pow((7 / 5) * math.pi * (t - 0.5), 2))
end

function orb.particle_i_to_data_offset(particle_i, stride)
    return (particle_i - 1) * stride + 1
end

function orb.lcha_to_rgba(l, c, h, alpha)
    local L = l * 100
    local a = math.cos(h * 6.283185) * c * 100
    local b = math.sin(h * 6.283185) * c * 100

    local Y = (L + 16) * 0.008620689
    local X = a * 0.002 + Y
    local Z = Y - b * 0.005

    local X3, Y3, Z3 = X * X * X, Y * Y * Y, Z * Z * Z
    X = X3 > 0.008856 and 0.95047 * X3 or 0.95047 * (X - 0.137931) * 0.128419
    Y = Y3 > 0.008856 and Y3 or (Y - 0.137931) * 0.128419
    Z = Z3 > 0.008856 and 1.08883 * Z3 or 1.08883 * (Z - 0.137931) * 0.128419

    local R = X * 3.2406 - Y * 1.5372 - Z * 0.4986
    local G = -X * 0.9689 + Y * 1.8758 + Z * 0.0415
    local B = X * 0.0557 - Y * 0.2040 + Z * 1.0570

    R = R > 0.0031308 and 1.055 * math.pow(R, 0.416666667) - 0.055 or 12.92 * R
    G = G > 0.0031308 and 1.055 * math.pow(G, 0.416666667) - 0.055 or 12.92 * G
    B = B > 0.0031308 and 1.055 * math.pow(B, 0.416666667) - 0.055 or 12.92 * B

    -- Clamp to [0,1]
    return
        R < 0 and 0 or (R > 1 and 1 or R),
        G < 0 and 0 or (G > 1 and 1 or G),
        B < 0 and 0 or (B > 1 and 1 or B),
        alpha
end

function orb.particle_is_to_lambda_i(i1, i2, n_particles)
    return (i1 - 1) * n_particles + i2
end

function orb.mix(lower, upper, ratio)
    return lower * (1 - ratio) + upper * ratio
end

function orb.dot(x1, y1, x2, y2)
    return x1 * x2 + y1 * y2
end

function orb.squared_distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return orb.dot(dx, dy, dx, dy)
end

function orb.magnitude(x, y)
    return math.sqrt(x * x + y * y)
end

function orb.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return orb.magnitude(dx, dy)
end

function orb.normalize(x1, y1)
    local magnitude = orb.magnitude(x1, y1)
    if magnitude < 1e-8 then
        return 0, 0
    else
        return x1 / magnitude, y1 / magnitude
    end
end

function orb.initialize(width, height)
    local this = orb
    this.particle_texture = this.generate_particle_texture()

    -- config
    this.n_particles = 256
    this.damping = 0.95
    this.gravity_dx = 0
    this.gravity_dy = 1
    this.gravity = 8000
    this.n_sub_steps = 4
    this.n_constraint_iterations = 2
    this.collision_compliance = 0.0001
    this.orb_compliance = 0.0001

    this.min_radius = 6
    this.max_radius = 11
    this.min_agitation = 3000
    this.max_agitation = 6000

    this.texture_scale = 2
    this.timestamp = love.timer.getTime()
    
    -- initial allocation
    this.orb_center_x = 0
    this.orb_center_y = 0
    this.orb_radius = 128 + 64

    this.particle_data_stride = _a_offset + 1
    this.particle_data = new_float_array(this.n_particles * this.particle_data_stride)

    local golden_angle = math.pi * (3 - math.sqrt(5))
    for particle_i = 1, this.n_particles do
        local i = this.particle_i_to_data_offset(particle_i, this.particle_data_stride)
        local t = (particle_i - 1) / this.n_particles

        local distance = this.orb_radius * math.sqrt(t)
        local angle = (particle_i - 1) * golden_angle

        local position_x = this.orb_center_x + distance * math.cos(angle)
        local position_y = this.orb_center_y + distance * math.sin(angle)

        local mass_t = this.mass_distribution(t)
        local r, g, b, _ = this.lcha_to_rgba(0.8, 1, t, 1)

        this.particle_data[i + _x_offset] = position_x
        this.particle_data[i + _y_offset] = position_y
        this.particle_data[i + _previous_x_offset] = position_x
        this.particle_data[i + _previous_y_offset] = position_y
        this.particle_data[i + _velocity_x_offset] = 0
        this.particle_data[i + _velocity_y_offset] = 0
        this.particle_data[i + _radius_offset] = orb.mix(this.min_radius, this.max_radius, mass_t)
        this.particle_data[i + _inverse_mass_offset] = 1 / (1 + mass_t)
        this.particle_data[i + _orb_lambda_offset] = 0
        this.particle_data[i + _r_offset] = r
        this.particle_data[i + _g_offset] = g
        this.particle_data[i + _b_offset] = b
        this.particle_data[i + _a_offset] = 1
    end

    this.particle_collision_lambdas = new_float_array(
        this.n_particles * this.n_particles
    )

    this.mesh_vertex_stride = (2 + 2 + 4) -- xy + uv + rgba, in floats
    this.mesh_data_stride = this.mesh_vertex_stride * 4

    this.mesh_data = new_float_array(
        this.n_particles * this.mesh_data_stride
    )

    this.mesh_vertex_map_stride = 6 -- two tris
    this.mesh_vertex_map = new_int_array(
        this.n_particles * this.mesh_vertex_map_stride
    )

    for particle_i = 1, this.n_particles do
        local vertex_data_i = this.particle_i_to_data_offset(
            particle_i,
            this.mesh_vertex_map_stride
        )

        local vertex_base = (particle_i - 1) * 4 -- n vertices per quad
        this.mesh_vertex_map[vertex_data_i + 0] = vertex_base + 0
        this.mesh_vertex_map[vertex_data_i + 1] = vertex_base + 1
        this.mesh_vertex_map[vertex_data_i + 2] = vertex_base + 2
        this.mesh_vertex_map[vertex_data_i + 3] = vertex_base + 0
        this.mesh_vertex_map[vertex_data_i + 4] = vertex_base + 2
        this.mesh_vertex_map[vertex_data_i + 5] = vertex_base + 3
    end

    this.update_mesh_data()
end

function orb.update_mesh_data()
    local this = orb

    local elapsed = love.timer.getTime() - this.timestamp

    for particle_i = 1, this.n_particles do
        local data_i = this.particle_i_to_data_offset(
            particle_i, this.particle_data_stride
        )

        local mesh_data_i = this.particle_i_to_data_offset(
            particle_i, this.mesh_data_stride
        )

        local px = this.particle_data[data_i + _x_offset]
        local py = this.particle_data[data_i + _y_offset]
        local vx = this.particle_data[data_i + _velocity_x_offset]
        local vy = this.particle_data[data_i + _velocity_y_offset]
        local radius = this.particle_data[data_i + _radius_offset] * this.texture_scale
        local r = this.particle_data[data_i + _r_offset]
        local g = this.particle_data[data_i + _g_offset]
        local b = this.particle_data[data_i + _b_offset]
        local a = this.particle_data[data_i + _a_offset]

        px = px + vx * elapsed
        py = py + vy * elapsed

        local top_left_x, top_left_y = px - radius, py - radius
        local top_right_x, top_right_y = px + radius, py - radius
        local bottom_right_x, bottom_right_y = px + radius, py + radius
        local bottom_left_x, bottom_left_y = px - radius, py + radius

        local offset = 0
        this.mesh_data[mesh_data_i + offset + 0] = top_left_x -- x
        this.mesh_data[mesh_data_i + offset + 1] = top_left_y -- y
        this.mesh_data[mesh_data_i + offset + 2] = 0 -- u
        this.mesh_data[mesh_data_i + offset + 3] = 0 -- v
        this.mesh_data[mesh_data_i + offset + 4] = r -- r
        this.mesh_data[mesh_data_i + offset + 5] = g -- g
        this.mesh_data[mesh_data_i + offset + 6] = b -- b
        this.mesh_data[mesh_data_i + offset + 7] = a -- a

        offset = offset + this.mesh_vertex_stride
        this.mesh_data[mesh_data_i + offset + 0] = top_right_x
        this.mesh_data[mesh_data_i + offset + 1] = top_right_y
        this.mesh_data[mesh_data_i + offset + 2] = 1
        this.mesh_data[mesh_data_i + offset + 3] = 0
        this.mesh_data[mesh_data_i + offset + 4] = r
        this.mesh_data[mesh_data_i + offset + 5] = g
        this.mesh_data[mesh_data_i + offset + 6] = b
        this.mesh_data[mesh_data_i + offset + 7] = a

        offset = offset + this.mesh_vertex_stride
        this.mesh_data[mesh_data_i + offset + 0] = bottom_right_x
        this.mesh_data[mesh_data_i + offset + 1] = bottom_right_y
        this.mesh_data[mesh_data_i + offset + 2] = 1
        this.mesh_data[mesh_data_i + offset + 3] = 1
        this.mesh_data[mesh_data_i + offset + 4] = r
        this.mesh_data[mesh_data_i + offset + 5] = g
        this.mesh_data[mesh_data_i + offset + 6] = b
        this.mesh_data[mesh_data_i + offset + 7] = a

        offset = offset + this.mesh_vertex_stride
        this.mesh_data[mesh_data_i + offset + 0] = bottom_left_x
        this.mesh_data[mesh_data_i + offset + 1] = bottom_left_y
        this.mesh_data[mesh_data_i + offset + 2] = 0
        this.mesh_data[mesh_data_i + offset + 3] = 1
        this.mesh_data[mesh_data_i + offset + 4] = r
        this.mesh_data[mesh_data_i + offset + 5] = g
        this.mesh_data[mesh_data_i + offset + 6] = b
        this.mesh_data[mesh_data_i + offset + 7] = a
    end

    -- convert to love compliant format

    local real_mesh_data = {}
    local push = function(mesh_data_i, offset)
        local to_insert = {}
        for i = 0, 7 do
            table.insert(to_insert, this.mesh_data[mesh_data_i + offset + i])
        end
        table.insert(real_mesh_data, to_insert)
    end

    for particle_i = 1, this.n_particles do
        local mesh_data_i = this.particle_i_to_data_offset(
            particle_i, this.mesh_data_stride
        )

        local offset = 0
        push(mesh_data_i, offset)

        offset = offset + this.mesh_vertex_stride
        push(mesh_data_i, offset)

        offset = offset + this.mesh_vertex_stride
        push(mesh_data_i, offset)

        offset = offset + this.mesh_vertex_stride
        push(mesh_data_i, offset)
    end

    local real_mesh_vertex_map = {}
    for i = 1, #this.mesh_vertex_map do
        table.insert(real_mesh_vertex_map, this.mesh_vertex_map[i] + 1) -- 1-based
    end

    this.mesh = rt.Mesh(real_mesh_data, rt.MeshDrawMode.TRIANGLES)
    this.mesh:set_vertex_map(real_mesh_vertex_map)
    this.mesh:set_texture(this.particle_texture)
end

function orb.enforce_distance(
    ax, ay, bx, by,
    inverse_mass_a, inverse_mass_b,
    target_distance,
    alpha, -- compliance, already scaled by delta^2
    lambda_before
)
    local eps = 1e-8

    local delta_x = bx - ax
    local delta_y = by - ay
    local length = orb.magnitude(delta_x, delta_y)
    if length < eps then
        return 0, 0, 0, 0, lambda_before
    end

    local normal_x, normal_y = delta_x / length, delta_y / length

    local constraint = length - target_distance
    local weight_sum = inverse_mass_a + inverse_mass_b
    local denominator = weight_sum + alpha
    if denominator < eps then
        return 0, 0, 0, 0, lambda_before
    end

    local delta_lambda = -(constraint + alpha * lambda_before) / denominator
    local lambda_new = lambda_before + delta_lambda

    local correction_ax = inverse_mass_a * delta_lambda * -normal_x
    local correction_ay = inverse_mass_a * delta_lambda * -normal_y
    local correction_bx = inverse_mass_b * delta_lambda *  normal_x
    local correction_by = inverse_mass_b * delta_lambda *  normal_y

    return correction_ax, correction_ay, correction_bx, correction_by, lambda_new
end

function orb.enforce_inside_circle(
    particle_x, particle_y, particle_r, particle_inverse_mass,
    circle_x, circle_y, circle_r,
    alpha,
    lambda_before
)
    local eps = 1e-8

    local delta_x = particle_x - circle_x
    local delta_y = particle_y - circle_y
    local length = orb.magnitude(delta_x, delta_y)

    -- constraint is satisfied (particle is inside boundary)
    local constraint = length - (circle_r - particle_r)
    if constraint <= 0 then
        return 0, 0, lambda_before
    end

    if length < eps then
        return 0, 0, lambda_before
    end

    local normal_x = delta_x / length
    local normal_y = delta_y / length

    local denominator = particle_inverse_mass + alpha
    if denominator < eps then
        return 0, 0, lambda_before
    end

    local delta_lambda = -(constraint + alpha * lambda_before) / denominator
    local lambda_new = lambda_before + delta_lambda

    return particle_inverse_mass * delta_lambda * normal_x,
        particle_inverse_mass * delta_lambda * normal_y,
        lambda_new
end

function orb.step(delta)
    local this = orb

    local sub_delta = delta / this.n_sub_steps
    local collision_alpha = this.collision_compliance / (sub_delta * sub_delta)
    local orb_alpha = this.orb_compliance / (sub_delta * sub_delta)

    for sub_step_i = 1, this.n_sub_steps do
        -- pre solve
        for particle_i = 1, this.n_particles do
            local i = this.particle_i_to_data_offset(particle_i, this.particle_data_stride)

            local x = this.particle_data[i + _x_offset]
            local y = this.particle_data[i + _y_offset]
            this.particle_data[i + _previous_x_offset] = x
            this.particle_data[i + _previous_y_offset] = y

            local velocity_x = this.particle_data[i + _velocity_x_offset] * this.damping
            local velocity_y = this.particle_data[i + _velocity_y_offset] * this.damping

            local inv_mass = this.particle_data[i + _inverse_mass_offset]
            velocity_x = velocity_x + sub_delta * this.gravity_dx * this.gravity
            velocity_y = velocity_y + sub_delta * this.gravity_dy * this.gravity

            this.particle_data[i + _velocity_x_offset] = velocity_x
            this.particle_data[i + _velocity_y_offset] = velocity_y

            this.particle_data[i + _x_offset] = x + sub_delta * velocity_x
            this.particle_data[i + _y_offset] = y + sub_delta * velocity_y

            this.particle_data[i + _orb_lambda_offset] = 0
        end

        for i = 1, this.n_particles * this.n_particles do
            this.particle_collision_lambdas[i] = 0
        end

        for constraint_iteration_i = 1, this.n_constraint_iterations do
            -- particle - particle collision
            for self_particle_i = 1, this.n_particles do
                for other_particle_i = 1, this.n_particles do
                    if self_particle_i ~= other_particle_i then
                        local self_i = this.particle_i_to_data_offset(self_particle_i, this.particle_data_stride)
                        local other_i = this.particle_i_to_data_offset(other_particle_i, this.particle_data_stride)

                        local lambda_i = this.particle_is_to_lambda_i(
                            self_particle_i, other_particle_i,
                            this.n_particles
                        )

                        local self_x = this.particle_data[self_i + _x_offset]
                        local self_y = this.particle_data[self_i + _y_offset]
                        local self_r = this.particle_data[self_i + _radius_offset]
                        local self_inv_mass = this.particle_data[self_i + _inverse_mass_offset]

                        local other_x = this.particle_data[other_i + _x_offset]
                        local other_y = this.particle_data[other_i + _y_offset]
                        local other_r = this.particle_data[other_i + _radius_offset]
                        local other_inv_mass = this.particle_data[other_i + _inverse_mass_offset]

                        local min_distance = self_r + other_r
                        local squared_distance = orb.squared_distance(self_x, self_y, other_x, other_y)
                        if squared_distance <= min_distance * min_distance then
                            local self_correction_x, self_correction_y,
                            other_correction_x, other_correction_y,
                            lambda = orb.enforce_distance(
                                self_x, self_y,
                                other_x, other_y,
                                self_inv_mass,
                                other_inv_mass,
                                min_distance, collision_alpha,
                                this.particle_collision_lambdas[lambda_i]
                            )

                            this.particle_data[self_i + _x_offset] = self_x + self_correction_x
                            this.particle_data[self_i + _y_offset] = self_y + self_correction_y
                            this.particle_data[other_i + _x_offset] = other_x + other_correction_x
                            this.particle_data[other_i + _y_offset] = other_y + other_correction_y
                            this.particle_collision_lambdas[lambda_i] = lambda
                        end
                    end
                end
            end

            -- particle - orb collision
            for particle_i = 1, this.n_particles do
                local self_i = this.particle_i_to_data_offset(particle_i, this.particle_data_stride)
                local self_x = this.particle_data[self_i + _x_offset]
                local self_y = this.particle_data[self_i + _y_offset]
                local self_r = this.particle_data[self_i + _radius_offset]
                local self_inv_mass = this.particle_data[self_i + _inverse_mass_offset]

                local correction_x, correction_y, lambda = this.enforce_inside_circle(
                    self_x, self_y, self_r, self_inv_mass,
                    this.orb_center_x, this.orb_center_y, this.orb_radius,
                    orb_alpha, this.particle_data[self_i + _orb_lambda_offset]
                )

                this.particle_data[self_i + _x_offset] = self_x + correction_x
                this.particle_data[self_i + _y_offset] = self_y + correction_y
                this.particle_data[self_i + _orb_lambda_offset] = lambda
            end
        end

        -- post solve
        for particle_i = 1, this.n_particles do
            local i = this.particle_i_to_data_offset(particle_i, this.particle_data_stride)
            local x = this.particle_data[i + _x_offset]
            local y = this.particle_data[i + _y_offset]

            local velocity_x = (x - this.particle_data[i + _previous_x_offset]) / sub_delta
            local velocity_y = (y - this.particle_data[i + _previous_y_offset]) / sub_delta
            this.particle_data[i + _velocity_x_offset] = velocity_x
            this.particle_data[i + _velocity_y_offset] = velocity_y
        end
    end

    this.timestamp = love.timer.getTime()
    this.update_mesh_data()
end

function orb.draw()
    local this = orb

    love.graphics.setColor(1, 1, 1, 1)
    this.mesh:draw()
end

function orb.set_position(x, y)
    local this = orb

    this.orb_center_x = x
    this.orb_center_y = y
end

function orb.agitate()
    local this = orb

    for particle_i = 1, this.n_particles do
        local i = this.particle_i_to_data_offset(particle_i, this.particle_data_stride)
        local magnitude = orb.mix(this.min_agitation, this.max_agitation, math.random())

        local dx = this.particle_data[i + _x_offset] - this.orb_center_x
        local dy = this.particle_data[i + _y_offset] - this.orb_center_y
        dx, dy = orb.normalize(dx, dy)

        local vx = this.particle_data[i + _velocity_x_offset]
        local vy = this.particle_data[i + _velocity_y_offset]

        this.particle_data[i + _velocity_x_offset] = vx - dx * magnitude
        this.particle_data[i + _velocity_y_offset] = vx - dy * magnitude
    end
end

return orb

