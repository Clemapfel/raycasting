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

    spatial_hash_outer_size = 3000,

    follow_compliance = 0,
    segment_compliance = 0,
    collision_compliance = 0
}

--- @class ow.Fluid
ow.Fluid = meta.class("OverworldFluid")

--- @class ow.FluidBounds
ow.FluidBounds = meta.class("FluidBounds")

--- @brief
function ow.Fluid:instantiate(object, stage, scene)
    self._stage = stage
    self._scene = scene

    -- extract room
    local other = object:get_object("bounds", true)
    rt.assert(other:get_type() == ow.ObjectType.POLYGON, "In ow.Fluid: object `", other:get_id(), "` is not a polygon")

    local contour = other:create_contour()
    self._segments = {}
    for i = 1, #contour + 2, 2 do
        local x1 = contour[math.wrap(i + 0, #contour)]
        local y1 = contour[math.wrap(i + 1, #contour)]
        local x2 = contour[math.wrap(i + 2, #contour)]
        local y2 = contour[math.wrap(i + 3, #contour)]
        table.insert(self._segments, { x1, y1, x2, y2 })
    end
    self._n_segments = #self._segments

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
local _follow_x = 16
local _follow_y = 17
local _follow_lambda = 18
local _first_segment_lambda_offset = 19

local _particle_i_to_data_offset = function(particle_i, stride)
    return (particle_i - 1) * stride + 1
end

local _particle_ij_to_collision_lambda_i = function(i, j, n_particles)
    if i > j then i, j = j, i end
    return (i - 1) * n_particles - i * (i - 1) / 2 + (j - i)
end

local _n_particles_to_n_collision_lambdas = function(n_particles)
    return n_particles * (n_particles - 1) / 2
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

            data[i + _follow_x] = x
            data[i + _follow_y] = y
            data[i + _follow_lambda] = 0

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

    self._particle_min_x = min_x
    self._particle_min_y = min_y
    self._particle_max_x = max_x
    self._particle_max_y = max_y
    self._particle_centroid_x = center_x
    self._particle_centroid_y = center_y

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

        local cell_size = 2 * rt.settings.overworld.fluid.particles.radius
        local outer_r = rt.settings.overworld.fluid.spatial_hash_outer_size

        self._spatial_hash_n_particles_per_cell = n_particles_per_cell
        self._spatial_hash_cell_r = cell_size
        self._spatial_hash_r = outer_r

        local n_rows = math.ceil(outer_r / cell_size)
        local n_cols = n_rows

        self._spatial_hash_n_rows = n_rows
        self._spatial_hash_n_columns = n_cols

        self._spatial_hash = {}

        for x = 1, self._spatial_hash_n_rows do
            for y = 1, self._spatial_hash_n_columns do
                local entry = {
                    [1] = 0 -- first index is particle count
                }

                for i = 2, n_particles_per_cell + 1 do
                    entry[i] = -1
                end

                self._spatial_hash[_cell_xy_to_linear_index(x, y, n_rows, n_cols)] = entry
            end
        end
    end

    self._canvas_padding = rt.settings.overworld.fluid.particles.radius * rt.settings.overworld.fluid.texture_scale

    self:_resize_canvas() -- sets self._canvas_needs_update
    self:_update_data_mesh()
end

do -- update helpers
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

        local collision_lambdas = self._collision_lambdas

        local spatial_hash_cell_counts = {}
        local spatial_hash_cell_starts = {}

        local spatial_hash_n_particles_per_cell = self._spatial_hash_n_particles_per_cell
        local spatial_hash_cell_radius = 0.5 * settings.particles.radius
        local spatial_hash_n_rows = self._spatial_hash_n_rows
        local spatial_hash_n_cols = self._spatial_hash_n_columns
        local spatial_hash = self._spatial_hash

        local particle_min_x, particle_min_y = self._particle_min_x, self._particle_min_y

        for _ = 1, n_sub_steps do
            -- ### PRE SOLVE ###

            -- reset spatial hash
            for entry in values(spatial_hash) do
                entry[1] = 0 -- cell count, keep stale ids
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
                data[i + _follow_lambda] = 0

                -- reset segment lambdas
                for lambda_i = _first_segment_lambda_offset, _first_segment_lambda_offset + n_segments do
                    data[i + lambda_i] = 0
                end

                -- update spatial hash
                local radius = data[i + _radius_offset]

                local spatial_hash_x = x + (1 - math.floor((particle_min_x - radius) / spatial_hash_cell_radius)) * spatial_hash_cell_radius
                local spatial_hash_y = y + (1 - math.floor((particle_min_y - radius) / spatial_hash_cell_radius)) * spatial_hash_cell_radius

                local cell_x = math.floor(spatial_hash_x / spatial_hash_cell_radius)
                local cell_y = math.floor(spatial_hash_y / spatial_hash_cell_radius)
                data[i + _cell_x_offset] = cell_x
                data[i + _cell_y_offset] = cell_y

                local id = data[i + _id_offset]
                local min_col = math.floor((spatial_hash_x - radius) / spatial_hash_cell_radius) + 1
                local max_col = math.floor((spatial_hash_x + radius) / spatial_hash_cell_radius) + 1
                local min_row = math.floor((spatial_hash_y - radius) / spatial_hash_cell_radius) + 1
                local max_row = math.floor((spatial_hash_y + radius) / spatial_hash_cell_radius) + 1

                min_col = math.max(min_col, 1)
                max_col = math.min(max_col, spatial_hash_n_cols)
                min_row = math.max(min_row, 1)
                max_row = math.min(max_row, spatial_hash_n_rows)

                local cells = {}
                for row_i = min_row, max_row do
                    for col_i = min_col, max_col do
                        local cell_i = _cell_xy_to_linear_index(row_i, col_i, spatial_hash_n_rows, spatial_hash_n_cols)
                        local cell = spatial_hash[cell_i]

                        local offset = 1 + cell[1] + 1 -- first element is count
                        cell[1 + offset] = i -- store data offset
                        cell[1] = cell[1] + 1
                    end
                end
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
                    x, y,
                    data[i + _follow_x], data[i + _follow_y],
                    data[_follow_lambda]
                )

                data[i + _x_offset] = x + correction_x
                data[i + _y_offset] = y + correction_y
                data[i + _follow_lambda] = lambda
            end

            -- ### COLLISION ###

            for particle_i = 1, n_particles do
                local self_i = _particle_i_to_data_offset(particle_i, particle_stride)

                local cell_x = data[self_i + _cell_x_offset]
                local cell_y = data[self_i + _cell_y_offset]

                for x_offset = -1, 1 do
                    for y_offset = -1, 1 do
                        local cell_i = _cell_xy_to_linear_index(
                            cell_x + x_offset,
                            cell_y + y_offset,
                            spatial_hash_n_rows,
                            spatial_hash_n_cols
                        )

                        local cell = spatial_hash[cell_i]
                        for offset = 0, cell[1] do
                            local other_i = cell[2 + offset] -- data offset, not particle id
                            if other_i ~= self_i then
                                local lambda_i = _particle_ij_to_collision_lambda_i(self_i, other_i, n_particles)

                                local self_x_i = self_i + _x_offset
                                local self_y_i = self_i + _y_offset

                                local other_x_i = other_i + _x_offset
                                local other_y_i = other_i + _y_offset

                                local self_x, self_y = data[self_x_i], data[self_y_i]
                                local other_x, other_y = data[other_x_i], data[other_y_i]

                                local min_distance = data[self_i + _radius_offset], data[other_i + _radius_offset]

                                local distance = math.squared_distance(
                                    self_x, self_y, other_x, other_y
                                )

                                if distance < min_distance^2 then
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

            -- ### POST SOLVE ###

            local min_x, min_y = math.huge, math.huge
            local max_x, max_y = -math.huge, -math.huge
            local centroid_x, centroid_y = 0, 0

            local max_velocity = 0
            local max_radius = 0

            for particle_i = 1, n_particles do
                local i = _particle_i_to_data_offset(particle_i)

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

            self._particle_min_x = min_x
            self._particle_min_y = min_y
            self._particle_max_x = max_x
            self._particle_max_y = max_y
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
    local width = self._particle_max_x - self._particle_min_x
    local height = self._particle_max_y - self._particle_min_y
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
function ow.Fluid:_debug_draw_segments()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    for segment in values(self._segments) do
        love.graphics.line(segment)
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

    self:_debug_draw_segments()
end
