require "common.label_sdf"
require "common.translation"
require "menu.menu_scene"
require "common.linked_list"

rt.settings.title_banner_scene = {
    n_sperms = 412,
    sperm = {
        min_radius = 10,
        max_radius = 12,
        min_velocity = 400,
        max_velocity = 800,
        air_resistance = 1 - 1e-6,
        position_history_n = 50,
        length = 50,
        n_particles = 24,

        contour_clearance = 1.5,
        shape_compliance = 1e-9,

        gravity = 0.5,
        gravity_dx = 0,
        gravity_dy = 1,
        gravity_dz = 0,

        damping = 0.99,
        n_sub_steps = 1,
        n_constraint_iterations = 1,
        segment_compliance = 1e-8
    },

    blob = {
        n_blobs = 1024,
        min_position_velocity = 80,
        max_position_velocity = 100,

        min_scale = 0,
        max_scale = 1.5,

        min_radius = 100,
        max_radius = 100,

        min_scale_velocity = 0.1,
        max_scale_velocity = 0.15,

        min_rotation_velocity = 0.05,
        max_rotation_velocity = 0.25,

        min_orbit_velocity = 20,
        max_orbit_velocity = 20,

        min_alpha = 0.04,
        max_alpha = 0.1
    },

    text_animation_duration = 1
}

aux.TitleBannerScene = meta.class("TitleBannerScene", rt.Scene, true)

function aux.TitleBannerScene:size_allocate(x, y, width, height)
    self._sdf_label = rt.LabelSDF(
        rt.Translation.menu_scene.title_screen.title,
        120,
        rt.Font(rt.settings.menu_scene.title_screen.font_roman),
        20,
        0.05
    )

    local label_w, label_h = self._sdf_label:measure()

    self._sdf_label:realize()
    self._sdf_label:reformat(
        x + 0.5 * width - 0.5 * label_w,
        y + 0.5 * height - 0.5 * label_h,
        label_w, label_h
    )

    self._text_shader_animation = rt.TimedAnimation(
        rt.settings.title_banner_scene.text_animation_duration,
        0, 1,
        rt.InterpolationFunctions.GAUSSIAN_HIGHPASS
    )

    self._blob_texture_shader = rt.Shader("website/title_banner_scene_blob_texture.glsl")

    self._blob_mesh_radius = 0.25 * height
    self._blob_texture_padding = 20
    self._blob_texture = rt.RenderTexture(1000, 1000)

    love.graphics.push("all")
    self._blob_texture:bind()
    love.graphics.clear()
    self._blob_texture_shader:bind()
    love.graphics.rectangle("fill", 0, 0, self._blob_texture:get_size())
    self._blob_texture_shader:unbind()
    love.graphics.pop()

    local settings = rt.settings.title_banner_scene.blob
    local center_x, center_y = x + 0.5 * width, y + 0.5 * height
    self._center_x, self._center_y = center_x, center_y
    self._radius_x, self._radius_y = 0.5 * label_w, 0.5 * label_h

    do
        self._blobs = {}
        local area_w, area_h = label_w, label_h
        local n_blobs = settings.n_blobs
        for blob_i = 1, n_blobs do
            local angle = rt.random.number(0, math.tau)
            local offset_x = rt.random.number(0, 0.5 * area_w)
            local offset_y = rt.random.number(0, 0.5 * area_h)
            local cx = center_x
            local cy = center_y

            local radius = rt.random.number(settings.min_radius, settings.max_radius)

            local x_offset = rt.random.number(0, 0.5 * area_w)
            local y_offset = rt.random.number(0, 0.5 * area_h)

            local pdx, pdy = math.cos(angle), math.sin(angle)
            local px = cx --+ pdx * x_offset
            local py = cy --+ pdy * y_offset

            local vx, vy = math.normalize(math.subtract(px, py, center_x, center_y))
            local vm = rt.random.number(settings.min_position_velocity, settings.max_position_velocity)
            vx = vx * vm
            vy = vy * vm

            table.insert(self._blobs, {
                angle = angle,

                x_scale = rt.random.number(settings.min_scale, settings.max_scale),
                x_scale_velocity = rt.random.number(settings.min_scale_velocity, settings.max_scale_velocity),
                x_scale_elapsed = rt.random.number(0, math.tau),

                y_scale = rt.random.number(settings.min_scale, settings.max_scale),
                y_scale_velocity = rt.random.number(settings.min_scale_velocity, settings.max_scale_velocity),
                y_scale_elapsed = rt.random.number(0, math.tau),

                x = px,
                y = py,
                velocity_x = vx,
                velocity_y = vy,
                orbit_direction = rt.random.choose(-1, 1),
                orbit_velocity = 0,

                rotation = rt.random.number(0, math.tau),
                rotation_velocity = rt.random.number(settings.min_rotation_velocity, settings.max_rotation_velocity),

                x_offset = x_offset,
                y_offset = y_offset,
                mass = math.pi * radius * radius,

                radius = radius,
                alpha = rt.random.number(settings.min_alpha, settings.max_alpha)
            })
        end
    end

    self:_allocate_particles(x, y, width, height)

    free(self._canvas, self._blob_shader)
    self._canvas = rt.RenderTexture(width, height, {
        msaa = 8
    })

    local try_compile = function(path)
        local success, shader = pcall(function()
            local shader = rt.Shader(path)
            shader:compile()
            return shader
        end)

        if success then
            return shader
        else
            rt.critical(shader)
            return nil
        end
    end

    self._blob_shader = try_compile("website/title_banner_scene_blob_draw.glsl")
    self._text_shader = try_compile("website/title_banner_scene_text_draw.glsl")
    self._sperm_shader = try_compile("website/title_banner_scene_sperm_draw.glsl")

    for tex in range(self._blob_texture, self._canvas) do
        tex:set_scale_mode(rt.TextureScaleMode.LINEAR)
    end


    self._text_shader_animation:reset()
