Polyline_t = "Polyline"

polyline_new = function(...)
    local self = object_new(Polyline_t, {
        vertices = {},
        n_vertices = 0
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
    return self
end

polyline_get_vertices = function(self)
    log_typecheck(self, Polyline_t)
    return self.vertices
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

    local vertices = self.vertices
    local n = polyline_get_n_nodes(self)

    local area = 0
    for i = 1, n do
        local next_i = i % n + 1
        local ai = (i - 1) * 2 + 1
        local bi = (next_i - 1) * 2 + 1
        area = area + 0.5 * math_cross(vertices[ai + 0], vertices[ai + 1], vertices[bi + 0], vertices[bi + 1])
    end
    return area
end
