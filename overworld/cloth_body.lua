require "common.mesh"
require "common.render_texture_3d"
require "common.transform"

rt.settings.overworld.cloth_body = {
    n_strands = 16,
    n_segments_per_strand = 8,

    n_iterations = {
        velocity = 8,
        distance = 8,
        axis = 1,
        bending = 3
    }
}

--- @class ow.ClothBody
ow.ClothBody = meta.class("ClothBody")

local settings = rt.settings.overworld.cloth_body

--- @brief
function ow.ClothBody:instantiate(center_x, center_y, center_z, width, height)
    self._view_transform = rt.Transform()
    self._view_transform:look_at(
        0,  0,  0, -- eye xyz
        0,  0,  1, -- target xyz
        0, -1,  0  -- up xyz
    )

    self._model_transform = rt.Transform()

    self._mesh = nil -- rt.Mesh
    self._canvas = nil -- rt.RenderTexture3D

    self:_init(
        center_x - 0.5 * width, center_y - 0.5 * height, center_z, -- top left
        center_x + 0.5 * width, center_y + 0.5 * height, center_z, -- bottom right
         0.15 * math.min(width, height), -- inner radius
        settings.n_strands,
        settings.n_segments_per_strand
    )
end

--- @brief
function ow.ClothBody:draw()
    love.graphics.push("all")
    self._canvas:bind()
    love.graphics.reset()
    self._canvas:set_view_transform(self._view_transform)
    self._canvas:set_model_transform(self._model_transform)

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setWireframe(true)
    self._mesh:draw()
    love.graphics.setWireframe(false)

    self._canvas:unbind()
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
    self._canvas:draw()
end

