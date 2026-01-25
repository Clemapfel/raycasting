require "common.smoothed_motion_1d"

rt.settings.player_body = {
    canvas_scale = 3,
    outline_darkening = 0.5,

    particle_texture_scale = 1,
    core_outline_width = 2,

    contour_threshold = 0.05,
    threshold = 0.4,

    texture_scale = 2,

    particle_texture_radius_factor = 1,
    contour_radius_factor = 2,

    n_rings = 4,
    rope_radius = 3,
    max_rope_length = 56,

    contour_inflation_speed = 2, -- fraction
    contour_deflation_speed = 1, -- fraction
    squish_speed = 4, -- fraction
    squish_magnitude = 0.16, -- fraction

    relative_velocity_influence = 1 / 3, -- [0, 1] where 0 no influence

    non_contour = {
        n_sub_steps = 2,
        n_constraint_iterations = 5,
        damping = 1 - 0.2,

        distance_compliance = 0,
        bending_compliance = 1,
        axis_compliance = 1,
        collision_compliance = 0.05,

        gravity = 500
    },

    contour = {
        n_sub_steps = 2,
        n_constraint_iterations = 5,
        damping = 1 - 0.2,

        distance_compliance = 0,
        bending_compliance = 1,
        axis_compliance = 0,
        collision_compliance = 0.05,

        gravity = 0
    }
}

--- @class rt.PlayerBody
rt.PlayerBody = meta.class("PlayerBody")

local _particle_texture_shader = rt.Shader("common/player_body_particle_texture.glsl")
local _instance_draw_shader = rt.Shader("common/player_body_instanced_draw.glsl")
local _threshold_shader = rt.Shader("common/player_body_threshold.glsl")
local _outline_shader = rt.Shader("common/player_body_outline.glsl")
local _core_shader = rt.Shader("common/player_body_core.glsl")

--- @brief
function rt.PlayerBody:instantiate(position_x, position_y)
    meta.assert(position_x, "Number", position_y, "Number")
    self._position_x = position_x
    self._position_y = position_y
    self._relative_velocity_x = 0
    self._relative_velocity_y = 0

    self._core_vertices = nil
    self._core_outline_scale = 1
    self._core_color = rt.Palette.WHITE
    self._body_color = rt.Palette.BLACK
    self._opacity = 1
    self._saturation = 1

    local squish_speed = rt.settings.player_body.squish_speed

    self._down_squish = false
    self._down_squish_normal_x = nil
    self._down_squish_normal_y = nil
    self._down_squish_origin_x = nil
    self._down_squish_normal_y = nil
    self._down_squish_motion = rt.SmoothedMotion1D(1, squish_speed)

    self._left_squish = false
    self._left_squish_normal_x = nil
    self._left_squish_normal_y = nil
    self._left_squish_origin_x = nil
    self._left_squish_normal_y = nil
    self._left_squish_motion = rt.SmoothedMotion1D(1, squish_speed)

    self._right_squish = false
    self._right_squish_normal_x = nil
    self._right_squish_normal_y = nil
    self._right_squish_origin_x = nil
    self._right_squish_normal_y = nil
    self._right_squish_motion = rt.SmoothedMotion1D(1, squish_speed)

    self._up_squish = false
    self._up_squish_normal_x = nil
    self._up_squish_normal_y = nil
    self._up_squish_origin_x = nil
    self._up_squish_normal_y = nil
    self._up_squish_motion = rt.SmoothedMotion1D(1, squish_speed)

    self._stencil_bodies = {}
    self._use_contour = true
    self._contour_transition_motion = rt.SmoothedMotion1D(0)
    self._contour_transition_motion:set_speed(
        rt.settings.player_body.contour_inflation_speed,
        rt.settings.player_body.contour_deflation_speed
    )
    
    self._particle_data = {}
    self._ropes = {}
    self._n_particles = 0
    
    self._colliding_lines = {} -- Table<Tuple<4>>
    self._colliding_lines_to_lambda = {}
    
    self._particle_texture_radius = nil -- Number
    self._particle_texture = nil -- rt.RenderTexture
    
    self._body_texture = nil -- rt.RenderTexture
    self._body_outline_texture = nil -- rt.RenderTexture
    self._render_texture_needs_update = false
    
    self._instance_mesh = nil -- rt.Mesh
    self._data_mesh_format = nil -- cf. _initialize
    self._data_mesh_data = {}
    self._data_mesh = nil -- rt.Mesh
    
    self._particle_i_to_data_mesh_position = {}


    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            for shader in range(_particle_texture_shader, _instance_draw_shader, _threshold_shader, _outline_shader, _core_shader) do
                shader:recompile()
            end
            self:_initialize()
        end
    end)
    
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

