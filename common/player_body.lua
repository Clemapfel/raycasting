require "common.smoothed_motion_1d"

rt.settings.player_body = {
    canvas_scale = 3,
    outline_darkening = 0.5,

    particle_texture_scale = 1,
    core_outline_width = 2,

    contour_threshold = 0.05,
    threshold = 0.4,

    texture_scale = 4,

    particle_texture_radius_factor = 1,
    contour_radius_factor = 1,

    n_rings = 4,
    rope_radius = 3,
    max_rope_length = 56,

    contour_inflation_speed = 2, -- fraction
    contour_deflation_speed = 1, -- fraction
    squish_speed = 2, -- fraction
    squish_magnitude = 0.2, -- fraction

    relative_velocity_influence = 1 / 3, -- [0, 1] where 0 no influence

    non_contour = {
        n_sub_steps = 2,
        n_constraint_iterations = 5,
        damping = 1 - 0.2,

        distance_compliance = 0,
        bending_compliance = 1,
        axis_compliance = 1,
        collision_compliance = 0.025,

        gravity = 500
    },

    contour = {
        n_sub_steps = 2,
        n_constraint_iterations = 4,
        bending_compliance = 1,
        axis_compliance = 1,
        distance_compliance = 1e-5,
        collision_compliance = 0.0005,

        damping = 1 - 0.2,

        gravity = 0
    }
}

setmetatable(rt.settings.player_body.contour, {
    __index = function(self, k, v)
        return debugger.get(k) or rawget(rt.settings.player_body.non_contour, k, v)
    end
})

--- @class rt.PlayerBody
rt.PlayerBody = meta.class("PlayerBody")

local _particle_texture_shader = rt.Shader("common/player_body_particle_texture.glsl")
local _instance_draw_shader = rt.Shader("common/player_body_instanced_draw.glsl")
local _threshold_shader = rt.Shader("common/player_body_threshold.glsl")
local _outline_shader = rt.Shader("common/player_body_outline.glsl")
local _core_shader = rt.Shader("common/player_body_core.glsl")

local _squished = 1
local _not_squished = 0

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
    self._down_squish_motion = rt.SmoothedMotion1D(_not_squished, squish_speed)

    self._left_squish = false
    self._left_squish_normal_x = nil
    self._left_squish_normal_y = nil
    self._left_squish_origin_x = nil
    self._left_squish_normal_y = nil
    self._left_squish_motion = rt.SmoothedMotion1D(_not_squished, squish_speed)

    self._right_squish = false
    self._right_squish_normal_x = nil
    self._right_squish_normal_y = nil
    self._right_squish_origin_x = nil
    self._right_squish_normal_y = nil
    self._right_squish_motion = rt.SmoothedMotion1D(_not_squished, squish_speed)

    self._up_squish = false
    self._up_squish_normal_x = nil
    self._up_squish_normal_y = nil
    self._up_squish_origin_x = nil
    self._up_squish_normal_y = nil
    self._up_squish_motion = rt.SmoothedMotion1D(_not_squished, squish_speed)

    self._body_stencil_bodies = {}
    self._core_stencil_bodies = {}
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
    self:_initialize()
end

local _x_offset = 0
local _y_offset = 1
local _previous_x_offset = 2 -- last sub step
local _previous_y_offset = 3
local _velocity_x_offset = 4
local _velocity_y_offset = 5
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

    local particle_texture_radius = rt.settings.player_body.particle_texture_radius_factor * rt.settings.player.radius - 1
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

    local contour_radius = rt.settings.player.radius * rt.settings.player.bubble_radius_factor

    local collision_easing = function(i, n)
        local progress = (i - 1) / n
        local t = 0.25

        if progress <= t then
            return 0
        end

        -- 0 until start of tail, analytically smooth transition to 1
        local x = (progress - t) / (1 - t)
        return x * x * (3 - 2 * x)
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

        for texture in range(self._body_texture, self._body_outline_texture) do
            texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
        end

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
            { location = 3, name = "position", format = "floatvec2" },
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
            data[i + _distance_lambda_offset] = 0
            data[i + _bending_lambda_offset] = 0
            data[i + _axis_lambda_offset] = 0

            if self._use_contour then
                -- if contour, align with axis, else keep at rope origin
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

    for motion in range(
        self._down_squish_motion,
        self._right_squish_motion,
        self._up_squish_motion,
        self._left_squish_motion,
        self._contour_transition_motion
    ) do
        motion:update(delta)
    end
