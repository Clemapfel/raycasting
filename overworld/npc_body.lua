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
local _shader = rt.Shader("overworld/~npc_body.glsl")

--- @brief
function ow.NPCBody:instantiate(
    top_left_x, top_left_y,
    width, height,
    hole_radius
)
    self._dilation_mesh = nil -- rt.Mesh
    self._canvas = nil -- rt.RenderTexture3D

    self._dilation = 0
    self._strands = {}

    local radius = math.min(width, height) / 2
    self:_init(
        top_left_x, top_left_y,
        top_left_x + width, top_left_y + height,
        radius, -- outer radius
        hole_radius, -- inner_radius
        _settings.n_strands,
        _settings.n_segments_per_strand
    )
end

--- @brief
function ow.NPCBody:_init(
    min_x, min_y,
    max_x, max_y,
    radius, inner_radius,
    n_strands, n_segments_per_strand
)
    local width, height = max_x - min_x, max_y - min_y
    self._dilation_canvas = rt.RenderTexture(
        width, height
    )

    local center_x, center_y, center_z = math.mix2(
        max_x, max_y,
        min_x, min_y,
        0.5
    )

    local mesh_data = {}
    local mesh_vertex_indices = {} -- 1-based
    local function add_vertex(x, y)
        local u = (x - min_x) / (max_x - min_x)
        local v = (y - min_y) / (max_y - min_y)
        table.insert(mesh_data, {
            x, y,
            u, v,
            1, 1, 1, 1
        })
    end

    self._strands = {}
    local strands = self._strands

    for i = 1, n_strands do
        local angle = (i - 1) * 2 * math.pi / n_strands
        strands[i] = {
            anchor_x = center_x,
            anchor_y = center_y,

            axis_x = math.cos(angle),
            axis_y = math.sin(angle),

            nodes = {}
        }
    end

    local function easing(t)
        local k = 1.5
        return 0.5 * (1 + math.erf((t - 0.5) * k))
    end

    local size = inner_radius
    local rest_length = radius
    local dilate_length = radius - inner_radius

    -- add vertices
    for segment_i = 1, n_segments_per_strand do
        for strand_i = 1, n_strands do
            local current_i = segment_i - 1
            local next_i = current_i + 1

            local strand = strands[strand_i]
            local has_next = segment_i < n_segments_per_strand

            local distance_a, distance_b
            local t = current_i / n_segments_per_strand
            distance_a = t * rest_length

            if has_next then
                distance_b = math.min(inner_radius + easing(t) * dilate_length, radius)
            end

            -- position at min dilation
            local current_x = strand.anchor_x + strand.axis_x * distance_a
            local current_y = strand.anchor_y + strand.axis_y * distance_a

            local next_x, next_y -- position at max dilation
            if has_next then
                next_x = strand.anchor_x + strand.axis_x * distance_b
                next_y = strand.anchor_y + strand.axis_y * distance_b
            end

            add_vertex(current_x, current_y)

            table.insert(strand.nodes, {
                current_x = current_x,
                current_y = current_y,

                next_x = next_x,
                next_y = next_y,

                has_next = has_next,
                vertex_index = #mesh_data
            })
        end
    end

    -- triangulate
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
        local corner_start_index = #mesh_data + 1
        add_vertex(min_x, min_y)
        add_vertex(max_x, min_y)
        add_vertex(min_x, max_y)
        add_vertex(max_x, max_y)

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

        do -- fill cardinal direction gaps
            local right_strand = math.floor(n_strands * 0 / 4) + 1
            local bottom_strand = math.floor(n_strands * 1 / 4) + 1
            local left_strand = math.floor(n_strands * 2 / 4) + 1
            local top_strand = math.floor(n_strands * 3 / 4) + 1

            local top_vertex_i = (outer_segment - 1) * n_strands + top_strand
            local right_vertex_i = (outer_segment - 1) * n_strands + right_strand
            local bottom_vertex_i = (outer_segment - 1) * n_strands + bottom_strand
            local left_vertex_i = (outer_segment - 1) * n_strands + left_strand

            table.insert(mesh_vertex_indices, top_vertex_i)
            table.insert(mesh_vertex_indices, top_left)
            table.insert(mesh_vertex_indices, top_right)

            table.insert(mesh_vertex_indices, right_vertex_i)
            table.insert(mesh_vertex_indices, top_right)
            table.insert(mesh_vertex_indices, bottom_right)

            table.insert(mesh_vertex_indices, bottom_vertex_i)
            table.insert(mesh_vertex_indices, bottom_right)
            table.insert(mesh_vertex_indices, bottom_left)

            table.insert(mesh_vertex_indices, left_vertex_i)
            table.insert(mesh_vertex_indices, bottom_left)
            table.insert(mesh_vertex_indices, top_left)
        end
    end

    self._dilation_mesh_data = mesh_data
    self._dilation_mesh = rt.Mesh(
        mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat,
        rt.GraphicsBufferUsage.STREAM
    )
    self._dilation_mesh:set_vertex_map(mesh_vertex_indices)
    self._dilation_mesh:set_texture(self._dilation_canvas)

    self._dilation_background = rt.AABB(
        min_x, min_y, max_x - min_x, max_y - min_y
    )

    self:_update_dilation()
end

--- @brief
function ow.NPCBody:_update_dilation()
    local min_i, max_i = math.huge, -math.huge
    for strand in values(self._strands) do
        for node in values(strand.nodes) do
            local x, y
            if node.has_next == false then
                x, y = node.current_x, node.current_y
            else
                x, y = math.mix2(
                    node.current_x, node.current_y,
                    node.next_x, node.next_y,
                    self._dilation
                )
            end

            local data = self._dilation_mesh_data[node.vertex_index]
            min_i = math.min(min_i, node.vertex_index)
            max_i = math.max(max_i, node.vertex_index)

            data[1], data[2] = x, y
        end
    end

    self._dilation_mesh:replace_data(self._dilation_mesh_data)
end

function ow.NPCBody:update(delta)
    -- noop
end

--- @brief
function ow.NPCBody:set_dilation(t)
    self._dilation = t
    self:_update_dilation()
end

--- @brief
function ow.NPCBody:get_texture()
    return self._dilation_canvas
end

--- @brief
function ow.NPCBody:draw()
    rt.Palette.BLACK:bind()
    love.graphics.rectangle("fill", self._dilation_background:unpack())

    --love.graphics.setWireframe(true)
    love.graphics.setColor(1, 1, 1, 1)
    self._dilation_mesh:draw()
    --love.graphics.setWireframe(false)
end