--- @brief
function rt.PlayerBody:_initialize()
    local settings = rt.settings.player_body

    self._particle_data = {}
    self._ropes = {}

    local particle_texture_radius = rt.settings.player_body.particle_texture_radius * rt.settings.player.radius - 1
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

    local body_radius = rt.settings.player.radius
    local max_rope_length = rt.settings.player_body.max_rope_length


    local max_particle_distance = -math.huge
    local max_particle_radius = -math.huge

    local radius_easing = function(i, n)
        -- don't ask
        local t = ((i - 1) / n)
        local function f(x) return (1 - x) * math.exp(-x^2) end
        local sqrt3 = math.sqrt(3)
        local result = 1 + math.exp(-t^2) * f((0.5 * (1 + sqrt3) * t) + (0.5 - (sqrt3 / 2)))
        return 1 / math.sqrt(2) * result
    end

    local contour_radius = settings.contour_radius_factor * particle_texture_radius

    local collision_easing = function(i, n)
        return ((i - 1) / n)
    end

    local opacity_easing = function(i, n)
        return (1 - ((i - 1) / n))
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
        self._particle_data = {}

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

                local radius = particle_texture_radius * radius_easing(rope_node_i, n_particles)
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
            local max_length = -math.huge
            for ring_i = 1, n_rings do
                local ring_t = (ring_i - 1) / n_rings
                local ring_r = (1 - ring_t) * body_radius / n_rings
                local n_ropes = math.max(3, math.ceil((2 * math.pi * ring_r) / rope_r))
                if n_ropes % 2 == 0 then n_ropes = n_ropes + 1 end
                local rope_length = fraction_to_rope_length(ring_t)
                max_length = math.max(max_length, rope_length)

                local n_nodes = rope_length_to_n_nodes(rope_length)

                -- Calculate total radius contribution for this rope
                local total_radius = 0
                for node_i = 1, n_nodes do
                    local radius = particle_texture_radius * radius_easing(node_i, n_nodes)
                    total_radius = total_radius + radius
                end

                for rope_i = 1, n_ropes do
                    local angle = (rope_i - 1) / n_ropes * 2 * math.pi
                    local dx, dy = math.cos(angle), math.sin(angle)
                    local anchor_x, anchor_y = 0 + dx * ring_r, 0 + dy * ring_r
                    local contour_length = contour_max_length - total_radius - math.magnitude(anchor_x, anchor_y)

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
        local texture_scale = settings.texture_scale

        local texture_r = max_particle_distance
        local padding = max_particle_radius
        local texture_w = 2 * (texture_r + padding) * texture_scale
        local texture_h = texture_w

        self._body_texture = rt.RenderTexture(
            texture_w, texture_h,
            0,
            rt.TextureFormat.R32F
        )

        self._body_outline_texture = rt.RenderTexture(
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
            { location = 3, name = "position", format = "floatvec2" }, -- xy: position
            { location = 4, name = "radius", format = "floatvec2" }, -- x: regular, y: contour
            { location = 5, name = "opacity", format = "float" }
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
    self._colliding_lines_to_lambda = {}
    local n_lines = #self._colliding_lines
    local n_particles = self._n_particles or 0
    for line_i = 1, n_lines do
        local row = {}
        for particle_i = 1, n_particles do
            row[particle_i] = 0.0
        end
        self._colliding_lines_to_lambda[line_i] = row
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
        to[3] = from[i + _radius_offset]
        to[4] = from[i + _contour_radius_offset]
        to[5] = from[i + _opacity_offset]
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
            data[i + _previous_x_offset] = x
            data[i + _previous_y_offset] = y
            data[i + _velocity_x_offset] = 0
            data[i + _velocity_y_offset] = 0

            if self._use_contour then
                local segment_length = data[i + _segment_length_offset]
                x = x + dx * segment_length
                y = y + dy * segment_length
            end

        end
    end

    self._render_texture_needs_update = true
end

function rt.PlayerBody:update(delta)
    self:_step(delta)

    self._contour_transition_motion:update(delta)
end

do -- update helpers (XPBD with lambdas)
    local _pre_solve = function(
        particles, n_particles,
        gravity_x, gravity_y,
        relative_velocity_x, relative_velocity_y,
        damping, delta
    )
        for particle_i = 1, n_particles do
            local i = (particle_i - 1) * _stride + 1
            local x_i = i + _x_offset
            local y_i = i + _y_offset
            local velocity_x_i = i + _velocity_x_offset
            local velocity_y_i = i + _velocity_y_offset

            local x = particles[x_i]
            local y = particles[y_i]

            -- store previous world positions for velocity update in post-solve
            particles[i + _previous_x_offset] = x
            particles[i + _previous_y_offset] = y

            -- world velocity from previous step
            local vwx = particles[velocity_x_i]
            local vwy = particles[velocity_y_i]

            -- convert to frame-relative before damping so the frame motion is not damped
            local vrx = (vwx - relative_velocity_x) * damping
            local vry = (vwy - relative_velocity_y) * damping

            -- integrate external acceleration (gravity); y-down so positive gravity_y accelerates downward
            local mass = particles[i + _mass_offset]
            vrx = vrx + mass * gravity_x * delta
            vry = vry + mass * gravity_y * delta

            -- convert back to world velocity for advection and storage
            local vwx_new = vrx + relative_velocity_x
            local vwy_new = vry + relative_velocity_y

            particles[velocity_x_i] = vwx_new
            particles[velocity_y_i] = vwy_new

            -- predict positions in world space (advected by frame)
            particles[x_i] = x + vwx_new * delta
            particles[y_i] = y + vwy_new * delta

            -- reset XPBD lambdas per particle
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

        local t = 1 - math.clamp(rt.settings.player_body.relative_velocity_influence, 0, 1)
        local relative_velocity_x, relative_velocity_y = t * self._relative_velocity_x, t * self._relative_velocity_y

        for _ = 1, n_sub_steps do
            _pre_solve(
                data, n_particles,
                gravity_dx * gravity, gravity_dy * gravity,
                relative_velocity_x, relative_velocity_y,
                damping,
                sub_delta
            )

            -- reset collision lambdas
            if self._colliding_lines_to_lambda ~= nil then
                for line_i = 1, #self._colliding_lines_to_lambda do
                    local row = self._colliding_lines_to_lambda[line_i]
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
                    local row = self._colliding_lines_to_lambda and self._colliding_lines_to_lambda[li]
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

        self._render_texture_needs_update = true
    end

    -- export for other classes to use
    rt.PlayerBody._enforce_distance = _enforce_distance_xpbd
    rt.PlayerBody._enforce_axis_alignment = _enforce_axis_alignment_xpbd
    rt.PlayerBody._enforce_bending = _enforce_bending_xpbd
    rt.PlayerBody._enforce_line_collision_xpbd = _enforce_line_collision_xpbd
end

--- @brief
function rt.PlayerBody:set_stencil_bodies(t)
    self._stencil_bodies = t
end

--- @brief
function rt.PlayerBody:_apply_squish()
    if self._use_contour then return end

    local magnitude = rt.settings.player_body.squish_magnitude
    local radius = rt.settings.player.radius

    local function apply(is_enabled, motion, nx, ny, ox, oy, default_nx, default_ny, default_ox, default_oy)
        if not is_enabled or motion == nil or motion.get_value == nil then return end
        local amount = motion:get_value()
        if amount <= 0 then return end

        -- pick fallbacks if values aren't provided yet
        local squish_nx = nx or default_nx
        local squish_ny = ny or default_ny
        local origin_x = ox or default_ox
        local origin_y = oy or default_oy

        -- normalize normal to avoid scaling artifacts
        local nlen = math.sqrt((squish_nx or 0)^2 + (squish_ny or 0)^2)
        if nlen < 1e-6 then return end
        squish_nx, squish_ny = squish_nx / nlen, squish_ny / nlen

        -- rotate so x-axis aligns with normal, scale x only (compress along normal),
        -- then rotate back, around the contact point in world-space.
        local angle = math.angle(squish_nx, squish_ny)
        local sx = 1 - magnitude * amount
        -- avoid flipping or killing the object entirely

        love.graphics.translate(origin_x, origin_y)
        love.graphics.rotate(angle)
        love.graphics.scale(sx, 1)
        love.graphics.rotate(-angle)
        love.graphics.translate(-origin_x, -origin_y)
    end

    -- Down (floor)
    apply(
        self._down_squish,
        self._down_squish_motion,
        self._down_squish_normal_x, self._down_squish_normal_y,
        self._down_squish_origin_x, self._down_squish_origin_y,
        0, -1,
        self._position_x, self._position_y + 0.5 * radius
    )

    -- Left (left wall)
    apply(
        self._left_squish,
        self._left_squish_motion,
        self._left_squish_normal_x, self._left_squish_normal_y,
        self._left_squish_origin_x, self._left_squish_origin_y,
        1, 0,
        self._position_x - 0.5 * radius, self._position_y
    )

    -- Right (right wall)
    apply(
        self._right_squish,
        self._right_squish_motion,
        self._right_squish_normal_x, self._right_squish_normal_y,
        self._right_squish_origin_x, self._right_squish_origin_y,
        -1, 0,
        self._position_x + 0.5 * radius, self._position_y
    )

    -- Up (ceiling)
    apply(
        self._up_squish,
        self._up_squish_motion,
        self._up_squish_normal_x, self._up_squish_normal_y,
        self._up_squish_origin_x, self._up_squish_origin_y,
        0, 1,
        self._position_x, self._position_y - 0.5 * radius
    )
end

--- @brief
function rt.PlayerBody:draw_body()
    if self._render_texture_needs_update then
        self:_update_data_mesh()

        love.graphics.push("all")
        love.graphics.reset()
        love.graphics.setBlendMode("add", "premultiplied")

        local w, h = self._body_texture:get_size()
        local texture_scale = rt.settings.player_body.texture_scale
        love.graphics.translate(0.5 * w, 0.5 * h)
        love.graphics.scale(texture_scale, texture_scale)
        love.graphics.translate(-0.5 * w, -0.5 * h)

        love.graphics.translate(
            -1 * self._position_x + 0.5 * w,
            -1 * self._position_y + 0.5 * h
        )
        self._body_texture:bind()
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
        _instance_draw_shader:send("contour_interpolation_factor", self._contour_transition_motion:get_value())
        self._instance_mesh:draw_instanced(self._n_particles)
        _instance_draw_shader:unbind()

        rt.graphics.set_stencil_mode(nil)

        self._body_texture:unbind()
        love.graphics.pop()

        -- threshold for outline
        love.graphics.push("all")
        love.graphics.reset()
        self._body_outline_texture:bind()
        love.graphics.clear(0, 0, 0, 0)
        _threshold_shader:bind()
        _threshold_shader:send("threshold", ternary(self._use_contour, rt.settings.player_body.contour_threshold, rt.settings.player_body.threshold))
        self._body_texture:draw()
        _threshold_shader:unbind()
        self._body_outline_texture:unbind()
        love.graphics.pop()
    end

    love.graphics.push()
    local w, h = self._body_texture:get_size()
    local texture_scale = rt.settings.player_body.texture_scale
    self:_apply_squish()

    love.graphics.translate(self._position_x - 0.5 * w, self._position_y - 0.5 * w)
    love.graphics.translate(0.5 * w, 0.5 * h)
    love.graphics.scale(1 / texture_scale, 1 / texture_scale)
    love.graphics.translate(-0.5 * w, -0.5 * h)

    local body_r, body_g, body_b, body_a = self._body_color:unpack()
    local outline_r, outline_g, outline_b, outline_a = self._core_color:unpack()
    _outline_shader:send("body_color", { body_r, body_g, body_b, body_a * self._opacity })
    _outline_shader:send("outline_color", { outline_r, outline_g, outline_b, outline_a * self._opacity })
    _outline_shader:bind()
    self._body_outline_texture:draw()
    _outline_shader:unbind()
    love.graphics.pop()
end

--- @brief
-- Ensure core is squished as well (call before translating to the player's local space).
function rt.PlayerBody:draw_core()
    if self._core_vertices == nil then return end

    love.graphics.push()
    self:_apply_squish()

    local core_r, core_g, core_b, core_a = self._core_color:unpack()

    love.graphics.translate(self._position_x, self._position_y)

    love.graphics.push()
    love.graphics.scale(self._core_outline_scale, self._core_outline_scale)
    love.graphics.setColor(core_r, core_g, core_b, core_a * self._opacity)
    love.graphics.polygon("fill", self._core_vertices)
    love.graphics.pop()

    _core_shader:bind()
    _core_shader:send("hue", self._hue)
    _core_shader:send("elapsed", rt.SceneManager:get_elapsed())
    _core_shader:send("saturation", self._saturation)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.polygon("fill", self._core_vertices)
    _core_shader:unbind()

    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:set_position(x, y)
    self._position_x = x
    self._position_y = y
end

function rt.PlayerBody:set_shape(positions)
    self._core_vertices = positions
    local max_r = -math.huge
    for i = 1, #positions, 2 do
        max_r = math.max(max_r, math.distance(positions[i+0], positions[i+1], 0, 0))
    end

    local outline_width = rt.settings.player_body.core_outline_width
    self._core_outline_scale = 1 + (outline_width / max_r)
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
    self._core_color = color
end

--- @brief
function rt.PlayerBody:set_opacity(opacity)
    self._opacity = opacity
end

--- @brief
function rt.PlayerBody:set_use_contour(b)
    self._use_contour = b
    self._contour_transition_motion:set_target_value(ternary(b, 1, 0))
end

--- @brief
function rt.PlayerBody:draw_bloom()
    if self._core_vertices == nil then return end

    love.graphics.push()
    local w, h = self._body_texture:get_size()
    local texture_scale = rt.settings.player_body.texture_scale
    love.graphics.translate(self._position_x - 0.5 * w, self._position_y - 0.5 * w)
    love.graphics.translate(0.5 * w, 0.5 * h)
    love.graphics.scale(1 / texture_scale, 1 / texture_scale)
    love.graphics.translate(-0.5 * w, -0.5 * h)
    _outline_shader:send("body_color", { 0, 0, 0, 0 })
    _outline_shader:send("outline_color", { self._core_color:unpack() })
    _outline_shader:bind()
    self._body_outline_texture:draw()
    _outline_shader:unbind()
    love.graphics.pop()
end

--- @brief
function rt.PlayerBody:set_relative_velocity(vx, vy)
    self._relative_velocity_x = vx
    self._relative_velocity_y = vy
end

--- @brief
function rt.PlayerBody:set_down_squish(b, nx, ny, contact_x, contact_y)
    self._down_squish = b
    self._down_squish_normal_x = nx or self._down_squish_normal_x
    self._down_squish_normal_y = ny or self._down_squish_normal_y
    self._down_squish_origin_x = contact_x or self._down_squish_origin_x
    self._down_squish_origin_y = contact_y or self._down_squish_origin_y

    if b == true then
        self._down_squish_motion:set_target_value(1)
    else
        self._down_squish_motion:set_target_value(0)
    end
end

--- @brief
function rt.PlayerBody:set_left_squish(b, nx, ny, contact_x, contact_y)
    self._left_squish = b
    self._left_squish_normal_x = nx or self._left_squish_normal_x
    self._left_squish_normal_y = ny or self._left_squish_normal_y
    self._left_squish_origin_x = contact_x or self._left_squish_origin_x
    self._left_squish_origin_y = contact_y or self._left_squish_origin_y

    if b == true then
        self._left_squish_motion:set_target_value(1)
    else
        self._left_squish_motion:set_target_value(0)
    end
end

--- @brief
function rt.PlayerBody:set_right_squish(b, nx, ny, contact_x, contact_y)
    self._right_squish = b
    self._right_squish_normal_x = nx or self._right_squish_normal_x
    self._right_squish_normal_y = ny or self._right_squish_normal_y
    self._right_squish_origin_x = contact_x or self._right_squish_origin_x
    self._right_squish_origin_y = contact_y or self._right_squish_origin_y

    if b == true then
        self._right_squish_motion:set_target_value(1)
    else
        self._right_squish_motion:set_target_value(0)
    end
end

--- @brief
function rt.PlayerBody:set_up_squish(b, nx, ny, contact_x, contact_y)
    self._up_squish = b
    self._up_squish_normal_x = nx or self._up_squish_normal_x
    self._up_squish_normal_y = ny or self._up_squish_normal_y
    self._up_squish_origin_x = contact_x or self._up_squish_origin_x
    self._up_squish_origin_y = contact_y or self._up_squish_origin_y

    if b == true then
        self._up_squish_motion:set_target_value(1)
    else
        self._up_squish_motion:set_target_value(0)
    end
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