--- @brief
function ow.ClothBody:_init(
    top_left_x, top_left_y, top_left_z,
    bottom_right_x, bottom_right_y, bottom_right_z,
    inner_radius, n_strands, n_segments_per_strand
)
    local mesh_data = {}
    local mesh_vertex_indices = {} -- 1-based
    local function add_vertex(x, y, z)
        table.insert(mesh_data, { x, y, z, 0, 0, 1, 1, 1, 1 })
    end

    -- Calculate the direction vectors for the plane
    local dx, dy, dz = math.normalize3(math.subtract3(
        bottom_right_x, bottom_right_y, bottom_right_z,
        top_left_x, top_left_y, top_left_z
    ))

    local center_x, center_y, center_z = math.mix3(
        bottom_right_x, bottom_right_y, bottom_right_z,
        top_left_x, top_left_y, top_left_z,
        0.5
    )

    local right_x, right_y, right_z = math.normalize3(math.subtract3(
        bottom_right_x, bottom_right_y, bottom_right_z,
        top_left_x, top_left_y, top_left_z
    ))


    local normal_x, normal_y, normal_z
    do
        local edge1_x = bottom_right_x - top_left_x
        local edge1_y = 0
        local edge1_z = 0

        local edge2_x = 0
        local edge2_y = bottom_right_y - top_left_y
        local edge2_z = 0

        normal_x, normal_y, normal_z = math.normalize3(math.cross3(
            edge1_x, edge1_y, edge1_z,
            edge2_x, edge2_y, edge2_z
        ))
    end

    local up_x, up_y, up_z = math.normalize3(math.cross3(
        normal_x, normal_y, normal_z,
        right_x, right_y, right_z
    ))

    local strands = {}
    for i = 1, n_strands do
        local angle = (i - 1) * 2 * math.pi / n_strands  -- FIX: proper angle distribution

        local center_offset_x = (math.cos(angle) * right_x + math.sin(angle) * up_x) * inner_radius
        local center_offset_y = (math.cos(angle) * right_y + math.sin(angle) * up_y) * inner_radius
        local center_offset_z = (math.cos(angle) * right_z + math.sin(angle) * up_z) * inner_radius

        add_vertex(
            center_x + center_offset_x,
            center_y + center_offset_y,
            center_z + center_offset_z
        )

        local axis_x = math.cos(angle) * right_x + math.sin(angle) * up_x
        local axis_y = math.cos(angle) * right_y + math.sin(angle) * up_y
        local axis_z = math.cos(angle) * right_z + math.sin(angle) * up_z

        table.insert(strands, {
            anchor_x = center_offset_x,
            anchor_y = center_offset_y,
            anchor_z = center_offset_z,

            axis_x = axis_x,
            axis_y = axis_y,
            axis_z = axis_z,

            last_positions = {
                center_x + center_offset_x,
                center_y + center_offset_y,
                center_z + center_offset_z
            },

            last_velocities = { 0, 0, 0 },
            vertex_indices = { #mesh_data },
            masses = { 1 },
        })
    end

    local width, height = bottom_right_x - top_left_x, bottom_right_y - top_left_y
    local segment_length = (math.sqrt((0.5 * width)^2 + (0.5 * height)^2) - inner_radius) / n_segments_per_strand
    for segment_i = 1, n_segments_per_strand do
        for strand_i = 1, n_strands do
            local strand = strands[strand_i]

            local current_n = #strand.last_positions
            local last_x = strand.last_positions[current_n - 2]
            local last_y = strand.last_positions[current_n - 1]
            local last_z = strand.last_positions[current_n - 0]

            local current_x = last_x + strand.axis_x * segment_length
            local current_y = last_y + strand.axis_y * segment_length
            local current_z = last_z + strand.axis_z * segment_length

            for position in range(current_x, current_y, current_z) do
                table.insert(strand.last_positions, position)
                table.insert(strand.last_velocities, 0)
            end

            table.insert(strand.masses, 1)

            add_vertex(current_x, current_y, current_z)
        end
    end

    for i = 1, n_strands do
        local next_i = (i % n_strands) + 1

        table.insert(mesh_vertex_indices, i)
        table.insert(mesh_vertex_indices, next_i)
        table.insert(mesh_vertex_indices, n_strands + i)

        table.insert(mesh_vertex_indices, n_strands + i)
        table.insert(mesh_vertex_indices, next_i)
        table.insert(mesh_vertex_indices, n_strands + next_i)
    end

    for segment_i = 1, n_segments_per_strand - 1 do
        for strand_i = 1, n_strands do
            local next_strand_i = (strand_i % n_strands) + 1

            local v1 = n_strands + (segment_i - 1) * n_strands + strand_i
            local v2 = n_strands + (segment_i - 1) * n_strands + next_strand_i
            local v3 = n_strands + segment_i * n_strands + strand_i
            local v4 = n_strands + segment_i * n_strands + next_strand_i

            table.insert(mesh_vertex_indices, v1)
            table.insert(mesh_vertex_indices, v2)
            table.insert(mesh_vertex_indices, v3)

            table.insert(mesh_vertex_indices, v3)
            table.insert(mesh_vertex_indices, v2)
            table.insert(mesh_vertex_indices, v4)
        end
    end

    self._mesh = rt.Mesh(
        mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STREAM
    )

    self._mesh:set_vertex_map(mesh_vertex_indices)

    self._canvas = rt.RenderTexture3D(
        width, height
    )
end

ow.ClothBody._solve_distance_constraint_3d = function(
    a_x, a_y, a_z,
    b_x, b_y, b_z,
    mass_a, mass_b,
    rest_length
)
    local current_distance = math.max(1, math.distance3(a_x, a_y, a_z, b_x, b_y, b_z))

    local delta_x = b_x - a_x
    local delta_y = b_y - a_y
    local delta_z = b_z - a_z

    local distance_correction = (current_distance - rest_length) / current_distance
    local correction_x = delta_x * distance_correction
    local correction_y = delta_y * distance_correction
    local correction_z = delta_z * distance_correction

    local total_mass = mass_a + mass_b
    local blend_a = mass_b / total_mass
    local blend_b = mass_a / total_mass

    a_x = a_x + correction_x * blend_a
    a_y = a_y + correction_y * blend_a
    a_z = a_z + correction_z * blend_a

    b_x = b_x - correction_x * blend_b
    b_y = b_y - correction_y * blend_b
    b_z = b_z - correction_z * blend_b

    return a_x, a_y, a_z, b_x, b_y, b_z
end

ow.ClothBody._solve_axis_constraint_3d = function(
    a_x, a_y, a_z,
    b_x, b_y, b_z,
    axis_x, axis_y, axis_z,
    mass_a, mass_b,
    intensity
)
    if intensity == nil then intensity = 1 end

    local delta_x = b_x - a_x
    local delta_y = b_y - a_y
    local delta_z = b_z - a_z

    local dot_product = math.abs(delta_x * axis_x + delta_y * axis_y + delta_z * axis_z)

    local projection_x = dot_product * axis_x
    local projection_y = dot_product * axis_y
    local projection_z = dot_product * axis_z

    local correction_x = (projection_x - delta_x)
    local correction_y = (projection_y - delta_y)
    local correction_z = (projection_z - delta_z)

    local total_mass = mass_a + mass_b
    local blend_a = math.mix(0, mass_b / total_mass, intensity)
    local blend_b = math.mix(0, mass_a / total_mass, intensity)

    a_x = a_x - correction_x * blend_a
    a_y = a_y - correction_y * blend_a
    a_z = a_z - correction_z * blend_a

    b_x = b_x + correction_x * blend_b
    b_y = b_y + correction_y * blend_b
    b_z = b_z + correction_z * blend_b

    return a_x, a_y, a_z, b_x, b_y, b_z
end


ow.ClothBody._solve_bending_constraint_3d = function(
    a_x, a_y, a_z,
    b_x, b_y, b_z,
    c_x, c_y, c_z,
    mass_a, mass_b, mass_c,
    stiffness
)
    local ab_x = b_x - a_x
    local ab_y = b_y - a_y
    local ab_z = b_z - a_z

    local bc_x = c_x - b_x
    local bc_y = c_y - b_y
    local bc_z = c_z - b_z

    ab_x, ab_y, ab_z = math.normalize3(ab_x, ab_y, ab_z)
    bc_x, bc_y, bc_z = math.normalize3(bc_x, bc_y, bc_z)

    local target_x = ab_x + bc_x
    local target_y = ab_y + bc_y
    local target_z = ab_z + bc_z

    local correction_x = target_x * stiffness
    local correction_y = target_y * stiffness
    local correction_z = target_z * stiffness

    -- inverse-mass weighting
    local inv_mass_sum = (1 / mass_a) + (1 / mass_b) + (1 / mass_c)
    local blend_a = (1 / mass_a) / inv_mass_sum
    local blend_b = (1 / mass_b) / inv_mass_sum
    local blend_c = (1 / mass_c) / inv_mass_sum

    a_x = a_x - correction_x * blend_a
    a_y = a_y - correction_y * blend_a
    a_z = a_z - correction_z * blend_a

    b_x = b_x + correction_x * blend_b
    b_y = b_y + correction_y * blend_b
    b_z = b_z + correction_z * blend_b

    c_x = c_x + correction_x * blend_c
    c_y = c_y + correction_y * blend_c
    c_z = c_z + correction_z * blend_c

    return a_x, a_y, a_z, b_x, b_y, b_z, c_x, c_y, c_z
end

--- @brief
ow.ClothBody._cloth_handler = function(data)
    local n_velocity_iterations, current_n_velocity_iterations = 0, settings.iterations.velocity, 0
    local n_distance_iterations, current_n_distance_iterations = 0, settings.iterations.distance, 0
    local n_axis_iterations, current_n_axis_iterations = 0, settings.iterations.axis, 0
    local n_bending_iterations, current_n_bending_iterations = 0, settings.iterations.bending, 0

    local velocity_done = n_velocity_iterations == 0
    local distance_done = n_distance_iterations == 0
    local axis_done = n_axis_iterations == 0
    local bending_done = n_bending_iterations == 0

    local positions = data.positions
    local last_positions = data.last_positions

    while not velocity_done
        or not distance_done
        or not axis_done
        or not bending_done
    do

        if not velocity_done then
            local mass_i = 1
            for i = 1, #positions, 2 do
                local current_x, current_y = positions[i+0], positions[i+1]
                if i == 1 then
                    current_x = data.position_x + rope.anchor_x
                    current_y = data.position_y + rope.anchor_y
                end

                local old_x, old_y = last_positions[i+0], last_positions[i+1]
                local mass = masses[mass_i]
                local before_x, before_y = current_x, current_y

                local velocity_x = (current_x - old_x) * data.velocity_damping
                local velocity_y = (current_y - old_y) * data.velocity_damping

                velocity_x = math.mix(velocity_x, last_velocities[i+0], data.inertia)
                velocity_y = math.mix(velocity_y, last_velocities[i+1], data.inertia)

                local attraction_x, attraction_y = 0, 0
                if data.attraction_magnitude > 0 then
                    local dx, dy = math.normalize(data.attraction_x - current_x, data.attraction_y - current_y)
                    attraction_x, attraction_y = dx * data.attraction_magnitude, dy * data.attraction_magnitude
                end

                -- sic: mass * gravity is intended
                positions[i+0] = current_x + velocity_x + mass * data.gravity_x * data.delta + attraction_x * mass
                positions[i+1] = current_y + velocity_y + mass * data.gravity_y * data.delta + attraction_y * mass

                last_positions[i+0] = before_x
                last_positions[i+1] = before_y

                last_velocities[i+0] = velocity_x
                last_velocities[i+1] = velocity_y

                mass_i = mass_i + 1
            end

            current_n_velocity_iterations = current_n_velocity_iterations + 1
            velocity_done = current_n_velocity_iterations >= n_velocity_iterations
        end

        if not distance_done then

            current_n_distance_iterations = current_n_distance_iterations + 1
            distance_done = current_n_distance_iterations >= n_distance_iterations
        end

        if not axis_done then

            current_n_axis_iterations = current_n_axis_iterations + 1
            axis_done = current_n_axis_iterations >= n_axis_iterations
        end

        if not bending_done then

            current_n_bending_iterations = current_n_bending_iterations + 1
            bending_done = current_n_bending_iterations >= n_bending_iterations
        end
    end
end