end

function aux.TitleBannerScene:update(delta)
    local settings = rt.settings.title_banner_scene.blob

    self._text_shader_animation:update(delta)

    local max_radius = math.max(self._radius_x, self._radius_y)
    local velocity_scale_x = self._radius_x / max_radius
    local velocity_scale_y = self._radius_y / max_radius

    do
        local bounds = self:get_bounds()
        for blob in values(self._blobs) do

            local ox, oy = blob.x - self._center_x, blob.y - self._center_y
            local dist = math.magnitude(ox, oy)

            local dx, dy = math.normalize(ox, oy)

            local tx, ty
            if blob.orbit_direction == 1 then
                tx, ty = math.turn_left(dx, dy)
            else
                tx, ty = math.turn_right(dx, dy)
            end
            tx, ty = math.normalize(tx, ty)

            local t_weight = math.distance(blob.x, blob.y, self._center_x, self._center_y) / math.min(self._radius_x, self._radius_y)

            local ax = tx * blob.orbit_velocity * math.min(t_weight, 1)
            local ay = ty * blob.orbit_velocity * math.min(t_weight, 1)

            local vt = math.dot(
                blob.velocity_x + ax * delta,
                blob.velocity_y + ay * delta,
                tx, ty
            )

            local centripetal = (vt * vt) / dist
            ax = ax - dx * centripetal
            ay = ay - dy * centripetal

            blob.x = blob.x + blob.velocity_x * delta
            blob.y = blob.y + blob.velocity_y * delta

            blob.x_scale_elapsed = blob.x_scale_elapsed + delta
            blob.x_scale = math.mix(
                settings.min_scale,
                settings.max_scale,
                rt.InterpolationFunctions.SINE_WAVE(blob.x_scale_elapsed, blob.x_scale_velocity)
            )

            blob.y_scale_elapsed = blob.y_scale_elapsed + delta
            blob.y_scale = math.mix(
                settings.min_scale,
                settings.max_scale,
                rt.InterpolationFunctions.SINE_WAVE(blob.y_scale_elapsed, blob.y_scale_velocity)
            )

            if blob.x_scale <= 0.01 or blob.y_scale <= 0.01 then
                blob.x = self._center_x
                blob.y = self._center_y

                local angle = rt.random.number(0, math.tau)
                local vm = rt.random.number(settings.min_position_velocity, settings.max_position_velocity)

                blob.velocity_x = math.cos(angle) * vm * velocity_scale_x
                blob.velocity_y = math.sin(angle) * vm * velocity_scale_y

                blob.x_scale = rt.random.number(settings.min_scale, settings.max_scale)
                blob.y_scale = rt.random.number(settings.min_scale, settings.max_scale)
                blob.x_scale_elapsed = rt.random.number(0, math.tau)
                blob.y_scale_elapsed = rt.random.number(0, math.tau)
            end
        end
    end

    self:_update_particles(delta)
