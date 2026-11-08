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