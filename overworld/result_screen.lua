require "common.timed_animation_sequence"
require "menu.stage_grade_label"
require "common.translation"
require "common.label"

rt.settings.overworld.result_screen = {
    flow_step = 1 / 100, -- fraction
    time_step = 1, -- seconds
    coins_step = 1, -- count
}


--- @class ow.ResultScreen
ow.ResultScreen = meta.class("ResultScreen", rt.Widget)

--- @brief
function ow.ResultScreen:instantiate()
    self._mesh_animation = rt.TimedAnimation(2, 0, 1, rt.InterpolationFunctions.LINEAR)
end

--- @brief
function ow.ResultScreen:present(x, y)
    self._mesh_animation:reset()
    self:update(0)
end

--- @brief
function ow.ResultScreen:realize()

end

function ow.ResultScreen:size_allocate(x, y, width, height)
    local mesh_w, mesh_h = 0.5 * width, 0.5 * height
    self._mesh_area = rt.AABB(
        x + 0.5 * width - 0.5 * mesh_w,
        y + 0.5 * height - 0.5 * mesh_h,
        mesh_w, mesh_h
    )

    -- setup animation paths
    local center_x = self._mesh_area.x + 0.5 * self._mesh_area.width
    local center_y = self._mesh_area.y + 0.5 * self._mesh_area.height
    local x_radius = 0.5 * self._mesh_area.width
    local y_radius = x_radius

    local n_outer_vertices
    local outline_width = 50

    -- Calculate rectangle bounds (inner and outer)
    local inner_rect, outer_rect

    do
        local sides = {}

        local rx, ry, w, h = self._mesh_area:unpack()
        outer_rect = rt.Path(
            rx + 0, ry + 0,
            rx + w, ry + 0,
            rx + w, ry + h,
            rx + 0, ry + h,
            rx + 0, ry + 0
        )

        local ow, oh = w, h -- outer size

        rx, ry, w, h = rx + outline_width, ry + outline_width, w - 2 * outline_width, h - 2 * outline_width
        inner_rect = rt.Path(
            rx + 0, ry + 0,
            rx + w, ry + 0,
            rx + w, ry + h,
            rx + 0, ry + h,
            rx + 0, ry + 0
        )

        local iw, ih = w, h -- inner size
        local gcd = math.gcd(
            iw,
            iw + ih,
            iw + ih + iw,
            iw + ih + iw + ih,
            iw + ih + iw + ih + ow,
            iw + ih + iw + ih + ow + oh,
            iw + ih + iw + ih + ow + oh + ow,
            iw + ih + iw + ih + ow + oh + ow + oh
        )

        n_outer_vertices = (iw + ih + iw + ih + ow + oh + ow + oh) / gcd
    end

    self._vertex_i_to_path = {}
    self._vertex_i_to_path_weight = {}
    self._mesh_data = {}

    -- Add center vertex
    table.insert(self._mesh_data, {
        center_x, center_y, -- xy
        0.5, 0.5,           -- uv (center of texture)
        1, 1, 1, 1          -- rgba
    })

    local vertex_i = 2 -- Start from 2 since center is at index 1
    local max_inner_path_length, max_outer_path_length = -math.huge, -math.huge

    -- Generate ring vertices (inner and outer pairs)
    for i = 1, n_outer_vertices do
        local angle = (i - 1) / n_outer_vertices * (2 * math.pi)
        local cos_a, sin_a = math.cos(angle), math.sin(angle)

        -- Inner ring vertex
        local ring_inner_x = center_x + cos_a * (x_radius - outline_width)
        local ring_inner_y = center_y + sin_a * (y_radius - outline_width)

        -- Outer ring vertex
        local ring_outer_x = center_x + cos_a * x_radius
        local ring_outer_y = center_y + sin_a * y_radius

        -- Inner rectangle vertex
        local t = math.fract(angle / (2 * math.pi) + 0.75)
        local rect_inner_x, rect_inner_y = inner_rect:at(t)

        -- Outer rectangle vertex
        local rect_outer_x, rect_outer_y = outer_rect:at(t)

        -- Create animation paths
        local inner_path = rt.Path(
            center_x, center_y,
            ring_inner_x, ring_inner_y,
            rect_inner_x, rect_inner_y
        )
        self._vertex_i_to_path[vertex_i] = inner_path

        local inner_length = inner_path:get_length()
        self._vertex_i_to_path_weight[vertex_i] = inner_length
        max_inner_path_length = math.max(max_inner_path_length, inner_length)

        local outer_path = rt.Path(
            center_x, center_y,
            ring_outer_x, ring_outer_y,
            rect_outer_x, rect_outer_y
        )
        self._vertex_i_to_path[vertex_i + 1] = outer_path

        outer_path = outer_path:get_length()
        self._vertex_i_to_path_weight[vertex_i + 1] = outer_path
        max_outer_path_length = math.max(max_outer_path_length, outer_path)

        -- Add inner vertex to mesh data
        table.insert(self._mesh_data, {
            ring_inner_x, ring_inner_y, -- xy (starting position)
            (cos_a + 1) * 0.5, (sin_a + 1) * 0.5, -- uv (normalized)
            1, 1, 1, 1 -- rgba (inner color)
        })

        -- Add outer vertex to mesh data
        table.insert(self._mesh_data, {
            ring_outer_x, ring_outer_y, -- xy (starting position)
            (cos_a + 1) * 0.5, (sin_a + 1) * 0.5, -- uv (normalized)
            0, 0, 0, 1 -- rgba (outer color)
        })

        vertex_i = vertex_i + 2
    end

    -- Generate triangulation indices
    local vertex_map = {}

    for i = 1, n_outer_vertices do
        local current_inner = 2 * i      -- Current inner vertex (1-indexed, accounting for center)
        local current_outer = 2 * i + 1  -- Current outer vertex

        local next_i = (i % n_outer_vertices) + 1
        local next_inner = 2 * next_i
        local next_outer = 2 * next_i + 1

        -- Triangle 1: center -> current_inner -> next_inner
        table.insert(vertex_map, 1)             -- center
        table.insert(vertex_map, current_inner)
        table.insert(vertex_map, next_inner)

        -- Triangle 2: current_inner -> current_outer -> next_outer
        table.insert(vertex_map, current_inner)
        table.insert(vertex_map, current_outer)
        table.insert(vertex_map, next_outer)

        -- Triangle 3: current_inner -> next_outer -> next_inner
        table.insert(vertex_map, current_inner)
        table.insert(vertex_map, next_outer)
        table.insert(vertex_map, next_inner)
    end

    self._vertex_map = vertex_map

    self._mesh = rt.Mesh(
        self._mesh_data,
        rt.MeshDrawMode.TRIANGLES,
        rt.VertexFormat,
        rt.GraphicsBufferUsage.STREAM
    )

    self._mesh:set_vertex_map(vertex_map)

    for i, weight in pairs(self._vertex_i_to_path_weight) do
        if i % 2 == 0 then
            self._vertex_i_to_path_weight[i] = max_inner_path_length / weight
        else
            self._vertex_i_to_path_weight[i] = max_outer_path_length / weight
        end
    end
end

--- @brief
function ow.ResultScreen:update(delta)
    self._mesh_animation:update(delta)
    local t = self._mesh_animation:get_value()

    self._dbg = {}
    for i, path in pairs(self._vertex_i_to_path) do
        local x, y =  path:at(t * self._vertex_i_to_path_weight[i])
        self._mesh_data[i][1], self._mesh_data[i][2] = x, y
        table.insert(self._dbg, x)
        table.insert(self._dbg, y)
    end

    self._mesh:replace_data(self._mesh_data)
end

--- @brief
function ow.ResultScreen:draw()
    love.graphics.setColor(1, 1, 1, 1)
    --love.graphics.draw(self._mesh:get_native())

    love.graphics.setPointSize(3)
    love.graphics.points(self._dbg)
end
