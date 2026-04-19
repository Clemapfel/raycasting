rt.settings.overworld.fluid = {
    damping = 0.1,
    texture_scale = 4,

    n_particles = 400,

    particles = {
        radius = 10,
        min_mass = 1,
        max_mass = 2
    },

    n_sub_steps = 2,
    n_constraint_iterations = 2,

    spatial_hash_outer_size = 1000,

    follow_compliance = 0.01,
    segment_compliance = 0,
    collision_compliance = 0.0001
}

--- @class ow.Fluid
ow.Fluid = meta.class("OverworldFluid")

--- @class ow.FluidBounds
ow.FluidBounds = meta.class("FluidBounds")

local _segment_x1_offset = 0
local _segment_y1_offset = 1
local _segment_x2_offset = 2
local _segment_y2_offset = 3
local _segment_origin_x_offset = 4
local _segment_origin_y_offset = 5
local _segment_normal_x_offset = 6
local _segment_normal_y_offset = 7
local _segment_stride = _segment_normal_y_offset + 1

--- @brief
function ow.Fluid:instantiate(object, stage, scene)
    self._stage = stage
    self._scene = scene

    -- extract room
    local other = object:get_object("bounds", true)
    rt.assert(other:get_type() == ow.ObjectType.POLYGON, "In ow.Fluid: object `", other:get_id(), "` is not a polygon")

    local contour = other:create_contour()

    do
        self._segments = {}
        self._n_segments = 0

        local data = self._segments
        for segment_i = 1, #contour + 2, 2 do
            local x1 = contour[math.wrap(segment_i + 0, #contour)]
            local y1 = contour[math.wrap(segment_i + 1, #contour)]
            local x2 = contour[math.wrap(segment_i + 2, #contour)]
            local y2 = contour[math.wrap(segment_i + 3, #contour)]

            -- precompute origin
            local origin_x, origin_y = math.mix2(x1, y1, x2, y2, 0.5)

            -- precompute normal, require for line collision constraint
            local normal_x, normal_y = math.normalize(math.turn_left(
                x2 - x1,
                y2 - y1
            ))

            local i = #data + 1
            data[i + _segment_x1_offset] = x1
            data[i + _segment_y1_offset] = y1
            data[i + _segment_x2_offset] = x2
            data[i + _segment_y2_offset] = y2
            data[i + _segment_origin_x_offset] = origin_x
            data[i + _segment_origin_y_offset] = origin_y
            data[i + _segment_normal_x_offset] = normal_x
            data[i + _segment_normal_y_offset] = normal_y

            assert(#data - i == _segment_stride - 1)

            self._n_segments = self._n_segments + 1
        end

        for i = 1, #self._segments do
            assert(self._segments[i] ~= nil)
        end
    end

    -- init particles
    self:_initialize(object.x, object.y, 400)

    DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "k" then
            self:_initialize(object.x, object.y)
        end
    end)
end

local _x_offset = 0  -- x position, px
local _y_offset = 1  -- y position, px
local _previous_x_offset = 2 -- last sub steps x position, px
local _previous_y_offset = 3 -- last sub steps y position, px
local _velocity_x_offset = 4 -- x velocity, px / s
local _velocity_y_offset = 5 -- y velocity, px / s
local _radius_offset = 6 -- radius, px
local _mass_offset = 7
local _inverse_mass_offset = 8
local _id_offset = 9
local _cell_x_offset = 10
local _cell_y_offset = 11
local _r_offset = 12
local _g_offset = 13
local _b_offset = 14
local _a_offset = 15
local _follow_x_offset = 16
local _follow_y_offset = 17
local _follow_lambda_offset = 18
local _first_segment_lambda_offset = 19

local _particle_i_to_data_offset = function(particle_i, stride)
    return (particle_i - 1) * stride + 1
end

local _particle_ij_to_collision_lambda_i = function(i, j)
    if j < i then i, j = j, i end
    return math.floor((j - 1) * (j - 2) / 2) + i
end

local _n_particles_to_n_collision_lambdas = function(n_particles)
    return n_particles * (n_particles + 1) / 2
end

local _cell_xy_to_linear_index = function(row_i, col_i, n_rows, n_columns)
    return (row_i - 1) * n_columns + col_i
end

local _data_mesh_format = {
    { location = 3, name = "position", format = "floatvec2" },
    { location = 4, name = "radius", format = "float" },
    { location = 5, name = "color", format = "floatvec4" }
}

local _instance_draw_shader = rt.Shader("overworld/objects/fluid_draw_particles.glsl")
local _particle_texture_shader = rt.Shader("overworld/objects/fluid_particle_texture.glsl")

local _xy_to_spatial_hash_xy = function(
    x, y,
    particle_min_x, particle_min_y,
    particle_area_width, particle_area_height,
    spatial_hash_cell_radius
)
    -- translate so position can never be <= 0
    -- then shift so particle cluster is centered in spatial hash
    local offset_x = x - particle_min_x + 0.5 * particle_area_width
    local offset_y = y - particle_min_y + 0.5 * particle_area_height
    return offset_x, offset_y
end

local _spatial_hash_xy_to_cell_xy = function(
    spatial_hash_x, spatial_hash_y,
    spatial_hash_cell_radius,
    spatial_hash_n_cols, spatial_hash_n_rows
)
    local cell_x = math.floor(spatial_hash_x / spatial_hash_cell_radius) + 1
    local cell_y = math.floor(spatial_hash_y / spatial_hash_cell_radius) + 1

    return cell_x, cell_y
end

--- @brief
function ow.Fluid:_initialize(center_x, center_y)
    local n_particles = rt.settings.overworld.fluid.n_particles
    self._n_particles = n_particles

    _instance_draw_shader:recompile()
    _particle_texture_shader:recompile()

    do -- instance mesh
        -- 5-vertex quad with side length 1 centered at 0, 0
        local x, y, r = 0, 0, 1
        self._instance_mesh = rt.Mesh({
            { x    , y    , 0.5, 0.5,  1, 1, 1, 1 },
            { x - r, y - r, 0.0, 0.0,  1, 1, 1, 1 },
            { x + r, y - r, 1.0, 0.0,  1, 1, 1, 1 },
            { x + r, y + r, 1.0, 1.0,  1, 1, 1, 1 },
            { x - r, y + r, 0.0, 1.0,  1, 1, 1, 1 }
        }, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat2D, rt.GraphicsBufferUsage.STATIC)

        self._instance_mesh:set_vertex_map(
            1, 2, 3,
            1, 3, 4,
            1, 4, 5,
            1, 5, 2
        )
        self._instance_mesh:set_texture(self._particle_texture)
    end

    do -- instance mesh texture
        local particle_texture_r = rt.settings.overworld.fluid.particles.radius + 1 -- padding
        local w = (particle_texture_r + 2) * 2
        local h = w

        self._particle_texture = rt.RenderTexture(
            w, h,
            0, -- msaa
            rt.TextureFormat.NORMAL
        )

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

        self._instance_mesh:set_texture(self._particle_texture)
    end

    do -- data mesh
        local native = love.graphics.newMesh(
            _data_mesh_format,
            self._n_particles,
            rt.MeshDrawMode.POINTS, -- unused
            rt.GraphicsBufferUsage.STREAM
        )

        self._data_mesh = rt.Mesh(native)
        self._data_buffer = rt.GraphicsBuffer(native:getVertexBuffer())
        self._data_buffer_data = self._data_buffer:get_byte_data()

        for entry in values(_data_mesh_format) do
            self._instance_mesh:attach_attribute(
                self._data_mesh,
                entry.name,
                rt.MeshAttributeAttachmentMode.PER_INSTANCE
            )
        end
    end

    self._particle_stride = _first_segment_lambda_offset + self._n_segments + 1
    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge

    do -- particle data
        self._data = {}
        local data = self._data
        local settings = rt.settings.overworld.fluid

        local radius = settings.particles.radius
        local min_mass, max_mass = settings.particles.min_mass, settings.particles.max_mass
        local golden_angle = math.pi * (3 - math.sqrt(5))

        local max_distance = radius * math.sqrt(n_particles)

        local gaussian_easing = function(t)
            -- e^{-\left(\frac{4\pi}{3}\right)x^{2}}
            return math.exp(-1 * ((4 * math.pi) / 3) * t ^ 2)
        end

        for particle_index = 1, n_particles do
            local i = #data + 1

            local distance = radius * math.sqrt(particle_index)
            local angle = particle_index * golden_angle
            local t = gaussian_easing(distance / max_distance)

            local x = center_x + distance * math.cos(angle)
            local y = center_y + distance * math.sin(angle)

            min_x = math.min(min_x, x)
            min_y = math.min(min_y, y)
            max_x = math.max(max_x, x)
            max_y = math.max(max_y, y)

            data[i + _x_offset] = x
            data[i + _y_offset] = y
            data[i + _previous_x_offset] = x
            data[i + _previous_y_offset] = y

            data[i + _velocity_x_offset] = 0
            data[i + _velocity_y_offset] = 0

            data[i + _radius_offset] = radius

            local mass = math.mix(min_mass, max_mass, t)
            data[i + _mass_offset] = mass
            data[i + _inverse_mass_offset] = 1 / mass

            data[i + _id_offset] = particle_index
            data[i + _cell_x_offset] = 0 -- initialized on first update
            data[i + _cell_y_offset] = 0

            local r, g, b, a = rt.lcha_to_rgba(0.8, 1, t, 1)

            data[i + _r_offset] = r
            data[i + _g_offset] = g
            data[i + _b_offset] = b
            data[i + _a_offset] = a

            data[i + _follow_x_offset] = x
            data[i + _follow_y_offset] = y
            data[i + _follow_lambda_offset] = 0

            for offset = 0, self._n_segments do
                data[i + _first_segment_lambda_offset + offset] = 0
            end

            assert(#data - i == self._particle_stride - 1)
        end

        for i = 1, #data do
            assert(data[i] ~= nil)
        end

        self._collision_lambdas = table.new(_n_particles_to_n_collision_lambdas(self._n_particles), 0)
    end

    self._spatial_hash_cell_radius = 2 * rt.settings.overworld.fluid.particles.radius

    self._particle_area_padding = 2 * self._spatial_hash_cell_radius
    min_x = min_x - self._particle_area_padding
    min_y = min_y - self._particle_area_padding
    max_x = max_x + self._particle_area_padding
    max_y = max_y + self._particle_area_padding

    self._particle_min_x = min_x
    self._particle_min_y = min_y
    self._particle_area_width = max_x - min_x
    self._particle_area_height = max_y - min_y
    self._particle_centroid_x = center_x
    self._particle_centroid_y = center_y

    self._segment_aabb_padding = 8 * self._spatial_hash_cell_radius

    do -- spatial hash
        local primes = {
            2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71,
            73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151,
            157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233,
            239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317,
            331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419,
            421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503,
            509, 521, 523, 541, 547, 557, 563, 569, 571, 577, 587, 593, 599, 601, 607,
            613, 617, 619, 631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701,
            709, 719, 727, 733, 739, 743, 751, 757, 761, 769, 773, 787, 797, 809, 811,
            821, 823, 827, 829, 839, 853, 857, 859, 863, 877, 881, 883, 887, 907, 911,
            919, 929, 937, 941, 947, 953, 967, 971, 977, 983, 991, 997, 1009, 1013,
            1019, 1021
        }

        local n_particles_per_cell = n_particles
        for _, prime in ipairs(primes) do
            if prime > math.sqrt(n_particles) then
                n_particles_per_cell = prime
                break
            end
        end

        local cell_size = self._spatial_hash_cell_radius
        local outer_r = rt.settings.overworld.fluid.spatial_hash_outer_size

        local n_rows = math.ceil(outer_r / cell_size)
        local n_columns = n_rows

        self._spatial_hash_n_rows = n_rows
        self._spatial_hash_n_columns = n_columns

        self._spatial_hash_particle_count_index = 1
        self._spatial_hash_particle_index = 2

        self._spatial_hash = {}

        for row_i = 1, n_rows do
            for col_i = 1, n_columns do
                local cell = {
                    [self._spatial_hash_particle_count_index] = 0,
                }

                for offset = 0, n_particles_per_cell do
                    cell[self._spatial_hash_particle_index + offset] = -1
                end

                local linear_index = _cell_xy_to_linear_index(row_i, col_i, n_rows, n_columns)
                self._spatial_hash[linear_index] = cell
            end
        end

        for i = 1, n_rows * n_columns do
            assert(self._spatial_hash[i] ~= nil)
        end
    end

    self._canvas_padding = rt.settings.overworld.fluid.particles.radius * rt.settings.overworld.fluid.texture_scale

    self:_resize_canvas() -- sets self._canvas_needs_update
    self:_update_data_mesh()
end

do -- update helpers
    local function _enforce_distance(
        ax, ay, bx, by,
        inverse_mass_a, inverse_mass_b,
        target_distance,
        alpha, -- compliance, already scaled by delta^2
        lambda_before
    )
        local delta_x = bx - ax
        local delta_y = by - ay
        local length = math.magnitude(delta_x, delta_y)
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

        local correction_ax = inverse_mass_a * delta_lambda * -normal_x
        local correction_ay = inverse_mass_a * delta_lambda * -normal_y
        local correction_bx = inverse_mass_b * delta_lambda *  normal_x
        local correction_by = inverse_mass_b * delta_lambda *  normal_y

        return correction_ax, correction_ay, correction_bx, correction_by, lambda_new
    end

    local function _enforce_position(
        px, py, r, inverse_mass,
        follow_x, follow_y,
        compliance, lambda_before
    )
        local dx_raw, dy_raw = follow_x - px, follow_y - py
        local current_distance = math.distance(px, py, follow_x, follow_y)
        local dx, dy = math.normalize(dx_raw, dy_raw)

        local constraint_violation = r - current_distance

        local denominator = (inverse_mass + compliance)
        if math.abs(denominator) < math.eps then
            return 0, 0, lambda_before
        end

        local delta_lambda = (-constraint_violation - compliance * lambda_before) / denominator

        local lambda_after = lambda_before + delta_lambda

        return dx * delta_lambda * inverse_mass,
            dy * delta_lambda * inverse_mass,
            lambda_after
    end

    local function _enforce_segment_collision(
        position_x, position_y, radius, inverse_mass,
        line_contact_x, line_contact_y,
        line_normal_x, line_normal_y, -- normal encodes sidedness
        alpha,
        lambda_before
    )
        local constraint = (position_x - line_contact_x) * line_normal_x
            + (position_y - line_contact_y) * line_normal_y
            - radius

        if constraint >= 0.0 or inverse_mass <= 0.0 then
            return 0.0, 0.0, 0.0
        end

        local denominator = inverse_mass + alpha
        if denominator < math.eps then
            return 0.0, 0.0, lambda_before
        end

        local delta_lambda = -(constraint + alpha * lambda_before) / denominator
        local lambda_new = math.max(lambda_before + delta_lambda, 0.0)
        delta_lambda = lambda_new - lambda_before

        return inverse_mass * delta_lambda * line_normal_x,
            inverse_mass * delta_lambda * line_normal_y,
            lambda_new
    end

    local _point_on_segment = function(px, py, r, x1, y1, x2, y2)
        local dx, dy = x2 - x1, y2 - y1
        local t = math.dot(px - x1, py - y1, dx, dy) / (math.dot(dx, dy, dx, dy) + math.eps)

        -- is particle in voronoi region
        if not (t <= math.eps or t >= 1 - math.eps) then return false end

        -- is particle closer than r to segment
        local cx, cy = x1 + t * dx, y1 + t * dy
        return (px - cx)^2 + (py - cy)^2 < r^2
    end

    local _point_on_side = function(position_x, position_y, line_contact_x, line_contact_y, line_normal_x, line_normal_y)
        local offset_x = position_x - line_contact_x
        local offset_y = position_y - line_contact_y

        -- is particle on side of line the normal points in
        local signed_distance = offset_x * line_normal_x + offset_y * line_normal_y
        return signed_distance < 0.0
    end

    --- @brief
    function ow.Fluid:update(delta)
        local settings = rt.settings.overworld.fluid

        local damping = settings.damping
        local n_sub_steps = settings.n_sub_steps
        local n_constraint_iterations = settings.n_constraint_iterations

        local sub_delta = math.max(delta / settings.n_sub_steps, math.eps)

        local follow_alpha = settings.follow_compliance / (sub_delta^2)
        local collision_alpha = settings.collision_compliance / (sub_delta^2)
        local segment_alpha = settings.segment_compliance / (sub_delta^2)

        local data = self._data
        local n_particles = self._n_particles
        local particle_stride = self._particle_stride

        local segments = self._segments
        local n_segments = self._n_segments
        local segment_aabb_padding = self._segment_aabb_padding

        local collision_lambdas = self._collision_lambdas

        local spatial_hash_cell_counts = {}
        local spatial_hash_cell_starts = {}

        local spatial_hash_n_particles_per_cell = self._spatial_hash_n_particles_per_cell
        local spatial_hash_cell_radius = self._spatial_hash_cell_radius
        local spatial_hash_n_rows = self._spatial_hash_n_rows
        local spatial_hash_n_cols = self._spatial_hash_n_columns
        local spatial_hash = self._spatial_hash

        local cell_particle_count_index = self._spatial_hash_particle_count_index
        local cell_particle_index = self._spatial_hash_particle_index

        local particle_min_x, particle_min_y = self._particle_min_x, self._particle_min_y
        local particle_area_width, particle_area_height = self._particle_area_width, self._particle_area_height

        for _ = 1, n_sub_steps do
            -- ### PRE SOLVE ###

            -- reset spatial hash
            for entry in values(spatial_hash) do
                -- reset particle count
                entry[cell_particle_count_index] = 0

                -- keep stale particle ids
            end

            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i, particle_stride)

                -- store position at start of sub step
                local x = data[i + _x_offset]
                local y = data[i + _y_offset]
                data[i + _previous_x_offset] = x
                data[i + _previous_y_offset] = y

                -- apply damping
                local velocity_x = data[i + _velocity_x_offset] * damping
                local velocity_y = data[i + _velocity_y_offset] * damping

                data[i + _velocity_x_offset] = velocity_x
                data[i + _velocity_y_offset] = velocity_y

                -- integrate position
                data[i + _x_offset] = x + sub_delta * velocity_x
                data[i + _y_offset] = y + sub_delta * velocity_y

                -- reset follow lambda
                data[i + _follow_lambda_offset] = 0

                -- reset segment lambdas
                for offset = 0, n_segments - 1 do
                    data[i + _first_segment_lambda_offset + offset] = 0
                end

                -- update spatial hash
                local radius = data[i + _radius_offset]

                local spatial_hash_x, spatial_hash_y = _xy_to_spatial_hash_xy(
                    x, y,
                    particle_min_x, particle_min_y,
                    particle_area_width, particle_area_height,
                    spatial_hash_cell_radius
                )

                local cell_x, cell_y = _spatial_hash_xy_to_cell_xy(
                    spatial_hash_x, spatial_hash_y,
                    spatial_hash_cell_radius,
                    spatial_hash_n_rows, spatial_hash_n_cols
                )

                data[i + _cell_x_offset] = cell_x
                data[i + _cell_y_offset] = cell_y

                local cell_i = _cell_xy_to_linear_index(cell_y, cell_x, spatial_hash_n_rows, spatial_hash_n_cols)
                local cell = spatial_hash[cell_i]

                if cell == nil then -- emergency resize of spatial hash
                    if DEBUG then
                        --rt.error("In ow.Fluid: particle at `", x, " ", y, "` is out of bounds")
                    end

                    -- emergency resize spatial hash
                    rt.warning("In ow.Fluid: forced to resize spatial hash from ",
                        "`", self._spatial_hash_n_rows, "` `", self._spatial_hash_n_columns, "` to ",
                        "`", cell_x, "`", "`", cell_y, "`"
                    )

                    if cell_x > self._spatial_hash_n_rows then
                        self._spatial_hash_n_rows = cell_x
                    end

                    if cell_y > self._spatial_hash_n_columns then
                        self._spatial_hash_n_columns = cell_y
                    end

                    if cell == nil then
                        cell = {}
                        spatial_hash[cell_i] = cell
                        cell[cell_particle_count_index] = 0
                    end
                end

                local offset = cell[cell_particle_count_index]
                cell[cell_particle_index + offset] = particle_i
                cell[cell_particle_count_index] = offset + 1

                local fx, fy = self._scene:get_player():get_position()
                data[i + _follow_x_offset] = fx
                data[i + _follow_y_offset] = fy
            end

            -- reset collision lambdas
            for lambda_i = 1, _n_particles_to_n_collision_lambdas(n_particles) do
                collision_lambdas[lambda_i] = 0
            end

            -- ### MOTION ###

            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i, particle_stride)
                local x = data[i + _x_offset]
                local y = data[i + _y_offset]

                local correction_x, correction_y, lambda = _enforce_position(
                    x, y, data[i + _radius_offset], data[i + _inverse_mass_offset],
                    data[i + _follow_x_offset], data[i + _follow_y_offset],
                    follow_alpha, data[i + _follow_lambda_offset]
                )

                data[i + _x_offset] = x + correction_x
                data[i + _y_offset] = y + correction_y
                data[i + _follow_lambda_offset] = lambda
            end

            -- ### COLLISION ###

            -- particle - particle collision
            for self_particle_i = 1, n_particles do
                local self_i = _particle_i_to_data_offset(self_particle_i, particle_stride)

                local cell_x = data[self_i + _cell_x_offset]
                local cell_y = data[self_i + _cell_y_offset]

                for x_offset = -1, 1 do
                    for y_offset = -1, 1 do
                        local cell_i = _cell_xy_to_linear_index(
                            cell_y + y_offset, -- sic
                            cell_x + x_offset,
                            spatial_hash_n_rows,
                            spatial_hash_n_cols
                        )

                        local cell = spatial_hash[cell_i]
                        if cell ~= nil then
                            for offset = 0, cell[cell_particle_count_index] - 1 do
                                local other_particle_i = cell[cell_particle_index + offset]
                                local other_i = _particle_i_to_data_offset(other_particle_i, particle_stride)

                                if other_particle_i > self_particle_i then
                                    local lambda_i = _particle_ij_to_collision_lambda_i(
                                        self_particle_i,
                                        other_particle_i
                                    )

                                    local self_x_i = self_i + _x_offset
                                    local self_y_i = self_i + _y_offset

                                    local other_x_i = other_i + _x_offset
                                    local other_y_i = other_i + _y_offset

                                    local self_x, self_y = data[self_x_i], data[self_y_i]
                                    local other_x, other_y = data[other_x_i], data[other_y_i]

                                    local min_distance = data[self_i + _radius_offset] + data[other_i + _radius_offset]

                                    local distance = math.squared_distance(
                                        self_x, self_y, other_x, other_y
                                    )

                                    if distance <= min_distance ^ 2 then
                                        local self_correction_x, self_correction_y,
                                        other_correction_x, other_correction_y,
                                        lambda = _enforce_distance(
                                            data[self_x_i], data[self_y_i],
                                            data[other_x_i], data[other_y_i],
                                            data[self_i + _inverse_mass_offset],
                                            data[other_i + _inverse_mass_offset],
                                            min_distance, collision_alpha,
                                            collision_lambdas[lambda_i]
                                        )

                                        data[self_x_i] = self_x + self_correction_x
                                        data[self_y_i] = self_y + self_correction_y
                                        data[other_x_i] = other_x + other_correction_x
                                        data[other_y_i] = other_y + other_correction_y
                                        collision_lambdas[lambda_i] = lambda
                                    end
                                end
                            end
                        end
                    end
                end
            end

            -- particle - segment collision
            for particle_i = 1, n_particles do
                local particle_offset = _particle_i_to_data_offset(particle_i, particle_stride)
                local x_i, y_i = particle_offset + _x_offset, particle_offset + _y_offset
                local x, y = data[x_i], data[y_i]
                local radius = data[particle_offset + _radius_offset]

                for segment_i = 1, n_segments do
                    local segment_offset = _particle_i_to_data_offset(segment_i, _segment_stride)
                    local x1 = segments[segment_offset + _segment_x1_offset]
                    local y1 = segments[segment_offset + _segment_y1_offset]
                    local x2 = segments[segment_offset + _segment_x2_offset]
                    local y2 = segments[segment_offset + _segment_y2_offset]
                    local origin_x = segments[segment_offset + _segment_origin_x_offset]
                    local origin_y = segments[segment_offset + _segment_origin_y_offset]
                    local normal_x = segments[segment_offset + _segment_normal_x_offset]
                    local normal_y = segments[segment_offset + _segment_normal_y_offset]

                    local lambda_i = particle_offset + _first_segment_lambda_offset + (segment_i - 1)
                    if _point_on_side(x, y, origin_x, origin_y, normal_x, normal_y)
                        or _point_on_segment(x, y, radius, x1, y1, x2, y2)
                    then
                        local correction_x, correction_y, lambda = _enforce_segment_collision(
                            x, y, radius, data[particle_offset + _inverse_mass_offset],
                            origin_x, origin_y, normal_x, normal_y,
                            segment_alpha, data[lambda_i]
                        )

                        data[x_i] = x + correction_x
                        data[y_i] = y + correction_y
                        data[lambda_i] = lambda
                    end
                end
            end

            -- ### POST SOLVE ###

            local min_x, min_y = math.huge, math.huge
            local max_x, max_y = -math.huge, -math.huge
            local centroid_x, centroid_y = 0, 0

            local max_velocity = 0
            local max_radius = 0

            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i, particle_stride)

                local x = data[i + _x_offset]
                local y = data[i + _y_offset]

                local velocity_x = (x - data[i + _previous_x_offset]) / sub_delta
                local velocity_y = (y - data[i + _previous_y_offset]) / sub_delta
                data[i + _velocity_x_offset] = velocity_x
                data[i + _velocity_y_offset] = velocity_y

                centroid_x = centroid_x + x
                centroid_y = centroid_y + y

                local r = data[i + _radius_offset]
                if r > max_radius then max_radius = r end
                min_x = math.min(min_x, x - r)
                min_y = math.min(min_y, y - r)
                max_x = math.max(max_x, x + r)
                max_y = math.max(max_y, y + r)
            end

            if n_particles > 0 then
                centroid_x = centroid_x / n_particles
                centroid_y = centroid_y / n_particles
            end

            self._particle_min_x = min_x - self._particle_area_padding
            self._particle_min_y = min_y - self._particle_area_padding
            self._particle_area_width = math.max(self._particle_area_width, max_x - min_x + 2 * self._particle_area_padding)
            self._particle_area_height = math.max(self._particle_area_height, max_y - min_y + 2 * self._particle_area_padding)
            self._particle_centroid_x = centroid_x
            self._particle_centroid_y = centroid_y
        end

        -- export
        self:_update_data_mesh()
        self._canvas_needs_update = true
    end
end -- update helpers

local use_ffi = ffi ~= nil

--- @brief
function ow.Fluid:_update_data_mesh()
    local particle_data = self._data
    local texture_scale = rt.settings.overworld.fluid.texture_scale

    if use_ffi then
        local data = ffi.cast("float*", self._data_buffer_data:get_native():getFFIPointer())

        local to_ffi_offset = 1 / ffi.sizeof("float")
        local buffer_x_offset = self._data_buffer:get_byte_offset(1, 1) * to_ffi_offset
        local buffer_y_offset = self._data_buffer:get_byte_offset(1, 2) * to_ffi_offset
        local buffer_radius_offset = self._data_buffer:get_byte_offset(2, 1) * to_ffi_offset
        local buffer_r_offset = self._data_buffer:get_byte_offset(3, 1) * to_ffi_offset
        local buffer_g_offset = self._data_buffer:get_byte_offset(3, 2) * to_ffi_offset
        local buffer_b_offset = self._data_buffer:get_byte_offset(3, 3) * to_ffi_offset
        local buffer_a_offset = self._data_buffer:get_byte_offset(3, 4) * to_ffi_offset
        local buffer_stride = self._data_buffer:get_element_stride() * to_ffi_offset

        for particle_i = 1, self._n_particles do
            local particle_data_i = _particle_i_to_data_offset(particle_i, self._particle_stride)
            local buffer_i = (particle_i - 1) * buffer_stride

            data[buffer_i + buffer_x_offset] = particle_data[particle_data_i + _x_offset]
            data[buffer_i + buffer_y_offset] = particle_data[particle_data_i + _y_offset]
            data[buffer_i + buffer_radius_offset] = particle_data[particle_data_i + _radius_offset] * texture_scale
            data[buffer_i + buffer_r_offset] = particle_data[particle_data_i + _r_offset]
            data[buffer_i + buffer_g_offset] = particle_data[particle_data_i + _g_offset]
            data[buffer_i + buffer_b_offset] = particle_data[particle_data_i + _b_offset]
            data[buffer_i + buffer_a_offset] = particle_data[particle_data_i + _a_offset]
        end
    else
        local data = self._data_buffer_data:get_native()

        local buffer_x_offset = self._data_buffer:get_byte_offset(1, 1)
        local buffer_y_offset = self._data_buffer:get_byte_offset(1, 2)
        local buffer_radius_offset = self._data_buffer:get_byte_offset(2, 1)
        local buffer_r_offset = self._data_buffer:get_byte_offset(3, 1)
        local buffer_g_offset = self._data_buffer:get_byte_offset(3, 2)
        local buffer_b_offset = self._data_buffer:get_byte_offset(3, 3)
        local buffer_a_offset = self._data_buffer:get_byte_offset(3, 4)
        local buffer_stride = self._data_buffer:get_element_stride()

        for particle_i = 1, self._n_particles do
            local particle_data_i = _particle_i_to_data_offset(particle_i, self._particle_stride)
            local buffer_i = (particle_i - 1) * buffer_stride

            data:setFloat(buffer_i + buffer_x_offset, particle_data[particle_data_i + _x_offset])
            data:setFloat(buffer_i + buffer_y_offset, particle_data[particle_data_i + _y_offset])
            data:setFloat(buffer_i + buffer_radius_offset, particle_data[particle_data_i + _radius_offset] * texture_scale)
            data:setFloat(buffer_i + buffer_r_offset, particle_data[particle_data_i + _r_offset])
            data:setFloat(buffer_i + buffer_g_offset, particle_data[particle_data_i + _g_offset])
            data:setFloat(buffer_i + buffer_b_offset, particle_data[particle_data_i + _b_offset])
            data:setFloat(buffer_i + buffer_a_offset, particle_data[particle_data_i + _a_offset])
        end
    end

    self._data_mesh:replace_data(self._data_buffer_data)
end

--- @brief
function ow.Fluid:_resize_canvas()
    local width = self._particle_area_width
    local height = self._particle_area_height
    width = width + 2 * self._canvas_padding
    height = height + 2 * self._canvas_padding

    require "common.msaa_quality"
    require "common.texture_format"

    if self._canvas == nil
        or self._canvas:get_width() ~= width
        or self._canvas:get_height() ~= height
    then
        self._canvas = rt.RenderTexture(
            width, height,
            rt.graphics.msaa_quality_to_native(rt.MSAAQuality.BETTER),
            rt.TextureFormat.RGBA16F
        )

        self._canvas_needs_update = true
    end
end

--- @brief
function ow.Fluid:_debug_draw_particles()
    if use_ffi then
        local data = ffi.cast("float*", self._data_buffer_data:get_native():getFFIPointer())

        local to_ffi_offset = 1 / ffi.sizeof("float")
        local buffer_x_offset = self._data_buffer:get_byte_offset(1, 1) * to_ffi_offset
        local buffer_y_offset = self._data_buffer:get_byte_offset(1, 2) * to_ffi_offset
        local buffer_radius_offset = self._data_buffer:get_byte_offset(2, 1) * to_ffi_offset
        local buffer_r_offset = self._data_buffer:get_byte_offset(3, 1) * to_ffi_offset
        local buffer_g_offset = self._data_buffer:get_byte_offset(3, 2) * to_ffi_offset
        local buffer_b_offset = self._data_buffer:get_byte_offset(3, 3) * to_ffi_offset
        local buffer_a_offset = self._data_buffer:get_byte_offset(3, 4) * to_ffi_offset
        local buffer_stride = self._data_buffer:get_element_stride() * to_ffi_offset

        local particle_data = self._data
        for particle_i = 1, self._n_particles do
            local buffer_i = (particle_i - 1) * buffer_stride

            love.graphics.setColor(
                data[buffer_i + buffer_r_offset],
                data[buffer_i + buffer_g_offset],
                data[buffer_i + buffer_b_offset],
                data[buffer_i + buffer_a_offset]
            )

            love.graphics.circle("fill",
                data[buffer_i + buffer_x_offset],
                data[buffer_i + buffer_y_offset],
                data[buffer_i + buffer_radius_offset]
            )
        end
    else
        local data = self._data_buffer_data:get_native()
        local particle_data = self._data
        local buffer_x_offset = self._data_buffer:get_byte_offset(1, 1)
        local buffer_y_offset = self._data_buffer:get_byte_offset(1, 2)
        local buffer_radius_offset = self._data_buffer:get_byte_offset(2, 1)
        local buffer_r_offset = self._data_buffer:get_byte_offset(3, 1)
        local buffer_g_offset = self._data_buffer:get_byte_offset(3, 2)
        local buffer_b_offset = self._data_buffer:get_byte_offset(3, 3)
        local buffer_a_offset = self._data_buffer:get_byte_offset(3, 4)
        local buffer_stride = self._data_buffer:get_element_stride()

        for particle_i = 1, self._n_particles do
            local particle_data_i = _particle_i_to_data_offset(particle_i, self._particle_stride)
            local buffer_i = (particle_i - 1) * buffer_stride

            love.graphics.setColor(
                data:getFloat(buffer_i + buffer_r_offset),
                data:getFloat(buffer_i + buffer_g_offset),
                data:getFloat(buffer_i + buffer_b_offset),
                data:getFloat(buffer_i + buffer_a_offset)
            )

            love.graphics.circle("fill",
                data:getFloat(buffer_i + buffer_x_offset),
                data:getFloat(buffer_i + buffer_y_offset),
                data:getFloat(buffer_i + buffer_radius_offset)
            )
        end
    end
end

--- @brief
function ow.Fluid:_debug_draw_spatial_hash()
    local x_offset, y_offset = self._particle_min_x, self._particle_min_y
    love.graphics.push()

    local max_count = 0
    for cell in values(self._spatial_hash) do
        max_count = math.max(max_count, cell[self._spatial_hash_particle_count_index])
    end

    local cell_size = self._spatial_hash_cell_radius
    local offset_x, offset_y = _xy_to_spatial_hash_xy(
        0, 0,
        self._particle_min_x, self._particle_min_y,
        self._particle_area_width, self._particle_area_height,
        cell_size
    )
    love.graphics.translate(-offset_x, -offset_y)

    local n_rows, n_columns = self._spatial_hash_n_rows, self._spatial_hash_n_columns
    for row_i = 1, n_rows do
        for col_i = 1, n_columns do
            local x, y = (row_i - 1) * cell_size, (col_i - 1) * cell_size

            local cell_x, cell_y = _spatial_hash_xy_to_cell_xy(x, y, cell_size, n_rows, n_columns)
            local linear_index = _cell_xy_to_linear_index(cell_x, cell_y, n_rows, n_columns)
            local cell = self._spatial_hash[linear_index]

            local opacity = cell[self._spatial_hash_particle_count_index] / max_count
            opacity = opacity ^ (1 / 3.5)
            local r, g, b, a = rt.lcha_to_rgba(0.8, 1, opacity, opacity)
            love.graphics.setColor(r, g, b, a)
            love.graphics.rectangle("fill",
                x, y, cell_size, cell_size
            )
        end
    end

    love.graphics.pop()
end

--- @brief
function ow.Fluid:_debug_draw_segments()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    for segment_i = 1, self._n_segments do
        local segment_offset = _particle_i_to_data_offset(segment_i, _segment_stride)
        local x1 = self._segments[segment_offset + _segment_x1_offset]
        local y1 = self._segments[segment_offset + _segment_y1_offset]
        local x2 = self._segments[segment_offset + _segment_x2_offset]
        local y2 = self._segments[segment_offset + _segment_y2_offset]
        love.graphics.line(x1, y1, x2, y2)
    end
end

--- @brief
function ow.Fluid:draw()
    love.graphics.setColor(1, 1, 1, 1)

    if self._canvas_needs_update then
        love.graphics.push("all")
        love.graphics.reset()
        self._canvas:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.translate(-self._particle_min_x + self._canvas_padding, -self._particle_min_y + self._canvas_padding)
        _instance_draw_shader:bind()
        self._instance_mesh:draw_instanced(self._n_particles)
        _instance_draw_shader:unbind()
        self._canvas:unbind()
        love.graphics.pop()
        self._canvas_needs_update = false
    end

    love.graphics.push()
    love.graphics.translate(self._particle_min_x - self._canvas_padding, self._particle_min_y - self._canvas_padding)
    love.graphics.setBlendMode("alpha", "premultiplied")
    self._canvas:draw()
    love.graphics.setBlendMode("alpha", "alphamultiply")
    love.graphics.pop()

    --self:_debug_draw_segments()
    --self:_debug_draw_particles()
    --self:_debug_draw_spatial_hash()
end