end

function aux.TitleBannerScene:draw()
    local texture = self._blob_texture:get_native()
    local tex_w, tex_h = self._blob_texture:get_size()
    local origin_x, origin_y = 0.5 * tex_w, 0.5 * tex_h

    love.graphics.push("all")
    self._canvas:bind()

    love.graphics.translate(0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight())
    local scale = -0.05
    love.graphics.scale(1 + scale, 1 + scale)
    love.graphics.translate(-0.5 * love.graphics.getWidth(), -0.5 * love.graphics.getHeight())

    love.graphics.clear()
    love.graphics.setBlendMode("alpha", "premultiplied")
    for blob in values(self._blobs) do
        love.graphics.setColor(blob.alpha, blob.alpha, blob.alpha, blob.alpha)
        love.graphics.draw(
            texture,
            blob.x, blob.y,
            blob.rotation,
            blob.radius * blob.x_scale / tex_w, blob.radius * blob.y_scale / tex_h,
            origin_x, origin_y
        )
    end
    self._canvas:unbind()
    love.graphics.pop()

    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.clear(0, 0, 0, 0) --rt.Palette.GRAY_8:unpack())

    if self._blob_shader ~= nil then
        love.graphics.push("all")
        self._blob_shader:bind()
        self._blob_shader:send("black", rt.Palette.BLACK)
        self._blob_shader:send("elapsed", rt.SceneManager:get_elapsed())
        self._canvas:draw()
        self._blob_shader:unbind()
        love.graphics.pop()
    end

    --self:_draw_particles()

    love.graphics.push("all")
    self._text_shader:bind()
    self._text_shader:send("black", rt.Palette.BLACK)
    self._text_shader:send("elapsed", rt.SceneManager:get_elapsed())
    self._text_shader:send("animation", self._text_shader_animation:get_value())
    self._sdf_label:draw()
    self._text_shader:unbind()
    love.graphics.pop()
end

