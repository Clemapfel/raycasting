require "common.smoothed_motion_1d"

rt.settings.player_body = {
    canvas_scale = 3,
    outline_darkening = 0.5,

    particle_texture_scale = 1,
    core_outline_width = 0.5,

    contour_threshold = 0.05,
    threshold = 0.4,

    max_rope_length_radius_factor = 4.5,
    particle_texture_radius_factor = 1,
    contour_radius_factor = 2,

    n_rings = 4,
    rope_radius = 3,

    non_contour = {
        n_sub_steps = 2,
        n_constraint_iterations = 4,

        distance_compliance = 0,
        bending_compliance = 0.001,
        axis_compliance = 0.05,
        collision_compliance = 0.01,
        damping = 1 - 0.1,
        gravity = 250
    },

    contour = {
        collision_compliance = 120,
        axis_compliance = 0.00001,
        gravity = 0
    }
}

do
    -- copy settings if unassigned
    local from, to = rt.settings.player_body.non_contour, rt.settings.player_body.contour
    for k, v in pairs(from) do if to[k] == nil then to[k] = v end end
end

--- @class rt.PlayerBody
rt.PlayerBody = meta.class("PlayerBody")

--- @brief
function rt.PlayerBody:instantiate(position_x, position_y)
    meta.assert(position_x, "Number", position_y, "Number")
    self._position_x = position_x
    self._position_y = position_y

    self._core_vertices = nil
    self._core_color = rt.Palette.WHITE
    self._body_color = rt.Palette.BLACK

    self._stencil_bodies = {}
    self._use_contour = true

    self:_initialize()
end

local _x_offset = 0
local _y_offset = 1
local _velocity_x_offset = 2
local _velocity_y_offset = 3
local _previous_x_offset = 4 -- last sub step
local _previous_y_offset = 5
local _radius_offset = 6 -- radius, px
local _contour_radius_offset = 7
local _opacity_offset = 8
local _mass_offset = 9
local _inverse_mass_offset = 10
local _segment_length_offset = 11
local _contour_segment_length_offset = 12
local _collision_strength_offset = 13
local _distance_lambda_offset = 14
local _bending_lambda_offset = 15
local _axis_lambda_offset = 16

local _stride = _axis_lambda_offset + 1
local _particle_i_to_data_offset = function(particle_i)
    return (particle_i - 1) * _stride + 1 -- 1-based
end

local _particle_texture_shader = rt.Shader("common/player_body_particle_texture.glsl")
local _instance_draw_shader = rt.Shader("common/player_body_instanced_draw.glsl")
local _threshold_shader = rt.Shader("common/player_body_threshold.glsl")
local _outline_shader = rt.Shader("common/player_body_outline.glsl")
local _core_shader = rt.Shader("common/player_body_core.glsl")

DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
    if which == "k" then
        for shader in range(_particle_texture_shader, _instance_draw_shader, _threshold_shader, _outline_shader, _core_shader) do
            shader:recompile()
        end
    end
end)

