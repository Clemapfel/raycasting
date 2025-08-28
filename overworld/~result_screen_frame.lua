require "common.timed_animation_sequence"

--- @class ow.ResultScreenFrame
ow.ResultScreenFrame = meta.class("ResultScreenFrame", rt.Widget)
meta.add_signal(ow.ResultScreenFrame, "revealed")
meta.add_signal(ow.ResultScreenFrame, "hidden")

local _draw_shader, _mask_shader

--- @brief
function ow.ResultScreenFrame:instantiate()
    if _draw_shader == nil then _draw_shader = rt.Shader("overworld/result_screen_frame.glsl", { MODE = 0 }) end
    if _mask_shader == nil then
        _mask_shader = rt.Shader("overworld/result_screen_frame.glsl", { MODE = 1})
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "k" then
                _draw_shader:recompile()
                _mask_shader:recompile()
            end
        end)
    end

    self._mesh_animation = rt.AnimationChain(
        1, 0, 1, rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT
    )

    self._signal_emitted = false

    self._present_x, self._present_y = 0, 0
    self._rect_area = rt.AABB()
    self._vertex_i_to_path = {}
    self._mesh_data = {}
end

--- @brief
function ow.ResultScreenFrame:present(x, y)
    self._present_x, self._present_y = x, y
    self._mesh_animation:reset()
    self._signal_emitted = false
    self:_update_mesh_paths()
    self:update(0)
end

-- Create outer rounded rectangle path
local function create_rect_path(x, y, width, height, radius)
    local path_points = {}

    -- Clamp radius to not exceed half of smaller dimension
    radius = math.min(radius, width * 0.5, height * 0.5)

    -- Starting point: center of right side
    table.insert(path_points, x + width)
    table.insert(path_points, y + 0.5 * height)

    -- Right side to bottom-right corner start
    table.insert(path_points, x + width)
    table.insert(path_points, y + height - radius)

    -- Bottom-right rounded corner (quarter circle)
    local steps = 8 -- Number of steps for corner smoothness
    for i = 1, steps do
        local angle = (i / steps) * (math.pi * 0.5) -- 0 to 90 degrees
        local corner_x = x + width - radius + radius * math.cos(angle)
        local corner_y = y + height - radius + radius * math.sin(angle)
        table.insert(path_points, corner_x)
        table.insert(path_points, corner_y)
    end

    -- Bottom side
    table.insert(path_points, x + radius)
    table.insert(path_points, y + height)

    -- Bottom-left rounded corner
    for i = 1, steps do
        local angle = math.pi * 0.5 + (i / steps) * (math.pi * 0.5) -- 90 to 180 degrees
        local corner_x = x + radius + radius * math.cos(angle)
        local corner_y = y + height - radius + radius * math.sin(angle)
        table.insert(path_points, corner_x)
        table.insert(path_points, corner_y)
    end

    -- Left side
    table.insert(path_points, x)
    table.insert(path_points, y + radius)

    -- Top-left rounded corner
    for i = 1, steps do
        local angle = math.pi + (i / steps) * (math.pi * 0.5) -- 180 to 270 degrees
        local corner_x = x + radius + radius * math.cos(angle)
        local corner_y = y + radius + radius * math.sin(angle)
        table.insert(path_points, corner_x)
        table.insert(path_points, corner_y)
    end

    -- Top side
    table.insert(path_points, x + width - radius)
    table.insert(path_points, y)

    -- Top-right rounded corner
    for i = 1, steps do
        local angle = math.pi * 1.5 + (i / steps) * (math.pi * 0.5) -- 270 to 360 degrees
        local corner_x = x + width - radius + radius * math.cos(angle)
        local corner_y = y + radius + radius * math.sin(angle)
        table.insert(path_points, corner_x)
        table.insert(path_points, corner_y)
    end

    -- Return to starting point (center of right side)
    table.insert(path_points, x + width)
    table.insert(path_points, y + 0.5 * height)

    return rt.Path(table.unpack(path_points))
end