do

    local _TIMESTEP = 1 / 120
    local _MAX_STEPS_PER_FRAME = 4

    local _x_offset = 0
    local _y_offset = 1
    local _previous_x_offset = 2
    local _previous_y_offset = 3
    local _velocity_x_offset = 4
    local _velocity_y_offset = 5
    local _mass_offset = 6
    local _inverse_mass_offset = 7
    local _segment_lambda_offset = 8
    local _shape_lambda_x_offset = 9
    local _shape_lambda_y_offset = 10
    local _head_lambda_offset = 11
    local _tail_lambda_offset = 12

    local _particle_stride = _tail_lambda_offset + 1
    local _particle_i_to_data_offset = function(particle_i)
        return (particle_i - 1) * _particle_stride + 1
    end

    local function _build_band_targets(
        ax, ay, ar,
        bx, by, br,
        n_particles,
        clearance
    )
        local ra = ar + clearance
        local rb = br + clearance
        local dx, dy = bx - ax, by - ay
        local distance = math.sqrt(dx * dx + dy * dy)
        local axis_angle = 0
        if distance > math.eps then
            axis_angle = math.atan2(dy, dx)
        end

        local targets = {}

        if distance <= math.abs(ra - rb) + math.eps then
            local cx, cy, radius = ax, ay, ra
            if rb > ra then cx, cy, radius = bx, by, rb end
            for i = 1, n_particles do
                local angle = axis_angle + (i - 1) / n_particles * math.tau
                targets[i] = {
                    x = cx + math.cos(angle) * radius,
                    y = cy + math.sin(angle) * radius
                }
            end
            return targets
        end

        local cosine = (ra - rb) / distance
        cosine = math.max(-1, math.min(1, cosine))
        local beta = math.acos(cosine)
        local theta1 = axis_angle - beta
        local theta2 = axis_angle + beta
        local theta3 = theta1 + math.tau

        local tail_intervals = math.max(2, math.floor(n_particles * 0.16 + 0.5))
        local head_intervals = math.max(4, math.floor(n_particles * 0.34 + 0.5))
        if tail_intervals + head_intervals > n_particles - 2 then
            tail_intervals = math.max(1, math.floor((n_particles - 2) * 0.35))
            head_intervals = n_particles - 2 - tail_intervals
        end
        local tangent_intervals = n_particles - tail_intervals - head_intervals
        local top_intervals = math.floor(tangent_intervals / 2)
        local bottom_intervals = tangent_intervals - top_intervals

        local function add(x, y)
            targets[#targets + 1] = { x = x, y = y }
        end

        for k = 0, tail_intervals - 1 do
            local angle = theta1 + (2 * beta) * k / tail_intervals
            add(bx + rb * math.cos(angle), by + rb * math.sin(angle))
        end

        local b2x, b2y = bx + rb * math.cos(theta2), by + rb * math.sin(theta2)
        local a2x, a2y = ax + ra * math.cos(theta2), ay + ra * math.sin(theta2)
        for k = 0, top_intervals - 1 do
            local t = k / top_intervals
            add(b2x + (a2x - b2x) * t, b2y + (a2y - b2y) * t)
        end

        local head_arc = math.tau - 2 * beta
        for k = 0, head_intervals - 1 do
            local angle = theta2 + head_arc * k / head_intervals
            add(ax + ra * math.cos(angle), ay + ra * math.sin(angle))
        end

        local a1x, a1y = ax + ra * math.cos(theta3), ay + ra * math.sin(theta3)
        local b1x, b1y = bx + rb * math.cos(theta3), by + rb * math.sin(theta3)
        for k = 0, bottom_intervals - 1 do
            local t = k / bottom_intervals
            add(a1x + (b1x - a1x) * t, a1y + (b1y - a1y) * t)
        end

        while #targets < n_particles do
            local angle = axis_angle + (#targets / n_particles) * math.tau
            targets[#targets + 1] = {
                x = ax + ra * math.cos(angle),
                y = ay + ra * math.sin(angle)
            }
        end
        while #targets > n_particles do targets[#targets] = nil end

        return targets
    end

    local function _enforce_position_axis(position, target, inverse_mass, alpha, lambda_before)
        local denominator = inverse_mass + alpha
        if denominator < math.eps then return 0, lambda_before end

        local constraint = position - target
        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        return inverse_mass * delta_lambda, lambda_before + delta_lambda
    end

    function aux.TitleBannerScene:_allocate_particles(x, y, width, height)
        self._width = width
        self._height = height
        local cx, cy = self._center_x, self._center_y
        do
            self._sperms = {}
            self._particles = {}
            self._n_particles = 0

            local settings = rt.settings.title_banner_scene.sperm

            local particles = self._particles
            local n_sperms = rt.settings.title_banner_scene.n_sperms
            local golden_ratio = (1 + math.sqrt(5)) / 2
            for sperm_i = 1, n_sperms do
                local idx = sperm_i - 0.5 - 1
                local z_value = 1 - 2 * idx / n_sperms
                local theta = math.tau * idx / golden_ratio

                local sph_radius = math.sqrt(1 - z_value * z_value)
                local dir_x = sph_radius * math.cos(theta)
                local dir_y = sph_radius * math.sin(theta)
                local dir_z = z_value

                local velocity = rt.random.number(settings.min_velocity, settings.max_velocity)
                local step = velocity * rt.SceneManager:get_timestep()

                local history_n = math.ceil(settings.length / step)
                local position_history = rt.LinkedList()
                for i = 1, history_n do
                    local back = (history_n - i) * step
                    position_history:push_back(cx - dir_x * back, cy - dir_y * back, 0 - dir_z * back)
                end

                local length = (history_n - 1) * step
                local front_radius = rt.random.number(settings.min_radius, settings.max_radius)
                local back_radius = 3

                local head_x, head_y = cx, cy
                local tail_x, tail_y = cx - dir_x * length, cy - dir_y * length

                local n_particles = settings.n_particles
                local particle_start_offset = _particle_i_to_data_offset(self._n_particles + 1)
                local draw_contour = {}
                local targets = _build_band_targets(
                    head_x, head_y, front_radius,
                    tail_x, tail_y, back_radius,
                    n_particles, settings.contour_clearance
                )
                for i = 1, n_particles do
                    local px, py = targets[i].x, targets[i].y
                    self._n_particles = self._n_particles + 1
                    local particle_i = self._n_particles
                    local base = _particle_i_to_data_offset(particle_i)

                    particles[base + _x_offset] = px
                    particles[base + _y_offset] = py
                    particles[base + _previous_x_offset] = px
                    particles[base + _previous_y_offset] = py
                    particles[base + _velocity_x_offset] = 0
                    particles[base + _velocity_y_offset] = 0
                    particles[base + _mass_offset] = 1
                    particles[base + _inverse_mass_offset] = 1
                    particles[base + _segment_lambda_offset] = 0
                    particles[base + _shape_lambda_x_offset] = 0
                    particles[base + _shape_lambda_y_offset] = 0
                    particles[base + _head_lambda_offset] = 0
                    particles[base + _tail_lambda_offset] = 0

                    table.insert(draw_contour, px)
                    table.insert(draw_contour, py)
                end

                table.insert(draw_contour, draw_contour[1])
                table.insert(draw_contour, draw_contour[2])

                local hue = rt.random.number(0, 1)
                table.insert(self._sperms, {
                    x = cx,
                    y = cy,
                    z = 0,
                    prev_x = cx,
                    prev_y = cy,
                    prev_z = 0,
                    draw_x = cx,
                    draw_y = cy,
                    dx = dir_x * velocity,
                    dy = dir_y * velocity,
                    dz = dir_z * velocity,
                    front_radius = front_radius,
                    back_radius = back_radius,
                    length = length,
                    history_n = history_n,
                    hue = hue,
                    color = { rt.lcha_to_rgba(0.8, 1.0, hue, 1.0) },
                    position_history = position_history,
                    particle_start_offset = particle_start_offset,
                    n_particles = n_particles,
                    draw_contour = draw_contour,
                    prev_contour = { table.unpack(draw_contour) },
                    render_contour = { table.unpack(draw_contour) },
                    tail_x = tail_x,
                    tail_y = tail_y,
                    prev_tail_x = tail_x,
                    prev_tail_y = tail_y,
                })
            end
        end

        self._step_accumulator = 0
        self._interpolation_alpha = 0
        self:update(0)
    end

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

    local function _enforce_circle_nonpenetration(ax, ay, inverse_mass, cx, cy, cr, alpha, lambda_before)
        local delta_x = ax - cx
        local delta_y = ay - cy
        local length = math.sqrt(delta_x * delta_x + delta_y * delta_y)

        local normal_x, normal_y
        if length < math.eps then
            normal_x, normal_y = 1, 0
            length = 0
        else
            normal_x, normal_y = delta_x / length, delta_y / length
        end

        local constraint = length - cr
        local denominator = inverse_mass + alpha
        if denominator < math.eps then return 0, 0, lambda_before end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = math.max(0, lambda_before + delta_lambda)
        delta_lambda = lambda_new - lambda_before

        return inverse_mass * delta_lambda * normal_x,
        inverse_mass * delta_lambda * normal_y,
        lambda_new
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

    local function _enforce_exact_distance(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        target_distance,
        alpha,
        lambda_before
    )
        local delta_x = bx - ax
        local delta_y = by - ay
        local length = math.sqrt(delta_x^2 + delta_y^2)
        if length < math.eps then
            return 0, 0, 0, 0, lambda_before
        end

        local normal_x, normal_y = delta_x / length, delta_y / length

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

    function aux.TitleBannerScene:_update_particles(delta)
        local settings = rt.settings.title_banner_scene.sperm
        local timestep = 1 / 120
        local air_resistance = settings.air_resistance

        local n_sub_steps = settings.n_sub_steps
        local n_constraint_iterations = settings.n_constraint_iterations
        local damping = settings.damping

        local sub_delta = timestep / n_sub_steps
        local segment_alpha = settings.segment_compliance / (sub_delta ^ 2)
        local shape_alpha = settings.shape_compliance / (sub_delta ^ 2)
        local circle_alpha = 0
        local particles = self._particles

        self._step_accumulator = self._step_accumulator + delta

        local n_steps = 0
        while self._step_accumulator >= timestep do
            self._step_accumulator = self._step_accumulator - timestep

            n_steps = n_steps + 1
            if n_steps > _MAX_STEPS_PER_FRAME then
                self._step_accumulator = 0
                break
            end

            for sperm in values(self._sperms) do
                local previous_head_x, previous_head_y, previous_head_z = sperm.x, sperm.y, sperm.z
                local previous_tail_x, previous_tail_y, previous_tail_z = sperm.position_history:get_front_node():unpack()

                sperm.prev_x, sperm.prev_y, sperm.prev_z = sperm.x, sperm.y, sperm.z
                sperm.prev_tail_x, sperm.prev_tail_y = sperm.tail_x, sperm.tail_y

                do
                    local prev, cur = sperm.prev_contour, sperm.draw_contour
                    for i = 1, #cur do prev[i] = cur[i] end
                end

                sperm.dx = air_resistance * sperm.dx + settings.gravity * settings.gravity_dx
                sperm.dy = air_resistance * sperm.dy + settings.gravity * settings.gravity_dy
                sperm.dz = air_resistance * sperm.dz + settings.gravity * settings.gravity_dz

                local move_x, move_y, move_z = sperm.dx * timestep, sperm.dy * timestep, sperm.dz * timestep
                sperm.x = sperm.x + move_x
                sperm.y = sperm.y + move_y
                sperm.z = sperm.z + move_z

                sperm.position_history:push_back(sperm.x, sperm.y, sperm.z)
                sperm.position_history:pop_front()

                local n = sperm.n_particles
                local particle_start_offset = sperm.particle_start_offset

                local head_end_x, head_end_y, head_end_z = sperm.position_history:get_back_node():unpack()
                local head_r = sperm.front_radius
                local tail_end_x, tail_end_y, tail_end_z = sperm.position_history:get_front_node():unpack()
                local tail_r = sperm.back_radius

                for sub_step_i = 1, n_sub_steps do
                    local fraction = sub_step_i / n_sub_steps
                    local head_x = previous_head_x + (head_end_x - previous_head_x) * fraction
                    local head_y = previous_head_y + (head_end_y - previous_head_y) * fraction
                    local tail_x = previous_tail_x + (tail_end_x - previous_tail_x) * fraction
                    local tail_y = previous_tail_y + (tail_end_y - previous_tail_y) * fraction

                    local targets = _build_band_targets(
                        head_x, head_y, head_r,
                        tail_x, tail_y, tail_r,
                        n, settings.contour_clearance
                    )

                    local segment_lengths = {}
                    for i = 1, n do
                        local a = targets[i]
                        local b = targets[i % n + 1]
                        local dx, dy = b.x - a.x, b.y - a.y
                        segment_lengths[i] = math.sqrt(dx * dx + dy * dy)
                    end

                    for i = 1, n do
                        local node_i = particle_start_offset + (i - 1) * _particle_stride
                        local x, y, vx, vy, px, py = _pre_solve(
                            particles[node_i + _x_offset], particles[node_i + _y_offset],
                            particles[node_i + _velocity_x_offset], particles[node_i + _velocity_y_offset],
                            particles[node_i + _mass_offset],
                            0, 0,
                            damping,
                            sub_delta
                        )

                        particles[node_i + _x_offset] = x
                        particles[node_i + _y_offset] = y
                        particles[node_i + _velocity_x_offset] = vx
                        particles[node_i + _velocity_y_offset] = vy
                        particles[node_i + _previous_x_offset] = px
                        particles[node_i + _previous_y_offset] = py
                        particles[node_i + _segment_lambda_offset] = 0
                        particles[node_i + _shape_lambda_x_offset] = 0
                        particles[node_i + _shape_lambda_y_offset] = 0
                        particles[node_i + _head_lambda_offset] = 0
                        particles[node_i + _tail_lambda_offset] = 0
                    end

                    for _ = 1, n_constraint_iterations do
                        for i = 1, n do
                            local next_i = i % n + 1
                            local a = particle_start_offset + (i - 1) * _particle_stride
                            local b = particle_start_offset + (next_i - 1) * _particle_stride
                            local cax, cay, cbx, cby, lambda_new = _enforce_exact_distance(
                                particles[a + _x_offset], particles[a + _y_offset],
                                particles[b + _x_offset], particles[b + _y_offset],
                                particles[a + _inverse_mass_offset], particles[b + _inverse_mass_offset],
                                segment_lengths[i],
                                segment_alpha,
                                particles[a + _segment_lambda_offset]
                            )

                            particles[a + _x_offset] = particles[a + _x_offset] + cax
                            particles[a + _y_offset] = particles[a + _y_offset] + cay
                            particles[b + _x_offset] = particles[b + _x_offset] + cbx
                            particles[b + _y_offset] = particles[b + _y_offset] + cby
                            particles[a + _segment_lambda_offset] = lambda_new
                        end

                        for i = 1, n do
                            local node_i = particle_start_offset + (i - 1) * _particle_stride
                            local target = targets[i]
                            local node_x = particles[node_i + _x_offset]
                            local node_y = particles[node_i + _y_offset]
                            local inverse_mass = particles[node_i + _inverse_mass_offset]

                            local cx, lambda_x = _enforce_position_axis(
                                node_x, target.x, inverse_mass,
                                shape_alpha, particles[node_i + _shape_lambda_x_offset]
                            )
                            node_x = node_x + cx
                            particles[node_i + _shape_lambda_x_offset] = lambda_x

                            local cy, lambda_y = _enforce_position_axis(
                                node_y, target.y, inverse_mass,
                                shape_alpha, particles[node_i + _shape_lambda_y_offset]
                            )
                            node_y = node_y + cy
                            particles[node_i + _shape_lambda_y_offset] = lambda_y

                            local hx, hy, hl = _enforce_circle_nonpenetration(
                                node_x, node_y, inverse_mass,
                                head_x, head_y, head_r,
                                circle_alpha, particles[node_i + _head_lambda_offset]
                            )

                            node_x = node_x + hx
                            node_y = node_y + hy
                            particles[node_i + _head_lambda_offset] = hl

                            local tx, ty, tl = _enforce_circle_nonpenetration(
                                node_x, node_y, inverse_mass,
                                tail_x, tail_y, tail_r,
                                circle_alpha, particles[node_i + _tail_lambda_offset]
                            )

                            node_x = node_x + tx
                            node_y = node_y + ty
                            particles[node_i + _tail_lambda_offset] = tl
                            particles[node_i + _x_offset] = node_x
                            particles[node_i + _y_offset] = node_y
                        end
                    end

                    for i = 1, n do
                        local node_i = particle_start_offset + (i - 1) * _particle_stride
                        local vx, vy = _post_solve(
                            particles[node_i + _x_offset], particles[node_i + _y_offset],
                            particles[node_i + _previous_x_offset], particles[node_i + _previous_y_offset],
                            sub_delta
                        )
                        particles[node_i + _velocity_x_offset] = vx
                        particles[node_i + _velocity_y_offset] = vy
                    end
                end

                local contour = sperm.draw_contour
                for i = 1, n do
                    local node_i = particle_start_offset + (i - 1) * _particle_stride
                    contour[2 * i - 1] = particles[node_i + _x_offset]
                    contour[2 * i] = particles[node_i + _y_offset]
                end
                contour[2 * n + 1] = contour[1]
                contour[2 * n + 2] = contour[2]

                sperm.tail_x, sperm.tail_y = tail_end_x, tail_end_y
            end
        end

        self._interpolation_alpha = self._step_accumulator / timestep
    end

    function aux.TitleBannerScene:_draw_particles()
        local t = self._interpolation_alpha
        local function lerp(a, b) return a + (b - a) * t end

        for sperm in values(self._sperms) do
            rt.Palette.BLACK:bind()
            local prev, cur, out = sperm.prev_contour, sperm.draw_contour, sperm.render_contour
            for i = 1, #cur do out[i] = lerp(prev[i], cur[i]) end
            love.graphics.polygon("fill", out)

            love.graphics.push("all")
            self._sperm_shader:bind()
            self._sperm_shader:send("elapsed", rt.SceneManager:get_elapsed())

            rt.Palette.WHITE:bind()
            for i = 1, #cur do out[i] = lerp(prev[i], cur[i]) end
            love.graphics.line(out)

            self._sperm_shader:unbind()
            love.graphics.pop()
        end


    end
end