--- @brief
function rt.PlayerBody:_initialize()
    local settings = rt.settings.player_body

    self._particle_data = {}
    self._ropes = {}

    local body_radius = rt.settings.player.radius
    local max_rope_length = math.floor(settings.max_rope_length_radius_factor * body_radius) - 1

    local particle_texture_radius = settings.particle_texture_radius_factor * rt.settings.player.radius - 1
    self._particle_texture_radius = particle_texture_radius

    do -- particle texture
        local w = (particle_texture_radius + 2) * 2
        local h = w
        self._particle_texture = rt.RenderTexture(w, h)

        -- fill particle with density data using shader
        love.graphics.push("all")
        love.graphics.reset()
        self._particle_texture:bind()
        _particle_texture_shader:bind()

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.rectangle("fill",
            0, 0, w, h
        )

        _particle_texture_shader:unbind()
        self._particle_texture:unbind()
        love.graphics.pop()
    end

    local max_particle_distance = -math.huge
    local max_particle_radius = -math.huge

    local radius_easing = function(i, n)
        local t = ((i - 1) / n)

        local function f(x) return x^-x  end
        t = f(t + (1 / math.exp(1))) * math.exp(-t^2)

        return particle_texture_radius * t
    end

    local contour_radius = settings.contour_radius_factor * particle_texture_radius

    local collision_easing = function(i, n)
        return ((i - 1) / n)
    end

    local opacity_easing = function(i, n)
        return 1 - ((i - 1) / n)
    end

    local fraction_to_rope_length = function(t)
        return (1 - t) * max_rope_length
    end

    local rope_length_to_n_nodes = function(length)
        return math.ceil(length / (particle_texture_radius / 2))
    end

    local mass_easing = function(i, n)
        return 1
    end

    do -- particles
        local particle_n = 1
        local add_rope = function(
            n_particles,
            length, contour_length,
            anchor_x, anchor_y,
            dx, dy
        )
            local rope = {
                anchor_x = anchor_x,
                anchor_y = anchor_y,

                axis_x = dx,
                axis_y = dy,

                length = length,
                contour_length = contour_length,

                start_i = particle_n,
                end_i = nil
            }

            local segment_length = length / n_particles
            local contour_segment_length = contour_length / n_particles

            local x, y = self._position_x + anchor_x, self._position_y + anchor_y
            local data = self._particle_data
            for rope_node_i = 1, n_particles do
                -- add particle
                local i = #data + 1
                data[i + _x_offset] = x
                data[i + _y_offset] = y
                data[i + _velocity_x_offset] = 0
                data[i + _velocity_y_offset] = 0
                data[i + _previous_x_offset] = x
                data[i + _previous_y_offset] = y

                local radius = radius_easing(rope_node_i, n_particles)
                max_particle_radius = math.max(max_particle_radius, radius, contour_radius)
                data[i + _radius_offset] = radius
                data[i + _contour_radius_offset] = contour_radius

                local mass = mass_easing(rope_node_i, n_particles)
                data[i + _mass_offset] = mass
                data[i + _inverse_mass_offset] = 1 / mass

                data[i + _opacity_offset] = opacity_easing(rope_node_i, n_particles)

                data[i + _segment_length_offset] = segment_length
                data[i + _contour_segment_length_offset] = contour_segment_length
                data[i + _collision_strength_offset] = collision_easing(rope_node_i, n_particles)

                if rope_node_i == n_particles then
                    max_particle_distance = math.max(max_particle_distance, math.distance(
                        anchor_x + dx * math.max(length, contour_length),
                        anchor_y + dy * math.max(length, contour_length),
                        0, 0
                    ))
                end

                data[i + _distance_lambda_offset] = 0
                data[i + _bending_lambda_offset] = 0
                data[i + _axis_lambda_offset] = 0

                x = x + dx * segment_length
                y = y + dy * segment_length
                particle_n = particle_n + 1
            end

            rope.end_i = particle_n - 1
            table.insert(self._ropes, rope)
        end

        local contour_max_length = rt.settings.player.radius * rt.settings.player.bubble_radius_factor

        do
            local n_rings = settings.n_rings
            local rope_r = settings.rope_radius
            for ring_i = 1, n_rings do
                local ring_t = (ring_i - 1) / n_rings
                local ring_r = (1 - ring_t) * body_radius / n_rings
                local n_ropes = math.max(3, math.ceil((2 * math.pi * ring_r) / rope_r))
                if n_ropes % 2 == 0 then n_ropes = n_ropes + 1 end
                local rope_length = fraction_to_rope_length(ring_t)
                local n_nodes = rope_length_to_n_nodes(rope_length)

                for rope_i = 1, n_ropes do
                    local angle = (rope_i - 1) / n_ropes * 2 * math.pi
                    local dx, dy = math.cos(angle), math.sin(angle)
                    local anchor_x, anchor_y = 0 + dx * ring_r, 0 + dy * ring_r
                    local contour_length = contour_max_length - math.magnitude(anchor_x, anchor_y) - contour_radius / 2
                    add_rope(
                        n_nodes,
                        rope_length, contour_length,
                        anchor_x, anchor_y,
                        dx, dy
                    )
                end
            end
        end

        self._n_particles = particle_n - 1
    end

    do -- render textures
        local texture_r = max_particle_distance
        local padding = max_particle_radius
        local texture_w = 2 * (texture_r + padding)
        local texture_h = texture_w

        self._body_render_texture = rt.RenderTexture(
            texture_w, texture_h,
            0,
            rt.TextureFormat.R32F
        )

        self._body_outline_render_texture = rt.RenderTexture(
            texture_w, texture_h
        )

        self._render_texture_needs_update = true
    end

    do -- instance mesh
        local x, y, r = 0, 0, 1
        local mesh = rt.Mesh({
            { x    , y    , 0.5, 0.5,  1, 1, 1, 1 },
            { x - r, y - r, 0.0, 0.0,  1, 1, 1, 1 },
            { x + r, y - r, 1.0, 0.0,  1, 1, 1, 1 },
            { x + r, y + r, 1.0, 1.0,  1, 1, 1, 1 },
            { x - r, y + r, 0.0, 1.0,  1, 1, 1, 1 }
        },
            rt.MeshDrawMode.TRIANGLES,
            rt.VertexFormat,
            rt.GraphicsBufferUsage.STATIC
        )

        mesh:set_vertex_map(
            1, 2, 3,
            1, 3, 4,
            1, 4, 5,
            1, 5, 2
        )
        mesh:set_texture(self._particle_texture)
        self._instance_mesh = mesh
    end

    do -- data mesh
        self._data_mesh_format = {
            { location = 3, name = "position", format = "floatvec4" }, -- xy: position, zw: previous position
            { location = 4, name = "velocity", format = "floatvec2" },
            { location = 5, name = "radius", format = "floatvec2" }, -- x: regular, y: contour
            { location = 6, name = "opacity", format = "float" }
        }

        self._particle_i_to_data_mesh_position = {}
        for i = 1, self._n_particles do
            self._particle_i_to_data_mesh_position[i] = i
        end

        -- sort so highest radius particles are drawn first
        table.sort(self._particle_i_to_data_mesh_position, function(a_i, b_i)
            local i1 = _particle_i_to_data_offset(a_i)
            local i2 = _particle_i_to_data_offset(b_i)

            return self._particle_data[i1 + _radius_offset] < self._particle_data[i2 + _radius_offset]
        end)

        self._data_mesh_data = {}
        local data = self._particle_data
        for particle_i = 1, self._n_particles do
            local mapped_i = self._particle_i_to_data_mesh_position[particle_i]
            local i = _particle_i_to_data_offset(mapped_i)
            table.insert(self._data_mesh_data, {
                data[i + _x_offset],
                data[i + _y_offset],
                data[i + _previous_x_offset],
                data[i + _previous_y_offset],
                data[i + _velocity_x_offset],
                data[i + _velocity_y_offset],
                data[i + _radius_offset],
                data[i + _contour_radius_offset],
                data[i + _opacity_offset]
            })
        end

        self._data_mesh = rt.Mesh(
            self._data_mesh_data,
            rt.MeshDrawMode.POINTS,
            self._data_mesh_format,
            rt.GraphicsBufferUsage.STREAM
        )

        for entry in values(self._data_mesh_format) do
            self._instance_mesh:attach_attribute(
                self._data_mesh,
                entry.name,
                rt.MeshAttributeAttachmentMode.PER_INSTANCE
            )
        end
    end