--- @brief
function ow.ResultScreenFrame:_update_mesh_paths()
    local origin_x = self._present_x
    local origin_y = self._present_y

    local rect_w = 0.75 * self._bounds.width
    local rect_h = 0.75 * self._bounds.height
    self._rect_area = rt.AABB(
        self._bounds.x + 0.5 * self._bounds.width - 0.5 * rect_w,
        self._bounds.y + 0.5 * self._bounds.height - 0.5 * rect_h,
        rect_w, rect_h
    )

    local x_radius = math.min(rect_w, rect_h) / 2
    local y_radius = x_radius

    local circle_x = self._bounds.x + 0.5 * self._bounds.width
    local circle_y = self._bounds.y + 0.5 * self._bounds.height

    local outline_width = 50

    local inner_rect, outer_rect -- rt.Paths
    local n_outer_vertices

    do -- compute n vertices such that setps fall exactly on corners of rectangle
        local sides = {}
        local rx, ry, w, h = self._rect_area:unpack()

        local corner_radius = math.min(w, h) * 0.1 -- 10% of the smaller dimension

        outer_rect = create_rect_path(rx, ry, w, h, corner_radius)

        local ow, oh = w, h -- outer size

        rx, ry, w, h = rx + outline_width, ry + outline_width, w - 2 * outline_width, h - 2 * outline_width

        -- Create inner rounded rectangle with smaller corner radius
        local inner_corner_radius = math.max(0, corner_radius - outline_width * 0.5)
        inner_rect = create_rect_path(rx, ry, w, h, inner_corner_radius)

        local iw, ih = w, h -- inner size

        local inner_step_size = math.gcd(
            iw,
            iw + ih,
            iw + ih + iw,
            iw + ih + iw + ih
        )

        local outer_step_size = math.gcd(
            ow,
            ow + oh,
            ow + oh + ow,
            ow + oh + ow + oh
        )

        local inner_length = (2 * iw + 2 * ih)
        local outer_length = (2 * ow + 2 * oh)

        n_outer_vertices = math.lcm(
            inner_length / inner_step_size,
            outer_length / outer_step_size
        )

        local k, n = 1, n_outer_vertices
        while n < 128 do
            k = k + 1
            n = n_outer_vertices * k
        end

        n_outer_vertices = n
    end

    n_outer_vertices = n_outer_vertices * math.ceil(rt.get_pixel_scale())
    n_outer_vertices = n_outer_vertices + 1 -- +1 for duplicate last tr

    local vertex_i_to_weight_entry = {}

    self._vertex_i_to_path = {}
    self._mesh_data = {}

    table.insert(self._mesh_data, {
        origin_x, origin_y,
        0, 0,
        1, 1, 1, 1
    })

    do
        local rect_x, rect_y = self._rect_area.x + 0.5 * self._rect_area.width, self._rect_area.y + 0.5 * self._rect_area.height
        local path = rt.Path(
            origin_x, origin_y,
            circle_x, circle_x,
            rect_x, rect_y
        )

        self._vertex_i_to_path[1] = path

        vertex_i_to_weight_entry[1] = {
            to_circle = math.distance(origin_x, origin_y, circle_x, circle_x),
            to_rect = math.distance(circle_x, circle_y, rect_x, rect_y)
        }
    end

    local vertex_i = 2 -- Start from 2 since center is at index 1
    local max_inner_to_circle, max_inner_to_rect = -math.huge, -math.huge
    local max_outer_to_circle, max_outer_to_rect = -math.huge, -math.huge

    -- Generate ring vertices (inner and outer pairs)
    for i = 1, n_outer_vertices do
        local angle = (i - 1) / (n_outer_vertices - 1) * (2 * math.pi)
        local cos_a, sin_a = math.cos(angle), math.sin(angle)

        -- Inner ring vertex
        local ring_inner_x = circle_x + cos_a * x_radius
        local ring_inner_y = circle_y + sin_a * y_radius

        -- Outer ring vertex
        local ring_outer_x = circle_x + cos_a * (x_radius + outline_width)
        local ring_outer_y = circle_y + sin_a * (y_radius + outline_width)

        -- Inner rectangle vertex
        local t = math.fract((i - 1) / (n_outer_vertices - 1))
        local rect_inner_x, rect_inner_y = inner_rect:at(t)

        -- Outer rectangle vertex
        local rect_outer_x, rect_outer_y = outer_rect:at(t)

        -- Create animation paths
        local inner_path = rt.Path(
            origin_x, origin_y,
            ring_inner_x, ring_inner_y,
            rect_inner_x, rect_inner_y
        )
        self._vertex_i_to_path[vertex_i] = inner_path

        local inner_length = inner_path:get_length()
        local inner_weight_entry = {
            to_circle = math.distance(origin_x, origin_y, ring_inner_x, ring_inner_y),
            to_rect = math.distance(ring_inner_x, ring_inner_y, rect_inner_x, rect_inner_y)
        }

        vertex_i_to_weight_entry[vertex_i] = inner_weight_entry

        max_inner_to_circle = math.max(max_inner_to_circle, inner_weight_entry.to_circle)
        max_inner_to_rect = math.max(max_inner_to_rect, inner_weight_entry.to_rect)

        local outer_path = rt.Path(
            origin_x + cos_a * outline_width, origin_y + sin_a * outline_width,
            ring_outer_x, ring_outer_y,
            rect_outer_x, rect_outer_y
        )
        self._vertex_i_to_path[vertex_i + 1] = outer_path

        local outer_weight_entry = {
            to_circle = math.distance(origin_x, origin_y, ring_outer_x, ring_outer_y),
            to_rect = math.distance(ring_outer_x, ring_outer_y, rect_outer_x, rect_outer_y)
        }

        vertex_i_to_weight_entry[vertex_i + 1] = outer_weight_entry
        max_outer_to_circle = math.max(max_outer_to_circle, outer_weight_entry.to_circle)
        max_outer_to_rect = math.max(max_outer_to_rect, outer_weight_entry.to_rect)

        local u = angle / (2 * math.pi)

        -- for last try, override uv to prevent interpolation between last and first trie
        if i == n_outer_vertices then u = 1 end

        -- Add inner vertex to mesh data
        local inner = {
            ring_inner_x, ring_inner_y, -- xy (starting position)
            u, 0,
            1, 1, 1, 1 -- rgba (inner color)
        }

        -- Add outer vertex to mesh data
        local outer = {
            ring_outer_x, ring_outer_y, -- xy (starting position)
            u, 1,
            0, 0, 0, 1 -- rgba (outer color)
        }

        table.insert(self._mesh_data, inner)
        table.insert(self._mesh_data, outer)

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

    local max_inner_total = max_inner_to_circle + max_inner_to_rect
    local max_outer_total = max_outer_to_circle + max_outer_to_rect

    for i, entry in ipairs(vertex_i_to_weight_entry) do
        local path = self._vertex_i_to_path[i]
        if i % 2 == 0 then -- inner
            local total = entry.to_circle + entry.to_rect

            -- Parameterize so that circle phase takes time proportional to max_inner_to_circle
            -- and rect phase takes time proportional to max_inner_to_rect
            local circle_time_ratio = max_inner_to_circle / max_inner_total
            local rect_time_ratio = max_inner_to_rect / max_inner_total

            path:override_parameterization(
                circle_time_ratio,
                rect_time_ratio
            )
        else -- outer
            local total = entry.to_circle + entry.to_rect

            -- Parameterize so that circle phase takes time proportional to max_outer_to_circle
            -- and rect phase takes time proportional to max_outer_to_rect
            local circle_time_ratio = max_outer_to_circle / max_outer_total
            local rect_time_ratio = max_outer_to_rect / max_outer_total

            path:override_parameterization(
                circle_time_ratio,
                rect_time_ratio
            )
        end
    end
