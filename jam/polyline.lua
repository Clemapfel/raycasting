Polyline_t = "Polyline"

polyline_new = function(...)
    local self = object_new(Polyline_t, {
        vertices = {},
        n_vertices = 0,
        signed_area = 0,
        signed_area_needs_update = false
    })

    return polyline_init(self, ...)
end

polyline_init = function(self, ...)
    log_typecheck(self, Polyline_t)

    local first = select(1, ...)

    local vertices
    if object_is_table(first) then
        vertices = first
    else
        vertices = { ... }
    end

    local n = #vertices
    log_assert(n % 2 == 0 and n >= 6,  "In polyline_init: expected an even number of coordinates, at least 3 points")

    self.vertices = vertices
    self.n_vertices = math_divide_ints(n, 2)
    self.signed_area_needs_update = true -- vertices changed, cached area is invalid
    return self
end

polyline_get_vertices = function(self)
    log_typecheck(self, Polyline_t)
    return self.vertices
end

polyline_translate = function(self, x, y)
    log_typecheck(self, Polyline_t, x, Number_t, y, Number_t)
    local data = self.vertices
    for i = 1, table_sizeof(self.vertices), 2 do
        data[i + 0] = data[i + 0] + x
        data[i + 1] = data[i + 1] + y
    end
    return self
end

polyline_draw = function(self)
    log_typecheck(self, Polyline_t)

    local data = self.vertices
    local n = table_sizeof(data)

    for i = 1, n - 2, 2 do
        graphics_draw_line(data[i + 0], data[i + 1], data[i + 2], data[i + 3])
    end
    graphics_draw_line(data[n - 1], data[n - 0], data[1], data[2])

    return self
end

polyline_close = function(self)
    log_typecheck(self, Polyline_t)

    local data = self.vertices
    local n = #data
    local ax, ay = data[1], data[2]
    local bx, by = data[n - 1], data[n]
    if math_distance(ax, ay, bx, by) > 1 then
        table_push(data, ax)
        table_push(data, ay)
        self.n_vertices = self.n_vertices + 1
        self.signed_area_needs_update = true
    end
    return self
end

polyline_is_closed = function(self)
    log_typecheck(self, Polyline_t)

    local data = self.vertices
    local n = #data
    return math_distance(data[1], data[2], data[n - 1], data[n]) <= 1
end

polyline_get_n_nodes = function(self)
    log_typecheck(self, Polyline_t)

    local n = table_sizeof(self.vertices) / 2
    if polyline_is_closed(self) then
        n = n - 1
    end
    return n
end

polyline_get_signed_area = function(self)
    log_typecheck(self, Polyline_t)

    if not self.signed_area_needs_update then
        return self.signed_area
    end

    local vertices = self.vertices
    local n = polyline_get_n_nodes(self)

    local area = 0
    for i = 1, n do
        local next_i = i % n + 1
        local ai = (i - 1) * 2 + 1
        local bi = (next_i - 1) * 2 + 1
        area = area + 0.5 * math_cross(vertices[ai + 0], vertices[ai + 1], vertices[bi + 0], vertices[bi + 1])
    end

    self.signed_area = area
    self.signed_area_needs_update = false
    return area
end

polyline_get_winding = function(self)
    log_typecheck(self, Polyline_t)
    return polyline_get_signed_area(self) > 0 -- true: clockwise
end

polyline_get_aabb = function(self)
    log_typecheck(self, Polyline_t)

    local min_x, min_y, max_x, max_y = math_positive_inf, math_positive_inf, math_negative_inf, math_negative_inf

    local vertices = self.vertices
    local n = table_sizeof(vertices)

    for i = 1, n, 2 do
        local x, y = vertices[i], vertices[i + 1]
        if x < min_x then min_x = x end
        if y < min_y then min_y = y end
        if x > max_x then max_x = x end
        if y > max_y then max_y = y end
    end

    return min_x, min_y, max_x, max_y
end

polyline_get_vertex = function(self, index)
    log_typecheck(self, Polyline_t, index, Number_t)

    local n = polyline_get_n_nodes(self)
    log_assert(index >= 1 and index <= n, "In polyline_get_vertex: index out of range")

    local i = (index - 1) * 2 + 1
    local data = self.vertices
    return data[i + 0], data[i + 1]
end

polyline_get_edge = function(self, index)
    log_typecheck(self, Polyline_t, index, Number_t)

    local n = polyline_get_n_nodes(self)
    log_assert(index >= 1 and index <= n, "In polyline_get_edge: index out of range")

    local next_index = index % n + 1 -- closed contour
    local ai = (index - 1) * 2 + 1
    local bi = (next_index - 1) * 2 + 1
    local data = self.vertices

    return data[ai + 0], data[ai + 1], data[bi + 0], data[bi + 1]
end