end

function rt.PlayerBody:set_colliding_lines(t)
    for entry in values(t) do
        assert(entry.contact_x ~= nil
            and entry.contact_y ~= nil
            and entry.x1 ~= nil
            and entry.y1 ~= nil
            and entry.x2 ~= nil
            and entry.y2 ~= nil
            and entry.normal_x ~= nil
            and entry.normal_y ~= nil
        )
    end

    self._colliding_lines = t or {}

    -- Allocate XPBD collision lambdas: [line_i][particle_i]
    self._collision_lambdas = {}
    local n_lines = #self._colliding_lines
    local n_particles = self._n_particles or 0
    for line_i = 1, n_lines do
        local row = {}
        for particle_i = 1, n_particles do
            row[particle_i] = 0.0
        end
        self._collision_lambdas[line_i] = row
    end
end

--- @brief
function rt.PlayerBody:_update_data_mesh()
    local from = self._particle_data
    for particle_i = 1, self._n_particles do
        local mapped_i = self._particle_i_to_data_mesh_position[particle_i]
        local to = self._data_mesh_data[mapped_i]
        local i = _particle_i_to_data_offset(mapped_i)
        to[1] = from[i + _x_offset]
        to[2] = from[i + _y_offset]
        to[3] = from[i + _previous_x_offset]
        to[4] = from[i + _previous_y_offset]
        to[5] = from[i + _velocity_x_offset]
        to[6] = from[i + _velocity_y_offset]
        to[7] = from[i + _radius_offset]
        to[8] = from[i + _contour_radius_offset]
        to[9] = from[i + _opacity_offset]
    end

    self._data_mesh:replace_data(self._data_mesh_data)
