--- @class rt.Balloon
rt.Balloon = meta.class("Balloon")

local settings = {
    n_sub_steps = 16,
    n_constraint_iterations = 4,

    vertex_density = 1 / 4,
    damping = 0.9999,
    gravity = 5000,

    distance_compliance = 1e-4,
    volume_compliance = 0,
    line_compliance = 0,
    bending_compliance = 0
}

function rt.Balloon:instantiate(radius, center_x, center_y)
    mt.assert(radius, mt.Number, center_x, mt.Number, center_y, mt.Number)

    local n_nodes = math.ceil(math.max(16, settings.vertex_density * 2 * math.pi * radius))

    -- particle data
    self._particles = {}
    for i = 1, n_nodes do
        local angle = (i - 1) / n_nodes * 2 * math.pi
        local x = center_x + radius * math.cos(angle)
        local y = center_y + radius * math.sin(angle)
        local mass = 1
        table.insert(self._particles, {
            x = x,
            y = y,
            previous_x = x,
            previous_y = y,
            draw_x = x,
            draw_y = y,
            velocity_x = 0,
            velocity_y = 0,

            radius = 4,
            mass = 1,
            inverse_mass = 1 / mass,

            distance_lambda = 0,
            bending_lambda = 0,
            line_lambdas = { 0, 0, 0, 0 }
        })
    end

    -- clockwise winding

    -- collision planes
    local w, h = love.graphics.getDimensions()
    local padding = 5
    local x, y = padding, padding
    w = w - 2 * padding
    h = h - 2 * padding
    self._lines = {
        { x + 0, y + 0, x + w, y + 0 },
        { x + w, y + 0, x + w, y + h },
        { x + w, y + h, x + 0, y + h },
        { x + 0, y + h, x + 0, y + 0 }
    }

    -- line normals
    self._line_normals = {}
    for i, line in ipairs(self._lines) do
        local x1, y1, x2, y2 = line[1], line[2], line[3], line[4]
        local dx, dy = x2 - x1, y2 - y1
        local len = math.sqrt(dx * dx + dy * dy)
        self._line_normals[i] = { -dy / len, dx / len }
    end

    -- pairs from contour
    self._pairs = {}
    for i = 1, #self._particles do
        local i1 = i
        local i2 = math.wrap(i + 1, #self._particles)
        table.insert(self._pairs, {
            self._particles[i1],
            self._particles[i2]
        })
    end

    self._triplets = {}
    for i = 1, #self._particles do
        local i1 = i
        local i2 = math.wrap(i + 1, #self._particles)
        local i3 = math.wrap(i + 2, #self._particles)
        table.insert(self._pairs, {
            self._particles[i1],
            self._particles[i2],
            self._particles[i3]
        })
    end

    -- initial area
    local area = 0.0
    for i = 1, #self._particles do
        local p = self._particles[i]
        local q = self._particles[i % #self._particles + 1]
        area = area + 0.5 * (p.x * q.y - q.x * p.y)
    end
    self._rest_area = area

    -- global volume lambda
    self._volume_lambda = 0

    -- target segment length
    self._segment_length = (2 * math.pi * radius) / #self._particles

    -- gauss-seidel direction
    self._direction = true

    -- accumulated time
    self._elapsed = 0
end

function rt.Balloon:draw(frame_interpolation_alpha)
    frame_interpolation_alpha = frame_interpolation_alpha or 1
    local n = #self._particles

    local zoom = 1 / 1.25

    if self._mesh == nil then
        self._mesh_data = {}
        for i = 1, n do
            local angle_a = (i - 1) / n * 2 * math.pi
            local angle_b = i / n * 2 * math.pi
            local u_a = 0.5 + 0.5 * zoom * math.cos(angle_a)
            local v_a = 0.5 + 0.5 * zoom * math.sin(angle_a)
            local u_b = 0.5 + 0.5 * zoom * math.cos(angle_b)
            local v_b = 0.5 + 0.5 * zoom * math.sin(angle_b)

            table.insert(self._mesh_data, { 0, 0, 0.5,  0.5,  1, 1, 1, 1 }) -- center (unchanged)
            table.insert(self._mesh_data, { 0, 0, u_a,  v_a,  1, 1, 1, 1 })
            table.insert(self._mesh_data, { 0, 0, u_b,  v_b,  1, 1, 1, 1 })
        end
        self._mesh = rt.Mesh(self._mesh_data, rt.MeshDrawMode.TRIANGLES)
        self._mesh:set_texture(rt.Texture("assets/sprites/why.png"))
    end

    local mesh_data = self._mesh_data
    local positions = {}
    local sum_x, sum_y = 0, 0

    for i = 1, n do
        local a = self._particles[i]
        local b = self._particles[i % n + 1]

        local ax = a.draw_x + (a.x - a.draw_x) * frame_interpolation_alpha
        local ay = a.draw_y + (a.y - a.draw_y) * frame_interpolation_alpha
        local bx = b.draw_x + (b.x - b.draw_x) * frame_interpolation_alpha
        local by = b.draw_y + (b.y - b.draw_y) * frame_interpolation_alpha

        table.insert(positions, ax)
        table.insert(positions, ay)
        sum_x = sum_x + ax
        sum_y = sum_y + ay

        local base = (i - 1) * 3
        local va, vb = mesh_data[base + 2], mesh_data[base + 3]
        va[1], va[2] = ax, ay
        vb[1], vb[2] = bx, by
    end

    table.insert(positions, positions[1])
    table.insert(positions, positions[2])

    local cx, cy = sum_x / n, sum_y / n
    for i = 1, n do
        local center = mesh_data[(i - 1) * 3 + 1]
        center[1], center[2] = cx, cy
    end

    self._mesh:replace_data(mesh_data)

    love.graphics.setLineWidth(3)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.line(positions)

    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()

    local dark = 0.5
    love.graphics.setColor(dark, dark, dark, 1)
    for _, line in ipairs(self._lines) do
        love.graphics.line(line)
    end
end

do
    local function _pre_solve(
        position_x, position_y,
        velocity_x, velocity_y,
        mass,
        gravity_x, gravity_y,
        damping, delta
    )
        local previous_x = position_x
        local previous_y = position_y

        local world_velocity_new_x = velocity_x * damping + mass * gravity_x * delta
        local world_velocity_new_y = velocity_y * damping + mass * gravity_y * delta

        local position_new_x = position_x + world_velocity_new_x * delta
        local position_new_y = position_y + world_velocity_new_y * delta

        return position_new_x, position_new_y, world_velocity_new_x, world_velocity_new_y, previous_x, previous_y
    end

    local function _enforce_distance(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        target_distance,
        alpha,
        lambda_before
    )
        local delta_x = bx - ax
        local delta_y = by - ay
        local length = math.magnitude(delta_x, delta_y)
        if length < math.eps then
            return 0, 0, 0, 0, lambda_before
        end

        local normal_x, normal_y = math.normalize(delta_x, delta_y)

        local constraint = length - target_distance
        local weight_sum = inverse_mass_a + inverse_mass_b
        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return 0, 0, 0, 0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        local correction_ax = inverse_mass_a * delta_lambda * (-normal_x)
        local correction_ay = inverse_mass_a * delta_lambda * (-normal_y)
        local correction_bx = inverse_mass_b * delta_lambda * ( normal_x)
        local correction_by = inverse_mass_b * delta_lambda * ( normal_y)

        return correction_ax, correction_ay, correction_bx, correction_by, lambda_new
    end

    local function _enforce_line_collision(
        position_x, position_y, inverse_mass,
        radius,
        line_contact_x, line_contact_y,
        line_normal_x, line_normal_y,
        alpha,
        lambda_before
    )
        local normal_length = math.magnitude(line_normal_x, line_normal_y)
        if normal_length < math.eps then
            return 0.0, 0.0, lambda_before
        end
        local normalized_x, normalized_y = math.normalize(line_normal_x, line_normal_y)

        local relative_x = position_x - line_contact_x
        local relative_y = position_y - line_contact_y
        local signed_distance = math.dot(relative_x, relative_y, normalized_x, normalized_y)

        local constraint = signed_distance - radius
        if constraint >= 0.0 or inverse_mass <= 0.0 then
            return 0.0, 0.0, 0.0
        end

        local denominator = inverse_mass + alpha
        if denominator < math.eps then
            return 0.0, 0.0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = math.clamp(lambda_before + delta_lambda, 0.0, math.huge)
        delta_lambda = lambda_new - lambda_before

        local correction_x = inverse_mass * delta_lambda * normalized_x
        local correction_y = inverse_mass * delta_lambda * normalized_y

        return correction_x, correction_y, lambda_new
    end

    local function _enforce_bending(
        ax, ay, bx, by, cx, cy,
        inverse_mass_a, inverse_mass_b, inverse_mass_c,
        _,
        alpha,
        lambda_before
    )
        local tx = cx - ax
        local ty = cy - ay
        if math.magnitude(tx, ty) < math.eps then
            return 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, lambda_before
        end
        tx, ty = math.normalize(tx, ty)

        local nx, ny = math.turn_left(tx, ty)

        local mx = 0.5 * (ax + cx)
        local my = 0.5 * (ay + cy)

        local ex = mx - bx
        local ey = my - by
        local constraint = math.dot(ex, ey, nx, ny)

        local gax, gay =  0.5 * nx,  0.5 * ny
        local gbx, gby = -1.0 * nx, -1.0 * ny
        local gcx, gcy =  0.5 * nx,  0.5 * ny

        local weight_sum = inverse_mass_a * (0.5 * 0.5) +
            inverse_mass_b * (1.0 * 1.0) +
            inverse_mass_c * (0.5 * 0.5)

        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        local correction_ax = inverse_mass_a * delta_lambda * gax
        local correction_ay = inverse_mass_a * delta_lambda * gay
        local correction_bx = inverse_mass_b * delta_lambda * gbx
        local correction_by = inverse_mass_b * delta_lambda * gby
        local correction_cx = inverse_mass_c * delta_lambda * gcx
        local correction_cy = inverse_mass_c * delta_lambda * gcy

        return correction_ax, correction_ay, correction_bx, correction_by, correction_cx, correction_cy, lambda_new
    end

    local function _enforce_volume(particles, rest_area, alpha, lambda_before)
        local n = #particles
        local current_area = 0.0

        for i = 1, n do
            local p = particles[i]
            local q = particles[i % n + 1]
            current_area = current_area + 0.5 * (p.x * q.y - q.x * p.y)
        end

        local constraint = current_area - rest_area

        local weight_sum = 0.0
        local grads = {}
        for i = 1, n do
            local prev = particles[(i - 2) % n + 1]
            local next = particles[i % n + 1]
            local grad_x = 0.5 * (next.y - prev.y)
            local grad_y = 0.5 * (prev.x - next.x)
            grads[i] = { x = grad_x, y = grad_y }

            weight_sum = weight_sum + particles[i].inverse_mass * (grad_x * grad_x + grad_y * grad_y)
        end

        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        for i = 1, n do
            local p = particles[i]
            local g = grads[i]
            p.x = p.x + p.inverse_mass * delta_lambda * g.x
            p.y = p.y + p.inverse_mass * delta_lambda * g.y
        end

        return lambda_new
    end

    local function _post_solve(
        position_x, position_y,
        previous_x, previous_y,
        delta
    )
        local velocity_x = (position_x - previous_x) / delta
        local velocity_y = (position_y - previous_y) / delta

        return velocity_x, velocity_y
    end

    local function _closest_point_on_segment(xy_x, xy_y, sx1, sy1, sx2, sy2)
        local a_x, a_y = sx1, sy1
        local b_x, b_y = sx2, sy2
        local ab_x, ab_y = b_x - a_x, b_y - a_y
        local ab_len2 = ab_x * ab_x + ab_y * ab_y

        if ab_len2 <= 0.0 then
            return a_x, a_y
        end

        local ap_x, ap_y = xy_x - a_x, xy_y - a_y
        local t = (ap_x * ab_x + ap_y * ab_y) / ab_len2
        if t < 0.0 then t = 0.0 elseif t > 1.0 then t = 1.0 end

        return a_x + t * ab_x, a_y + t * ab_y
    end

    function rt.Balloon:update(delta)
        local sub_delta = delta / settings.n_sub_steps

        local damping = settings.damping
        local n_sub_steps = settings.n_sub_steps
        local n_constraint_iterations = settings.n_constraint_iterations

        local volume_alpha = settings.volume_compliance / (sub_delta^2)
        local line_alpha = settings.line_compliance / (sub_delta^2)
        local distance_alpha = settings.distance_compliance / (sub_delta^2)
        local bending_alpha = settings.bending_compliance / (sub_delta^2)

        local particles = self._particles
        local n_particles = #particles
        local pairs = self._pairs
        local tris = self._triplets
        local lines = self._lines
        local line_normals = self._line_normals
        local segment_length = self._segment_length

        local gravity_direction_x, gravity_direction_y = 0, 1
        local gravity = settings.gravity

        for particle_i = 1, n_particles do
            local particle = particles[particle_i]
            particle.previous_x = particle.x
            particle.previous_y = particle.y
            particle.draw_x = particle.x
            particle.draw_y = particle.y
        end

        for _ = 1, n_sub_steps do
            -- pre solve
            for particle_i = 1, n_particles  do
                local particle = particles[particle_i]
                local new_position_x, new_position_y, new_velocity_x, new_velocity_y, previous_x, previous_y = _pre_solve(
                    particle.x,
                    particle.y,
                    particle.velocity_x,
                    particle.velocity_y,
                    particle.mass,
                    gravity_direction_x * gravity, gravity_direction_y * gravity,
                    damping, sub_delta
                )

                particle.x = new_position_x
                particle.y = new_position_y
                particle.velocity_x = new_velocity_x
                particle.velocity_y = new_velocity_y
                particle.previous_x = previous_x
                particle.previous_y = previous_y

                particle.distance_lambda = 0
                particle.bending_lambda = 0
                for i = 1, 4 do
                    particle.line_lambdas[i] = 0
                end
            end

            self._volume_lambda = 0

            -- flip-flop gauss-seidel iteration direction
            local pair_start_i, pair_end_i, pair_step
            local tri_start_i, tri_end_i, tri_step
            if self._direction then
                pair_start_i = 1
                pair_end_i = #pairs
                pair_step = 1

                tri_start_i = 1
                tri_end_i = #tris
                tri_step = 1
            else
                pair_start_i = #pairs
                pair_end_i = 1
                pair_step = -1

                tri_start_i = #tris
                tri_end_i = 1
                tri_step = -1
            end
            self._direction = not self._direction

            for _ = 1, n_constraint_iterations do
                for pair_i = pair_start_i, pair_end_i, pair_step do
                    local a, b = pairs[pair_i][1], pairs[pair_i][2]
                    local correction_ax, correction_ay, correction_bx, correction_by, lambda_new = _enforce_distance(
                        a.x, a.y, b.x, b.y,
                        a.inverse_mass, b.inverse_mass,
                        segment_length,
                        distance_alpha,
                        a.distance_lambda
                    )

                    a.x = a.x + correction_ax
                    a.y = a.y + correction_ay
                    b.x = b.x + correction_bx
                    b.y = b.y + correction_by
                    a.distance_lambda = lambda_new
                end

                for tri_i = tri_start_i, tri_end_i, tri_step do
                    local a, b, c = table.unpack(tris[tri_i])

                    local segment_length_ab = segment_length
                    local segment_length_bc = segment_length
                    local target_length = segment_length_ab + segment_length_bc

                    local correction_ax, correction_ay, correction_bx, correction_by, correction_cx, correction_cy, lambda_new = _enforce_bending(
                        a.x, a.y, b.x, b.y, c.x, c.y,
                        a.inverse_mass, b.inverse_mass, c.inverse_mass,
                        2 * segment_length,
                        bending_alpha,
                        a.bending_lambda
                    )

                    a.x = a.x + correction_ax
                    a.y = a.y + correction_ay
                    b.x = b.x + correction_bx
                    b.y = b.y + correction_by
                    c.x = c.x + correction_cx
                    c.y = c.y + correction_cy

                    a.bending_lambda = lambda_new
                end

                self._volume_lambda = _enforce_volume(
                    particles,
                    self._rest_area,
                    volume_alpha,
                    self._volume_lambda
                )
            end

            -- solve line constraint
            for _ = 1, n_constraint_iterations do
                for particle_i = 1, n_particles do
                    local particle = self._particles[particle_i]
                    for line_i = 1, 4 do
                        local ax, ay, bx, by = table.unpack(lines[line_i])
                        local nx, ny = table.unpack(line_normals[line_i])
                        local cx, cy = _closest_point_on_segment(
                            particle.x, particle.y,
                            ax, ay, bx, by
                        )

                        local correction_x, correction_y, lambda_new = _enforce_line_collision(
                            particle.x,
                            particle.y,
                            particle.inverse_mass,
                            particle.radius, -- radius
                            cx,
                            cy,
                            nx,
                            ny,
                            line_alpha,
                            particle.line_lambdas[line_i]
                        )

                        particle.x = particle.x + correction_x
                        particle.y = particle.y + correction_y
                        particle.line_lambdas[line_i] = lambda_new
                    end
                end
            end

            -- post solve
            for particle_i = 1, n_particles do
                local particle = particles[particle_i]
                local new_velocity_x, new_velocity_y = _post_solve(
                    particle.x,
                    particle.y,
                    particle.previous_x,
                    particle.previous_y,
                    sub_delta
                )

                particle.velocity_x = new_velocity_x
                particle.velocity_y = new_velocity_y
            end
        end -- n sub steps
    end
end