end

do -- update helpers (XPBD with lambdas)
    local function _pre_solve(
        position_x, position_y,
        velocity_x, velocity_y,
        mass,
        gravity_x, gravity_y,
        relative_velocity_x, relative_velocity_y,
        damping, delta
    )
        -- store previous world positions for velocity update in post-solve
        local previous_x = position_x
        local previous_y = position_y

        -- world velocity from previous step
        local world_velocity_x = velocity_x
        local world_velocity_y = velocity_y

        -- convert to frame-relative before damping so the frame motion is not damped
        local relative_x = (world_velocity_x - relative_velocity_x) * damping
        local relative_y = (world_velocity_y - relative_velocity_y) * damping

        -- integrate external acceleration (gravity); y-down so positive gravity_y accelerates downward
        relative_x = relative_x + mass * gravity_x * delta
        relative_y = relative_y + mass * gravity_y * delta

        -- convert back to world velocity for advection and storage
        local world_velocity_new_x = relative_x + relative_velocity_x
        local world_velocity_new_y = relative_y + relative_velocity_y

        -- predict positions in world space (advected by frame)
        local position_new_x = position_x + world_velocity_new_x * delta
        local position_new_y = position_y + world_velocity_new_y * delta

        -- reset XPBD lambdas per particle
        local distance_lambda = 0
        local bending_lambda = 0
        local axis_lambda = 0

        return position_new_x, position_new_y, world_velocity_new_x, world_velocity_new_y, previous_x, previous_y, distance_lambda, bending_lambda, axis_lambda
    end

    -- XPBD distance constraint between two particles (A,B)
    -- C = |b - a| - d0 = 0
    local function _enforce_distance_xpbd(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        target_distance,
        alpha,         -- compliance (already scaled by sub_delta^2)
        lambda_before    -- accumulated lambda for this constraint
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

        -- x_i += w_i * d_lambda * gradC_i
        local correction_ax = inverse_mass_a * delta_lambda * (-normal_x) -- grad_a = -n
        local correction_ay = inverse_mass_a * delta_lambda * (-normal_y)
        local correction_bx = inverse_mass_b * delta_lambda * ( normal_x) -- grad_b = +n
        local correction_by = inverse_mass_b * delta_lambda * ( normal_y)

        return correction_ax, correction_ay, correction_bx, correction_by, lambda_new
    end

    -- XPBD bending as end-to-end AC distance equals target (sum of adjacent segment lengths)
    -- C = |c - a| - target_ac = 0
    local function _enforce_bending_xpbd(
        ax, ay, bx, by, cx, cy, 
        inverse_mass_a, inverse_mass_b, inverse_mass_c,
        target_ac_distance,
        alpha,
        lambda_before
    )
        local delta_x = cx - ax
        local delta_y = cy - ay
        local length = math.magnitude(delta_x, delta_y)
        if length < math.eps then
            return 0, 0, 0, 0, 0, 0, lambda_before
        end
        local normal_x, normal_y = math.normalize(delta_x, delta_y)

        local constraint = length - target_ac_distance
        local weight_sum = inverse_mass_a + inverse_mass_c
        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return 0, 0, 0, 0, 0, 0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        -- a += w_a * dλ * (-n); c += w_c * dλ * (n)
        local correction_ax = inverse_mass_a * delta_lambda * (-normal_x)
        local correction_ay = inverse_mass_a * delta_lambda * (-normal_y)
        local correction_cx = inverse_mass_c * delta_lambda * ( normal_x)
        local correction_cy = inverse_mass_c * delta_lambda * ( normal_y)

        -- B gets no direct correction in this simplified bending constraint
        return correction_ax, correction_ay, 0.0, 0.0, correction_cx, correction_cy, lambda_new
    end

    -- XPBD axis-alignment (1D scalar constraint: perpendicular projection to rotate segment towards axis)
    -- Let target axis unit be t = (tx,ty), perpendicular p = (-vy, vx) from current segment dir (with sign flip to avoid 180° flip).
    -- C = (b - (a + t * L)) · p = 0
    -- grad_a ≈ -p, grad_b ≈ p (treat p as constant - ignore derivative w.r.t positions)
    local function _enforce_axis_alignment_xpbd(
        ax, ay,
        bx, by,
        inverse_mass_a, inverse_mass_b,
        segment_length,
        target_x, target_y,
        alpha,
        lambda_before
    )
        local vector_x = bx - ax
        local vector_y = by - ay
        local vector_length = math.magnitude(vector_x, vector_y)
        if vector_length < 1e-12 then
            return 0, 0, 0, 0, lambda_before
        end
        vector_x, vector_y = math.normalize(vector_x, vector_y)

        -- choose orientation to avoid 180° ambiguity
        if math.dot(vector_x, vector_y, target_x, target_y) < 0 then
            vector_x = -vector_x
            vector_y = -vector_y
        end

        -- perpendicular to current segment
        local perpendicular_x = -vector_y
        local perpendicular_y =  vector_x

        -- desired endpoint for B along target axis
        local target_b_x = ax + target_x * segment_length
        local target_b_y = ay + target_y * segment_length

        -- scalar error along perpendicular
        local error_x = target_b_x - bx
        local error_y = target_b_y - by
        local constraint = math.dot(error_x, error_y, perpendicular_x, perpendicular_y)

        local weight_sum = inverse_mass_a + inverse_mass_b
        local denominator = weight_sum + alpha
        if denominator < math.eps then
            return 0, 0, 0, 0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = lambda_before + delta_lambda

        -- x_i += w_i * dλ * gradC_i; grad_a = -p, grad_b = p
        local correction_ax = inverse_mass_a * delta_lambda * (-perpendicular_x)
        local correction_ay = inverse_mass_a * delta_lambda * (-perpendicular_y)
        local correction_bx = inverse_mass_b * delta_lambda * ( perpendicular_x)
        local correction_by = inverse_mass_b * delta_lambda * ( perpendicular_y)

        return correction_ax, correction_ay, correction_bx, correction_by, lambda_new
    end

    -- XPBD line collision (inequality): C = n·(x - c) - r >= 0, λ >= 0
    local function _enforce_line_collision_xpbd(
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
        -- inactive if satisfied; reset lambda to 0 to avoid stickiness
        if constraint >= 0.0 or inverse_mass <= 0.0 then
            return 0.0, 0.0, 0.0
        end

        local denominator = inverse_mass + alpha
        if denominator < math.eps then
            return 0.0, 0.0, lambda_before
        end

        -- inequality complementarity: clamp λ >= 0
        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = math.clamp(lambda_before + delta_lambda, 0.0, math.huge)
        delta_lambda = lambda_new - lambda_before

        -- x += w * dλ * n
        local correction_x = inverse_mass * delta_lambda * normalized_x
        local correction_y = inverse_mass * delta_lambda * normalized_y

        return correction_x, correction_y, lambda_new
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

        local data = self._particle_data
        local n_particles = self._n_particles

        local gravity_direction_x, gravity_direction_y = 0, 1
        local gravity = settings.gravity

        local influence = 1 - math.clamp(rt.settings.player_body.relative_velocity_influence, 0, 1)
        local relative_velocity_x, relative_velocity_y = influence * self._relative_velocity_x, influence * self._relative_velocity_y

        for _ = 1, n_sub_steps do
            for particle_i = 1, self._n_particles do
                local offset = _particle_i_to_data_offset(particle_i)
                local new_position_x, new_position_y, new_velocity_x, new_velocity_y, previous_x, previous_y, distance_lambda, bending_lambda, axis_lambda = _pre_solve(
                    data[offset + _x_offset],
                    data[offset + _y_offset],
                    data[offset + _velocity_x_offset],
                    data[offset + _velocity_y_offset],
                    data[offset + _mass_offset],
                    gravity_direction_x * gravity, gravity_direction_y * gravity,
                    relative_velocity_x, relative_velocity_y,
                    damping, sub_delta
                )

                data[offset + _x_offset] = new_position_x
                data[offset + _y_offset] = new_position_y
                data[offset + _velocity_x_offset] = new_velocity_x
                data[offset + _velocity_y_offset] = new_velocity_y
                data[offset + _previous_x_offset] = previous_x
                data[offset + _previous_y_offset] = previous_y
                data[offset + _distance_lambda_offset] = distance_lambda
                data[offset + _bending_lambda_offset] = bending_lambda
                data[offset + _axis_lambda_offset] = axis_lambda
            end

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

            for __ = 1, n_constraint_iterations do
                for rope in values(self._ropes) do
                    local anchor_x = self._position_x + rope.anchor_x
                    local anchor_y = self._position_y + rope.anchor_y

                    -- pin first node to anchor each iteration
                    local anchor_offset = _particle_i_to_data_offset(rope.start_i)
                    data[anchor_offset + _x_offset] = anchor_x
                    data[anchor_offset + _y_offset] = anchor_y

                    -- segment distance constraints (XPBD)
                    for node_i = rope.start_i, rope.end_i - 1, 1 do
                        local a_i = _particle_i_to_data_offset(node_i + 0)
                        local b_i = _particle_i_to_data_offset(node_i + 1)

                        local ax, ay = data[a_i + _x_offset], data[a_i + _y_offset]
                        local bx, by = data[b_i + _x_offset], data[b_i + _y_offset]

                        local inverse_mass_a = data[a_i + _inverse_mass_offset]
                        local inverse_mass_b = data[b_i + _inverse_mass_offset]

                        local segment_length
                        if not self._use_contour then
                            segment_length = data[a_i + _segment_length_offset]
                        else
                            segment_length = data[a_i + _contour_segment_length_offset]
                        end

                        local correction_ax, correction_ay, correction_bx, correction_by, lambda_new = _enforce_distance_xpbd(
                            ax, ay, bx, by,
                            inverse_mass_a, inverse_mass_b,
                            segment_length,
                            distance_alpha,
                            data[a_i + _distance_lambda_offset]
                        )

                        data[a_i + _x_offset] = ax + correction_ax
                        data[a_i + _y_offset] = ay + correction_ay
                        data[b_i + _x_offset] = bx + correction_bx
                        data[b_i + _y_offset] = by + correction_by
                        data[a_i + _distance_lambda_offset] = lambda_new
                    end

                    -- bending constraints (XPBD)
                    for node_i = rope.start_i, rope.end_i - 2, 1 do
                        local a_i = _particle_i_to_data_offset(node_i + 0)
                        local b_i = _particle_i_to_data_offset(node_i + 1)
                        local c_i = _particle_i_to_data_offset(node_i + 2)

                        local ax, ay = data[a_i + _x_offset], data[a_i + _y_offset]
                        local bx, by = data[b_i + _x_offset], data[b_i + _y_offset]
                        local particle_c_x, particle_c_y = data[c_i + _x_offset], data[c_i + _y_offset]

                        local inverse_mass_a = data[a_i + _inverse_mass_offset]
                        local inverse_mass_b = data[b_i + _inverse_mass_offset]
                        local inverse_mass_c = data[c_i + _inverse_mass_offset]

                        local segment_length_ab = data[a_i + _segment_length_offset]
                        local segment_length_bc = data[b_i + _segment_length_offset]
                        local target_length = segment_length_ab + segment_length_bc

                        local correction_ax, correction_ay, _, _, correction_cxx, correction_cxy, lambda_new = _enforce_bending_xpbd(
                            ax, ay, bx, by, particle_c_x, particle_c_y,
                            inverse_mass_a, inverse_mass_b, inverse_mass_c,
                            target_length,
                            bending_alpha,
                            data[a_i + _bending_lambda_offset]
                        )
                        
                        data[a_i + _x_offset] = ax + correction_ax
                        data[a_i + _y_offset] = ay + correction_ay
                        data[c_i + _x_offset] = particle_c_x + correction_cxx
                        data[c_i + _y_offset] = particle_c_y + correction_cxy
                        data[a_i + _bending_lambda_offset] = lambda_new

                    end

                    -- axis alignment (XPBD, IK-like)
                    for node_i = rope.start_i, rope.end_i - 1 do
                        local a_i = _particle_i_to_data_offset(node_i)
                        local b_i = _particle_i_to_data_offset(node_i + 1)

                        local ax = data[a_i + _x_offset]
                        local ay = data[a_i + _y_offset]
                        local bx = data[b_i + _x_offset]
                        local by = data[b_i + _y_offset]

                        local inverse_mass_a = data[a_i + _inverse_mass_offset]
                        local inverse_mass_b = data[b_i + _inverse_mass_offset]

                        local segment_length = data[a_i + _segment_length_offset]

                        local axis_j = node_i - rope.start_i + 1
                        local correction_ax, correction_ay, correction_bx, correction_by, lambda_new = _enforce_axis_alignment_xpbd(
                            ax, ay, bx, by,
                            inverse_mass_a, inverse_mass_b,
                            segment_length,
                            rope.axis_x, rope.axis_y,
                            axis_alpha,
                            data[a_i + _axis_lambda_offset]
                        )
                        data[a_i + _axis_lambda_offset] = lambda_new

                        data[a_i + _x_offset] = ax + correction_ax
                        data[a_i + _y_offset] = ay + correction_ay
                        data[b_i + _x_offset] = bx + correction_bx
                        data[b_i + _y_offset] = by + correction_by
                    end

                    ::next_rope::
                end

                -- collisions (XPBD inequality per line, per particle)
                for line_i, line in ipairs(self._colliding_lines or {}) do
                    local row = self._colliding_lines_to_lambda and self._colliding_lines_to_lambda[line_i]
                    for particle_i = 1, self._n_particles do
                        local offset = _particle_i_to_data_offset(particle_i)

                        local radius = self._use_contour
                            and data[offset + _contour_radius_offset]
                            or  data[offset + _radius_offset]

                        local alpha_multiplier = data[offset + _collision_strength_offset]
                        if self._use_contour then alpha_multiplier = 0 end

                        local correction_x, correction_y, lambda_new = _enforce_line_collision_xpbd(
                            data[offset + _x_offset],
                            data[offset + _y_offset],
                            data[offset + _inverse_mass_offset],
                            radius,
                            line.contact_x,
                            line.contact_y,
                            line.normal_x,
                            line.normal_y,
                            collision_alpha * (1 - alpha_multiplier),
                            row[particle_i]
                        )

                        data[offset + _x_offset] = data[offset + _x_offset] + correction_x
                        data[offset + _y_offset] = data[offset + _y_offset] + correction_y

                        row[particle_i] = lambda_new
                    end
                end
            end -- constraint iterations

            for particle_i = 1, self._n_particles do
                local i = _particle_i_to_data_offset(particle_i)
                local new_velocity_x, new_velocity_y = _post_solve(
                    data[i + _x_offset],
                    data[i + _y_offset],
                    data[i + _previous_x_offset],
                    data[i + _previous_y_offset],
                    sub_delta
                )

                data[i + _velocity_x_offset] = new_velocity_x
                data[i + _velocity_y_offset] = new_velocity_y
            end
        end -- n sub steps

        self._render_texture_needs_update = true
    end

    -- export for other classes to use
    rt.PlayerBody._pre_solve = _pre_solve
    rt.PlayerBody._post_solve = _post_solve
    rt.PlayerBody._enforce_distance = _enforce_distance_xpbd
    rt.PlayerBody._enforce_axis_alignment = _enforce_axis_alignment_xpbd
    rt.PlayerBody._enforce_bending = _enforce_bending_xpbd
    rt.PlayerBody._enforce_line_collision_xpbd = _enforce_line_collision_xpbd
end

--- @brief
function rt.PlayerBody:set_stencil_bodies(t)
    self._body_stencil_bodies = t
end

--- @brief
function rt.PlayerBody:set_core_stencil_bodies(t)
    self._core_stencil_bodies = {}
end

--- @brief
function rt.PlayerBody:_apply_squish()
    if self._use_contour then return end

    local magnitude = rt.settings.player_body.squish_magnitude
    local radius = rt.settings.player.radius

    local function apply(motion, normal_x, normal_y, origin_x, origin_y)
        local amount = motion:get_value()
        if amount <= 0.01 then return end
        normal_x, normal_y = math.normalize(normal_x, normal_y)

        local angle = math.angle(normal_x, normal_y)
        local scale_x = 1 - magnitude * amount

        love.graphics.translate(origin_x, origin_y)
        love.graphics.rotate(angle)
        love.graphics.scale(scale_x, 1)
        love.graphics.rotate(-angle)
        love.graphics.translate(-origin_x, -origin_y)
    end

    apply(self._down_squish_motion,
        self._down_squish_normal_x, self._down_squish_normal_y,
        self._down_squish_origin_x, self._down_squish_origin_y
    )

    apply(self._left_squish_motion,
        self._left_squish_normal_x, self._left_squish_normal_y,
        self._left_squish_origin_x, self._left_squish_origin_y
    )

    apply(self._right_squish_motion,
        self._right_squish_normal_x, self._right_squish_normal_y,
        self._right_squish_origin_x, self._right_squish_origin_y
    )

    apply(self._up_squish_motion,
        self._up_squish_normal_x, self._up_squish_normal_y,
        self._up_squish_origin_x, self._up_squish_origin_y
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
        for body in values(self._body_stencil_bodies) do
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

    love.graphics.setColor(1, 1, 1, 1)
    local body_r, body_g, body_b, body_a = self._body_color:unpack()
    local outline_r, outline_g, outline_b, outline_a = self._core_color:unpack()
    _outline_shader:send("body_color", { body_r, body_g, body_b, body_a * self._opacity })
    _outline_shader:send("outline_color", { outline_r, outline_g, outline_b, outline_a * self._opacity })
    _outline_shader:bind()
    self._body_outline_texture:draw()
    _outline_shader:unbind()
    love.graphics.pop()

    rt.graphics.set_stencil_mode(nil)

    --[[
    for line in values(self._colliding_lines) do
        local cx, cy = line.contact_x, line.contact_y
        local lx, ly = math.turn_left(line.normal_x, line.normal_y)
        local rx, ry = math.turn_right(line.normal_x, line.normal_y)
        love.graphics.line(cx + 100 * lx, cy + 100 * ly, cx + 100 * rx, cy + 100 * ry)
    end
    ]]--

end

--- @brief
function rt.PlayerBody:draw_core()
    if self._core_vertices == nil then return end

    love.graphics.push("all")

    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
    for body in values(self._body_stencil_bodies) do
        body:draw(true) -- mask only
    end
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

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
    love.graphics.setColor(1, 1, 1, self._opacity)
    love.graphics.polygon("fill", self._core_vertices)
    _core_shader:unbind()

    rt.graphics.set_stencil_mode(nil)

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
    self:_apply_squish()
    love.graphics.translate(self._position_x - 0.5 * w, self._position_y - 0.5 * w)
    love.graphics.translate(0.5 * w, 0.5 * h)
    love.graphics.scale(1 / texture_scale, 1 / texture_scale)
    love.graphics.translate(-0.5 * w, -0.5 * h)
    _outline_shader:send("body_color", { 0, 0, 0, 0 })

    local core_r, core_g, core_b, core_a = self._core_color:unpack()
    core_a = core_a * self._opacity
    _outline_shader:send("outline_color", { core_r, core_g, core_b, core_a })
    _outline_shader:bind()
    self._body_outline_texture:draw()
    _outline_shader:unbind()
    love.graphics.pop()


    love.graphics.push()
    love.graphics.scale(self._core_outline_scale, self._core_outline_scale)
    love.graphics.setColor(core_r, core_g, core_b, core_a)
    love.graphics.polygon("line", self._core_vertices)
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
        self._down_squish_motion:set_target_value(_squished)
    else
        self._down_squish_motion:set_target_value(_not_squished)
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
        self._left_squish_motion:set_target_value(_squished)
    else
        self._left_squish_motion:set_target_value(_not_squished)
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
        self._right_squish_motion:set_target_value(_squished)
    else
        self._right_squish_motion:set_target_value(_not_squished)
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
        self._up_squish_motion:set_target_value(_squished)
    else
        self._up_squish_motion:set_target_value(_not_squished)
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