end

--- @brief
function rt.PlayerBody:relax()
    local data = self._particle_data
    local center_x, center_y = self._position_x, self._position_y
    for rope in values(self._ropes) do
        local dx, dy = rope.axis_x, rope.axis_y
        local x, y = center_x + rope.anchor_x, center_y + rope.anchor_y
        for particle_i = rope.start_i, rope.end_i do
            local i = _particle_i_to_data_offset(particle_i)
            data[i + _x_offset] = x
            data[i + _y_offset] = y

            local segment_length = data[i + _segment_length_offset]
            x = x + dx * segment_length
            y = y + dy * segment_length
        end
    end

    self:_update_data_mesh()
end

function rt.PlayerBody:update(delta)
    self:_step(delta)
end

do -- update helpers (XPBD with lambdas)
    local _pre_solve = function(
        particles, n_particles,
        gravity_x, gravity_y,
        damping, delta
    )
        for particle_i = 1, n_particles do
            local i = (particle_i - 1) * _stride + 1
            local x_i = i + _x_offset
            local y_i = i + _y_offset
            local velocity_x_i = i + _velocity_x_offset
            local velocity_y_i = i + _velocity_y_offset

            local x, y = particles[x_i], particles[y_i]

            particles[i + _previous_x_offset] = x
            particles[i + _previous_y_offset] = y

            local velocity_x = particles[velocity_x_i] * damping
            local velocity_y = particles[velocity_y_i] * damping

            local mass = particles[i + _mass_offset]
            velocity_x = velocity_x + mass * gravity_x * delta
            velocity_y = velocity_y + mass * gravity_y * delta

            particles[velocity_x_i] = velocity_x
            particles[velocity_y_i] = velocity_y

            particles[x_i] = x + delta * velocity_x
            particles[y_i] = y + delta * velocity_y

            -- reset lambdas
            particles[i + _distance_lambda_offset] = 0
            particles[i + _bending_lambda_offset] = 0
            particles[i + _axis_lambda_offset] = 0
        end
    end

    -- XPBD distance constraint between two particles (A,B)
    -- C = |b - a| - d0 = 0
    local function _enforce_distance_xpbd(
        ax, ay, bx, by,
        inv_mass_a, inv_mass_b,
        target_distance,
        alpha,         -- compliance (already scaled by sub_delta^2)
        lambda_prev    -- accumulated lambda for this constraint
    )
        local dx = bx - ax
        local dy = by - ay
        local len = math.sqrt(dx * dx + dy * dy)
        if len < math.eps then
            return 0, 0, 0, 0, lambda_prev
        end
        local nx = dx / len
        local ny = dy / len

        local C = len - target_distance
        local wsum = inv_mass_a + inv_mass_b
        local denom = wsum + alpha
        if denom < math.eps then
            return 0, 0, 0, 0, lambda_prev
        end

        local d_lambda = -(C + alpha * lambda_prev) / denom
        local lambda_new = lambda_prev + d_lambda

        -- x_i += w_i * d_lambda * gradC_i
        local axc = inv_mass_a * d_lambda * (-nx) -- grad_a = -n
        local ayc = inv_mass_a * d_lambda * (-ny)
        local bxc = inv_mass_b * d_lambda * ( nx) -- grad_b = +n
        local byc = inv_mass_b * d_lambda * ( ny)

        return axc, ayc, bxc, byc, lambda_new
    end

    -- XPBD bending as end-to-end AC distance equals target (sum of adjacent segment lengths)
    -- C = |c - a| - target_ac = 0
    local function _enforce_bending_xpbd(
        ax, ay, bx, by, cx, cy,  -- bx,by unused in gradient approx (kept for parity)
        inv_mass_a, inv_mass_b, inv_mass_c, -- inv_mass_b unused here
        target_ac_distance,
        alpha,
        lambda_prev
    )
        local dx = cx - ax
        local dy = cy - ay
        local len = math.sqrt(dx * dx + dy * dy)
        if len < math.eps then
            return 0, 0, 0, 0, 0, 0, lambda_prev
        end
        local nx = dx / len
        local ny = dy / len

        local C = len - target_ac_distance
        local wsum = inv_mass_a + inv_mass_c
        local denom = wsum + alpha
        if denom < math.eps then
            return 0, 0, 0, 0, 0, 0, lambda_prev
        end

        local d_lambda = -(C + alpha * lambda_prev) / denom
        local lambda_new = lambda_prev + d_lambda

        -- a += w_a * dλ * (-n); c += w_c * dλ * (n)
        local axc = inv_mass_a * d_lambda * (-nx)
        local ayc = inv_mass_a * d_lambda * (-ny)
        local cxc = inv_mass_c * d_lambda * ( nx)
        local cyc = inv_mass_c * d_lambda * ( ny)

        -- B gets no direct correction in this simplified bending constraint
        return axc, ayc, 0.0, 0.0, cxc, cyc, lambda_new
    end

    -- XPBD axis-alignment (1D scalar constraint: perpendicular projection to rotate segment towards axis)
    -- Let target axis unit be t = (tx,ty), perpendicular p = (-vy, vx) from current segment dir (with sign flip to avoid 180° flip).
    -- C = (b - (a + t * L)) · p = 0
    -- grad_a ≈ -p, grad_b ≈ p (treat p as constant - ignore derivative w.r.t positions)
    local function _enforce_axis_alignment_xpbd(
        ax, ay,
        bx, by,
        inv_mass_a, inv_mass_b,
        segment_length,
        tx, ty,
        alpha,
        lambda_prev
    )
        local vx = bx - ax
        local vy = by - ay
        local vlen = math.sqrt(vx * vx + vy * vy)
        if vlen < 1e-12 then
            return 0, 0, 0, 0, lambda_prev
        end
        vx = vx / vlen
        vy = vy / vlen

        -- choose orientation to avoid 180° ambiguity
        if vx * tx + vy * ty < 0 then
            vx = -vx
            vy = -vy
        end

        -- perpendicular to current segment
        local px = -vy
        local py =  vx

        -- desired endpoint for B along target axis
        local tbx = ax + tx * segment_length
        local tby = ay + ty * segment_length

        -- scalar error along perpendicular
        local ex = tbx - bx
        local ey = tby - by
        local C = ex * px + ey * py

        local wsum = inv_mass_a + inv_mass_b
        local denom = wsum + alpha
        if denom < math.eps then
            return 0, 0, 0, 0, lambda_prev
        end

        local d_lambda = -(C + alpha * lambda_prev) / denom
        local lambda_new = lambda_prev + d_lambda

        -- x_i += w_i * dλ * gradC_i; grad_a = -p, grad_b = p
        local axc = inv_mass_a * d_lambda * (-px)
        local ayc = inv_mass_a * d_lambda * (-py)
        local bxc = inv_mass_b * d_lambda * ( px)
        local byc = inv_mass_b * d_lambda * ( py)

        return axc, ayc, bxc, byc, lambda_new
    end

    -- XPBD line collision (inequality): C = n·(x - c) - r >= 0, λ >= 0
    local function _enforce_line_collision_xpbd(
        x, y, inv_mass,
        radius,
        line_contact_x, line_contact_y,
        line_normal_x, line_normal_y,
        alpha,
        lambda_prev
    )
        local nlen = math.sqrt(line_normal_x * line_normal_x + line_normal_y * line_normal_y)
        if nlen < math.eps then
            return 0.0, 0.0, lambda_prev
        end
        local nx = line_normal_x / nlen
        local ny = line_normal_y / nlen

        local rx = x - line_contact_x
        local ry = y - line_contact_y
        local s = rx * nx + ry * ny

        local C = s - radius
        -- inactive if satisfied; reset lambda to 0 to avoid stickiness
        if C >= 0.0 or inv_mass <= 0.0 then
            return 0.0, 0.0, 0.0
        end

        local denom = inv_mass + alpha
        if denom < math.eps then
            return 0.0, 0.0, lambda_prev
        end

        -- inequality complementarity: clamp λ >= 0
        local d_lambda = -(C + alpha * lambda_prev) / denom
        local lambda_new = lambda_prev + d_lambda
        if lambda_new < 0.0 then
            lambda_new = 0.0
        end
        d_lambda = lambda_new - lambda_prev

        -- x += w * dλ * n
        local dx = inv_mass * d_lambda * nx
        local dy = inv_mass * d_lambda * ny

        return dx, dy, lambda_new
    end

    local function _post_solve(particles, n_particles, delta)
        for particle_i = 1, n_particles do
            local i = (particle_i - 1) * _stride + 1

            local x = particles[i + _x_offset]
            local y = particles[i + _y_offset]

            local velocity_x = (x - particles[i + _previous_x_offset]) / delta
            local velocity_y = (y - particles[i + _previous_y_offset]) / delta
            particles[i + _velocity_x_offset] = velocity_x
            particles[i + _velocity_y_offset] = velocity_y
        end
    end

    -- PlayerBody:_step with XPBD lambdas
    function rt.PlayerBody:_step(delta)
        local settings = ternary(self._use_contour, rt.settings.player_body.contour, rt.settings.player_body.non_contour)
        local sub_delta = delta / settings.n_sub_steps

        local damping = settings.damping
        local n_sub_steps = settings.n_sub_steps
        local n_constraint_iterations = settings.n_constraint_iterations

        local distance_alpha = settings.distance_compliance / (sub_delta^2)
        local bending_alpha = settings.bending_compliance / (sub_delta^2)
        local axis_alpha = settings.axis_compliance / (sub_delta^2)
        local collision_alpha = settings.collision_compliance / (sub_delta^2)

        if self._use_contour then collision_alpha = 0.8 end -- override, this produces better deformation

        local data = self._particle_data
        local n_particles = self._n_particles

        local gravity_dx, gravity_dy = 0, 1
        local gravity = settings.gravity

        for _ = 1, n_sub_steps do
            _pre_solve(
                data, n_particles,
                gravity_dx * gravity, gravity_dy * gravity,
                damping,
                sub_delta
            )

            -- reset collision lambdas
            if self._collision_lambdas ~= nil then
                for line_i = 1, #self._collision_lambdas do
                    local row = self._collision_lambdas[line_i]
                    if row ~= nil then
                        for particle_i = 1, n_particles do
                            row[particle_i] = 0.0
                        end
                    end
                end
            end

            for _ = 1, n_constraint_iterations do
                for rope in values(self._ropes) do
                    local anchor_x = self._position_x + rope.anchor_x
                    local anchor_y = self._position_y + rope.anchor_y

                    -- pin first node to anchor each iteration
                    local anchor_i = _particle_i_to_data_offset(rope.start_i)
                    data[anchor_i + _x_offset] = anchor_x
                    data[anchor_i + _y_offset] = anchor_y

                    -- segment distance constraints (XPBD)
                    for node_i = rope.start_i, rope.end_i - 1, 1 do
                        local i1 = _particle_i_to_data_offset(node_i + 0)
                        local i2 = _particle_i_to_data_offset(node_i + 1)

                        local ax, ay = data[i1 + _x_offset], data[i1 + _y_offset]
                        local bx, by = data[i2 + _x_offset], data[i2 + _y_offset]

                        local inv_a = data[i1 + _inverse_mass_offset]
                        local inv_b = data[i2 + _inverse_mass_offset]

                        local segment_length
                        if not self._use_contour then
                            segment_length = data[i1 + _segment_length_offset]
                        else
                            segment_length = data[i1 + _contour_segment_length_offset]
                        end

                        local seg_j = node_i - rope.start_i + 1
                        local axc, ayc, bxc, byc, lambda_new = _enforce_distance_xpbd(
                            ax, ay, bx, by,
                            inv_a, inv_b,
                            segment_length,
                            distance_alpha,
                            data[i1 + _distance_lambda_offset]
                        )
                        data[i1 + _distance_lambda_offset] = lambda_new

                        data[i1 + _x_offset] = ax + axc
                        data[i1 + _y_offset] = ay + ayc
                        data[i2 + _x_offset] = bx + bxc
                        data[i2 + _y_offset] = by + byc
                    end

                    if not self._use_contour then goto next_rope end

                    -- bending constraints (XPBD)
                    for node_i = rope.start_i, rope.end_i - 2, 1 do
                        local i1 = _particle_i_to_data_offset(node_i + 0)
                        local i2 = _particle_i_to_data_offset(node_i + 1)
                        local i3 = _particle_i_to_data_offset(node_i + 2)

                        local ax, ay = data[i1 + _x_offset], data[i1 + _y_offset]
                        local bx, by = data[i2 + _x_offset], data[i2 + _y_offset]
                        local cx, cy = data[i3 + _x_offset], data[i3 + _y_offset]

                        local wa = data[i1 + _inverse_mass_offset]
                        local wb = data[i2 + _inverse_mass_offset]
                        local wc = data[i3 + _inverse_mass_offset]

                        local segment_length_ab = data[i1 + _segment_length_offset]
                        local segment_length_bc = data[i2 + _segment_length_offset]
                        local target_length = segment_length_ab + segment_length_bc

                        local bend_j = node_i - rope.start_i + 1
                        local axc, ayc, _, _, cxc, cyc, lambda_new = _enforce_bending_xpbd(
                            ax, ay, bx, by, cx, cy,
                            wa, wb, wc,
                            target_length,
                            bending_alpha,
                            data[i1 + _bending_lambda_offset]
                        )
                        data[i1 + _bending_lambda_offset] = lambda_new

                        data[i1 + _x_offset] = ax + axc
                        data[i1 + _y_offset] = ay + ayc
                        data[i3 + _x_offset] = cx + cxc
                        data[i3 + _y_offset] = cy + cyc
                    end

                    -- axis alignment (XPBD, IK-like)
                    for node_i = rope.start_i, rope.end_i - 1 do
                        local i1 = _particle_i_to_data_offset(node_i)
                        local i2 = _particle_i_to_data_offset(node_i + 1)

                        local ax = data[i1 + _x_offset]
                        local ay = data[i1 + _y_offset]
                        local bx = data[i2 + _x_offset]
                        local by = data[i2 + _y_offset]

                        local wa = data[i1 + _inverse_mass_offset]
                        local wb = data[i2 + _inverse_mass_offset]

                        local segment_length = data[i1 + _segment_length_offset]

                        local axis_j = node_i - rope.start_i + 1
                        local axc, ayc, bxc, byc, lambda_new = _enforce_axis_alignment_xpbd(
                            ax, ay, bx, by,
                            wa, wb,
                            segment_length,
                            rope.axis_x, rope.axis_y,
                            axis_alpha,
                            data[i1 + _axis_lambda_offset]
                        )
                        data[i1 + _axis_lambda_offset] = lambda_new

                        data[i1 + _x_offset] = ax + axc
                        data[i1 + _y_offset] = ay + ayc
                        data[i2 + _x_offset] = bx + bxc
                        data[i2 + _y_offset] = by + byc
                    end

                    ::next_rope::
                end

                -- collisions (XPBD inequality per line, per particle)
                for li, line in ipairs(self._colliding_lines or {}) do
                    local row = self._collision_lambdas and self._collision_lambdas[li]
                    for particle_i = 1, self._n_particles do
                        local i = _particle_i_to_data_offset(particle_i)

                        local radius = self._use_contour
                            and data[i + _contour_radius_offset]
                            or  data[i + _radius_offset]

                        local alpha_multiplier = data[i + _collision_strength_offset]
                        if alpha_multiplier > 0 then
                            local cx, cy, lambda_new = _enforce_line_collision_xpbd(
                                data[i + _x_offset],
                                data[i + _y_offset],
                                data[i + _inverse_mass_offset],
                                radius,
                                line.contact_x,
                                line.contact_y,
                                line.normal_x,
                                line.normal_y,
                                collision_alpha * (1 - alpha_multiplier),
                                row and row[particle_i] or 0.0
                            )

                            data[i + _x_offset] = data[i + _x_offset] + cx
                            data[i + _y_offset] = data[i + _y_offset] + cy

                            if row ~= nil then
                                row[particle_i] = lambda_new
                            end
                        end
                    end
                end
            end -- constraint iterations

            _post_solve(
                data, n_particles,
                sub_delta
            )
        end -- n sub steps

        self:_update_data_mesh()
        self._render_texture_needs_update = true
    end