polyline_test_circle = function(self, px, py, pr)
    log_typecheck(self, Polyline_t, px, Number_t, py, Number_t, pr, Number_t)

    local vertices = polyline_get_vertices(self)
    local n = polyline_get_n_nodes(self)
    local radius_sq = pr * pr
    local indices = {}
    local distances = {}

    for i = 1, n do
        local j = i % n + 1
        local ai = (i - 1) * 2 + 1
        local bi = (j - 1) * 2 + 1
        local ax, ay = vertices[ai + 0], vertices[ai + 1]
        local bx, by = vertices[bi + 0], vertices[bi + 1]
        local dx, dy = bx - ax, by - ay
        local length_sq = math_dot(dx, dy, dx, dy)

        local t = 0
        if length_sq > 0 then
            t = math_clamp(math_dot(px - ax, py - ay, dx, dy) / length_sq, 0, 1)
        end

        local cx, cy = ax + dx * t, ay + dy * t
        local ox, oy = px - cx, py - cy
        local distance_sq = math_dot(ox, oy, ox, oy)
        if math_dot(ox, oy, ox, oy) <= radius_sq then
            table_push(indices, i)
            distances[i] = distance_sq
        end
    end

    table_sort(indices, function(a, b)
        return distance[a] < distances[b]
    end)

    return indices
end

polyline_test_point = function(self, px, py)
    log_typecheck(self, Polyline_t, px, Number_t, py, Number_t)

    local data = self.vertices
    local n = polyline_get_n_nodes(self)

    local last = (n - 1) * 2 + 1
    local ax, ay = data[last + 0], data[last + 1]
    local winding = 0

    for i = 1, n * 2, 2 do
        local bx, by = data[i + 0], data[i + 1]

        if ay <= py then
            if by > py then -- upward crossing
                if (bx - ax) * (py - ay) - (px - ax) * (by - ay) > 0 then
                    winding = winding + 1
                end
            end
        elseif by <= py then -- downward crossing
            if (bx - ax) * (py - ay) - (px - ax) * (by - ay) < 0 then
                winding = winding - 1
            end
        end

        ax, ay = bx, by
    end

    return winding ~= 0
end

polyline_test_segment = function(self, origin_x, origin_y, direction_x, direction_y)
    log_typecheck(self, Polyline_t,
        origin_x, Number_t, origin_y, Number_t,
        direction_x, Number_t, direction_y, Number_t)

    local vertices = polyline_get_vertices(self)
    local n = polyline_get_n_nodes(self)
    local indices = {}
    local distances = {}

    local eps = math_eps
    local direction_length_sq = math_dot(direction_x, direction_y, direction_x, direction_y)
    local direction_length = math_magnitude(direction_x, direction_y)

    log_assert(direction_length > eps, "In polyline_test_segment: segment has length 0")
    local parameter_eps = eps / direction_length

    for i = 1, n do
        local j = i % n + 1
        local ai = (i - 1) * 2 + 1
        local bi = (j - 1) * 2 + 1
        local ax, ay = vertices[ai], vertices[ai + 1]
        local bx, by = vertices[bi], vertices[bi + 1]
        local edge_x, edge_y = bx - ax, by - ay
        local edge_length_sq = math_dot(edge_x, edge_y, edge_x, edge_y)
        local offset_x, offset_y = ax - origin_x, ay - origin_y
        local t
        local overlaps = false

        if edge_length_sq >= eps * eps then -- disregard degenerate segments
            local edge_length = math_magnitude(edge_x, edge_y)
            local denominator = math_cross(direction_x, direction_y, edge_x, edge_y)

            if math_max(denominator, -denominator) > eps * direction_length * edge_length then
                -- non-parallel
                t = math_cross(offset_x, offset_y, edge_x, edge_y) / denominator
                local u = math_cross(offset_x, offset_y, direction_x, direction_y) / denominator
                local edge_parameter_eps = eps / edge_length
                overlaps = t >= -parameter_eps and t <= 1 + parameter_eps
                    and u >= -edge_parameter_eps and u <= 1 + edge_parameter_eps
            else
                -- parallel
                local collinear_cross = math_cross(offset_x, offset_y, direction_x, direction_y)
                if math_max(collinear_cross, -collinear_cross) <= eps * direction_length then
                    local end_offset_x = bx - origin_x
                    local end_offset_y = by - origin_y
                    local t0 = math_dot(offset_x, offset_y, direction_x, direction_y) / direction_length_sq
                    local t1 = math_dot(end_offset_x, end_offset_y, direction_x, direction_y) / direction_length_sq
                    local overlap_start = math_max(0, math_min(t0, t1))
                    local overlap_end = math_min(1, math_max(t0, t1))

                    if overlap_start <= overlap_end + parameter_eps then
                        t = math_clamp(overlap_start, 0, 1)
                        overlaps = true
                    end
                end
            end
        end

        if overlaps then
            table_push(indices, i)
            distances[i] = math_clamp(t, 0, 1)
        end
    end

    table_sort(indices, function(a, b)
        if distances[a] == distances[b] then
            return a < b
        end
        return distances[a] < distances[b]
    end)

    return indices
end
