require "common.mesh"
require "common.render_texture_3d"
require "common.transform"
require "common.path_3d"

rt.settings.overworld.cloth_body = {
    n_strands = 32,
    n_segments_per_strand = 8,

    n_iterations = {
        velocity = 8,
        distance = 8,
        axis = 1,
        bending = 3
    }
}

--- @class ow.NPCBody
ow.NPCBody = meta.class("NPCBody")

local _settings = rt.settings.overworld.cloth_body
local _shader = rt.Shader("overworld/npc_body.glsl")

--- @brief
function ow.NPCBody:instantiate(
    center_x, center_y, center_z,
    width, height,
    hole_radius
)
    self._view_transform = rt.Transform()
    self._view_transform:look_at(
        0,  0,  0, -- eye xyz
        0,  0,  1, -- target xyz
        0, -1,  0  -- up xyz
    )

    self._model_transform = rt.Transform()

    self._mesh = nil -- rt.Mesh
    self._canvas = nil -- rt.RenderTexture3D

    self._dilation = 0
    self._strands = {}

    local radius = math.max(width, height)
    self:_init(
        center_x - 0.5 * width, center_y - 0.5 * height, center_z, -- top left
        center_x + 0.5 * width, center_y + 0.5 * height, center_z, -- bottom right
        radius, -- outer radius
        hole_radius, -- inner_radius
        _settings.n_strands,
        _settings.n_segments_per_strand
    )
end

--- @brief
function ow.NPCBody:_init(
    top_left_x, top_left_y, top_left_z,
    bottom_right_x, bottom_right_y, bottom_right_z,
    radius, inner_radius,
    n_strands, n_segments_per_strand
)
    local width, height = bottom_right_x - top_left_x, bottom_right_y - top_left_y
    self._canvas = rt.RenderTexture3D(
        width, height
    )

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


    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge

    local mesh_data = {}
    local mesh_vertex_indices = {} -- 1-based
    local function add_vertex(x, y, z, hue)
        min_x = math.min(min_x, x)
        min_y = math.min(min_y, y)
        max_x = math.max(max_x, x)
        max_y = math.max(max_y, y)

        table.insert(mesh_data, { x, y, z, 0, 0, rt.lcha_to_rgba(0.8,1, hue, 1) })
    end

    self._strands = {}
    local strands = self._strands

    -- First, add all inner circle vertices
    for i = 1, n_strands do
        local angle = (i - 1) * 2 * math.pi / n_strands

        local center_offset_x = 0 --(math.cos(angle) * right_x + math.sin(angle) * up_x) * inner_radius
        local center_offset_y = 0 --(math.cos(angle) * right_y + math.sin(angle) * up_y) * inner_radius
        local center_offset_z = 0 --(math.cos(angle) * right_z + math.sin(angle) * up_z) * inner_radius

        local axis_x = math.cos(angle) * right_x + math.sin(angle) * up_x
        local axis_y = math.cos(angle) * right_y + math.sin(angle) * up_y
        local axis_z = math.cos(angle) * right_z + math.sin(angle) * up_z

        local strand = {
            anchor_x = center_x + center_offset_x,
            anchor_y = center_y + center_offset_y,
            anchor_z = center_z + center_offset_z,

            axis_x = axis_x,
            axis_y = axis_y,
            axis_z = axis_z,

            nodes = {},
        }

        strands[i] = strand
    end

    local function easing(t)
        return 1 - math.exp(-3 * t)
    end

    local rest_length = radius - inner_radius
    local default_segment_length = rest_length / n_segments_per_strand

    -- add vertices
    for segment_i = 1, n_segments_per_strand do
        for strand_i = 1, n_strands do
            local current_i = segment_i - 1
            local next_i = current_i + 1

            local strand = strands[strand_i]
            local has_next = segment_i < n_segments_per_strand

            local distance_a, distance_b

            if segment_i == 1 then
                -- inner most segment: dilate to inner radius
                distance_a = 0
                distance_b = inner_radius
            else
                -- outer segments: exponential easings
                local t_a = (current_i + 1) / (n_segments_per_strand - 1)
                distance_a = default_segment_length * easing(t_a)

                if has_next then
                    local t_b = (next_i + 1) / (n_segments_per_strand - 1)
                    distance_b = default_segment_length * easing(t_b)
                end
            end

            local current_x = strand.anchor_x + strand.axis_x * distance_a
            local current_y = strand.anchor_y + strand.axis_y * distance_a
            local current_z = strand.anchor_z + strand.axis_z * distance_a

            local next_x, next_y, next_z
            if has_next then
                next_x = strand.anchor_x + strand.axis_x * distance_b
                next_y = strand.anchor_y + strand.axis_y * distance_b
                next_z = strand.anchor_z + strand.axis_z * distance_b
            end

            add_vertex(current_x, current_y, current_z, current_i / n_segments_per_strand)

            table.insert(strand.nodes, {
                current_x = current_x,
                current_y = current_y,
                current_z = current_z,

                next_x = next_x,
                next_y = next_y,
                next_z = next_z,

                has_next = has_next,
                vertex_index = #mesh_data
            })
        end
    end

    -- triangulate the strands (quads between neighboring strands)
    for segment_i = 1, n_segments_per_strand - 1 do
        for strand_i = 1, n_strands do
            local next_strand_i = (strand_i % n_strands) + 1

            local v1 = (segment_i - 1) * n_strands + strand_i
            local v2 = (segment_i - 1) * n_strands + next_strand_i
            local v3 = (segment_i + 0) * n_strands + strand_i
            local v4 = (segment_i + 0) * n_strands + next_strand_i

            table.insert(mesh_vertex_indices, v1)
            table.insert(mesh_vertex_indices, v2)
            table.insert(mesh_vertex_indices, v3)

            table.insert(mesh_vertex_indices, v3)
            table.insert(mesh_vertex_indices, v2)
            table.insert(mesh_vertex_indices, v4)
        end
    end

    do -- add corners and connect them to the shape
        local corner_z = center_z
        local corner_hue = 1.0

        local corner_start_index = #mesh_data + 1
        add_vertex(min_x, min_y, corner_z, corner_hue)
        add_vertex(max_x, min_y, corner_z, corner_hue)
        add_vertex(min_x, max_y, corner_z, corner_hue)
        add_vertex(max_x, max_y, corner_z, corner_hue)

        local top_left = corner_start_index
        local top_right = corner_start_index + 1
        local bottom_left = corner_start_index + 2
        local bottom_right = corner_start_index + 3

        local outer_segment = n_segments_per_strand
        for strand_i = 1, n_strands do
            local next_strand_i = (strand_i % n_strands) + 1

            local current_i = (outer_segment - 1) * n_strands + strand_i
            local next_i = (outer_segment - 1) * n_strands + next_strand_i

            local current_data = mesh_data[current_i]
            local next_data = mesh_data[next_i]

            local current_x, current_y = current_data[1], current_data[2]
            local next_x, next_y = next_data[1], next_data[2]

            local mid_x = (current_x + next_x) / 2
            local mid_y = (current_y + next_y) / 2

            if mid_x <= center_x and mid_y <= center_y then
                table.insert(mesh_vertex_indices, current_i)
                table.insert(mesh_vertex_indices, next_i)
                table.insert(mesh_vertex_indices, top_left)
            elseif mid_x > center_x and mid_y <= center_y then
                table.insert(mesh_vertex_indices, current_i)
                table.insert(mesh_vertex_indices, next_i)
                table.insert(mesh_vertex_indices, top_right)
            elseif mid_x <= center_x and mid_y > center_y then
                table.insert(mesh_vertex_indices, current_i)
                table.insert(mesh_vertex_indices, next_i)
                table.insert(mesh_vertex_indices, bottom_left)
            else
                table.insert(mesh_vertex_indices, current_i)
                table.insert(mesh_vertex_indices, next_i)
                table.insert(mesh_vertex_indices, bottom_right)
            end
        end
    end

    -- uv mapping
    for data in values(mesh_data) do
        local x, y = data[1], data[2]
        local u = (x - min_x) / (max_x - min_x)
        local v = (y - min_y) / (max_y - min_y)
        data[4], data[5] = u, v
    end

    self._mesh_data = mesh_data
    self._mesh = rt.Mesh(
        mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat3D,
        rt.GraphicsBufferUsage.STREAM
    )
    self._mesh:set_vertex_map(mesh_vertex_indices)

    self:_update_dilation()