end

--- @brief
function rt.PlayerBody:set_stencil_bodies(t)
    self._stencil_bodies = t
end

--- @brief
function rt.PlayerBody:draw_body()
    if self._render_texture_needs_update then
        love.graphics.push("all")
        love.graphics.reset()
        love.graphics.setBlendMode("add", "premultiplied")

        local texture_w, texture_h = self._body_render_texture:get_size()
        love.graphics.translate(
            -1 * self._position_x + 0.5 * texture_w,
            -1 * self._position_y + 0.5 * texture_h
        )
        self._body_render_texture:bind()
        love.graphics.clear(0, 0, 1, 0)

        local stencil_value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
        for body in values(self._stencil_bodies) do
            body:draw(true) -- mask only
        end
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

        rt.Palette.TRUE_WHITE:bind()
        _instance_draw_shader:bind()
        _instance_draw_shader:send("texture_scale", rt.settings.player_body.particle_texture_scale)
        _instance_draw_shader:send("interpolation_alpha", 1)
        _instance_draw_shader:send("use_contour", self._use_contour)
        self._instance_mesh:draw_instanced(self._n_particles)
        _instance_draw_shader:unbind()

        rt.graphics.set_stencil_mode(nil)

        self._body_render_texture:unbind()
        love.graphics.pop()

        -- threshold for outline
        love.graphics.push("all")
        love.graphics.reset()
        self._body_outline_render_texture:bind()
        love.graphics.clear(0, 0, 0, 0)
        _threshold_shader:bind()
        _threshold_shader:send("threshold", ternary(self._use_contour, rt.settings.player_body.contour_threshold, rt.settings.player_body.threshold))
        self._body_render_texture:draw()
        _threshold_shader:unbind()
        self._body_outline_render_texture:unbind()
        love.graphics.pop()
    end

    love.graphics.push()
    local texture_w, texture_h = self._body_render_texture:get_size()
    love.graphics.translate(self._position_x - 0.5 * texture_w, self._position_y - 0.5 * texture_w)
    _outline_shader:send("body_color", { self._body_color:unpack() })
    _outline_shader:send("outline_color", { self._core_color:unpack() })
    _outline_shader:bind()
    self._body_outline_render_texture:draw()
    _outline_shader:unbind()
    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:draw_core()
    if self._core_vertices == nil then return end

    love.graphics.push()
    self._core_color:bind()

    love.graphics.translate(self._position_x, self._position_y)

    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(rt.settings.player_body.core_outline_width * 2)
    love.graphics.line(self._core_vertices)

    _core_shader:bind()
    _core_shader:send("hue", self._hue)
    _core_shader:send("elapsed", rt.SceneManager:get_elapsed())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon("fill", self._core_vertices)
    _core_shader:unbind()

    love.graphics.pop()

    for line in values(self._colliding_lines) do
        local left_x, left_y = math.turn_left(line.normal_x, line.normal_y)
        local right_x, right_y = math.turn_right(line.normal_x, line.normal_y)
        love.graphics.line(
            line.contact_x + left_x * 100,
            line.contact_y + left_y * 100,
            line.contact_x + right_x * 100,
            line.contact_y + right_y * 100
        )
    end