end

function ow.ResultScreenFrame:size_allocate(x, y, width, height)
    self:_update_mesh_paths()
end

--- @brief
function ow.ResultScreenFrame:update(delta)
    if self._mesh == nil then return end

    self._mesh_animation:update(delta)
    local t = self._mesh_animation:get_value()

    self._dbg = {}
    for i, path in pairs(self._vertex_i_to_path) do
        local x, y =  path:at(t)
        self._mesh_data[i][1], self._mesh_data[i][2] = x, y
        table.insert(self._dbg, x)
        table.insert(self._dbg, y)
    end

    self._mesh:replace_data(self._mesh_data)

    if self._mesh_animation:get_fraction() >= 0.5 and self._signal_emitted == false then
        self:signal_emit("revealed")
        self._signal_emitted = true
    end
end

--- @brief
function ow.ResultScreenFrame:draw()
    if not self:get_is_realized() then return end

    love.graphics.setColor(1, 1, 1, 1)

    _mask_shader:bind()
    _mask_shader:send("elapsed", rt.SceneManager:get_elapsed())
    _mask_shader:send("black", { rt.Palette.BLACK:unpack() })
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._mesh:get_native())
    _mask_shader:unbind()

    _draw_shader:bind()
    _draw_shader:send("elapsed", rt.SceneManager:get_elapsed())
    _draw_shader:send("black", { rt.Palette.BLACK:unpack() })
    love.graphics.draw(self._mesh:get_native())
    _draw_shader:unbind()
end

--- @brief
function ow.ResultScreenFrame:draw_mask()
    _mask_shader:bind()
    _mask_shader:send("elapsed", rt.SceneManager:get_elapsed())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(self._mesh:get_native())
    _mask_shader:unbind()
end