end

--- @brief
function ow.NPCBody:_update_dilation()
    local min_i, max_i = math.huge, -math.huge
    for strand in values(self._strands) do
        for node in values(strand.nodes) do
            local x, y, z
            if node.has_next == false then
                x, y, z = node.current_x, node.current_y, node.current_z
            else
                x, y, z = math.mix3(
                    node.current_x, node.current_y, node.current_z,
                    node.next_x, node.next_y, node.next_z,
                    self._dilation
                )
            end

            local data = self._mesh_data[node.vertex_index]
            min_i = math.min(min_i, node.vertex_index)
            max_i = math.max(max_i, node.vertex_index)

            data[1], data[2], data[3] = x, y, z
        end
    end

    self._mesh:replace_data(self._mesh_data)
end

--- @brief
function ow.NPCBody:set_dilation(t)
    self._dilation = t
    self:_update_dilation()
end

--- @brief
function ow.NPCBody:draw()
    love.graphics.push("all")
    self._canvas:bind()
    love.graphics.reset()
    self._canvas:set_view_transform(self._view_transform)
    self._canvas:set_model_transform(self._model_transform)

    _shader:bind()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(2)
    self._mesh:draw()
    _shader:unbind()

    self._canvas:unbind()
    love.graphics.pop()

    love.graphics.setColor(1, 1, 1, 1)
    self._canvas:draw()
end

--- @brief
function ow.NPCBody:update(delta)
    -- noop for now
end