end

--- @brief
function rt.PlayerBody:set_position(x, y)
    self._position_x = x
    self._position_y = y
end

--- @brief
function rt.PlayerBody:set_shape(positions)
    self._core_vertices = positions
end

rt.PlayerBody.update_rope = function(data)

end

--- @brief
function rt.PlayerBody:set_color(color)
    meta.assert(color, rt.RGBA)
    self._core_color = color
    self._hue = select(3, rt.rgba_to_lcha(self._core_color:unpack()))
end

--- @brief
function rt.PlayerBody:set_body_color(color)
    meta.assert(color, rt.RGBA)
    self._body_color = color
end

--- @brief
function rt.PlayerBody:set_core_color(color)

end

--- @brief
function rt.PlayerBody:set_opacity(opacity)

end

--- @brief
function rt.PlayerBody:set_use_contour(b)
    self._use_contour = b
end

--- @brief
function rt.PlayerBody:draw_bloom()
    if self._core_vertices == nil then return end

    love.graphics.push()
    self._core_color:bind()

    love.graphics.translate(self._position_x, self._position_y)

    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(rt.settings.player_body.core_outline_width * 2)
    love.graphics.line(self._core_vertices)

    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:set_relative_velocity(vx, vy)

end

--- @brief
function rt.PlayerBody:set_down_squish(b, nx, ny, contact_x, contact_y)

end

--- @brief
function rt.PlayerBody:set_left_squish(b, nx, ny, contact_x, contact_y)

end

--- @brief
function rt.PlayerBody:set_right_squish(b, nx, ny, contact_x, contact_y)

end

--- @brief
function rt.PlayerBody:set_up_squish(b, nx, ny, contact_x, contact_y)

end

--- @brief
function rt.PlayerBody:set_gravity(gravity_x, gravity_y)
    self._gravity_x, self._gravity_y = gravity_x, gravity_y -- can be nil
end

--- @brief
function rt.PlayerBody:set_saturation(t)
    self._saturation = t
end

--- @brief
function rt.PlayerBody:get_saturation()
    return self._saturation
end

--- @brief
function rt.PlayerBody:set_world(physics_world)
end

--- @brief
function rt.PlayerBody:set_use_stencils(b)
end