AABB_t = "AABB"

aabb_new = function(...)
    return aabb_init(object_new(AABB_t, {}), ...)
end

aabb_init = function(self, aabb_or_x, y, width, height)
    if object_is_table(aabb_or_x) then
        log_typecheck_arg_i(self, AABB_t, aabb_or_x, AABB_t, y, Nil_t, width, Nil_t, height, Nil_t)
        local other = aabb_or_x
        self.x = other.x
        self.y = other.y
        self.width = other.width
        self.height = other.height
    else
        log_typecheck_arg_i(self, AABB_t, aabb_or_x, Number_t, y, Number_t, width, Number_t, height, Number_t)
        self.x = aabb_or_x
        self.y = y
        self.width = width
        self.height = height
    end

    return self
end

aabb_unpack = function(self)
    log_typecheck(self, AABB_t)
    return self.x, self.y, self.width, self.height
end

aabb_draw = function(self, corner_radius)
    log_typecheck(self, AABB_t)
    local x, y, w, h = aabb_unpack(self)
    graphics_draw_rectangle(x, y, w, h, corner_radius)
end

aabb_overlaps_point = function(self, px, py)
    log_typecheck(self, AABB_t, px, Number_t, py, Number_t)
    local x, y, w, h = aabb_unpack(self)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

aabb_overlaps_polyline = function(self, contour)
    log_typecheck(self, AABB_t, contour, Polyline_t)

    local x1, y1, w, h = aabb_unpack(self)
    local x2, y2 = x1 + w, y1 + h
    local vertices = polyline_get_vertices(contour)
    local n = #vertices

    local min_x, min_y = math_inf, math_inf
    local max_x, max_y = math_negative_inf, math_negative_inf

    -- early check: any vertex in bounds
    for i = 1, n, 2 do
        local px, py = vertices[i], vertices[i + 1]
        min_x = math_min(min_x, px)
        min_y = math_min(min_y, py)
        max_x = math_max(max_x, px)
        max_y = math_max(max_y, py)

        if px >= x1 and px <= x2 and py >= y1 and py <= y2 then
            return true
        end
    end

    if max_x < x1 or min_x > x2 or max_y < y1 or min_y > y2 then
        return false
    end

    -- lian-barsky
    for i = 1, n, 2 do
        local j = i + 2
        if j > n then j = 1 end

        local ax, ay = vertices[i], vertices[i + 1]
        local bx, by = vertices[j], vertices[j + 1]

        local dx, dy = bx - ax, by - ay
        local t_min, t_max = 0, 1
        local overlaps = true

        if dx == 0 then
            overlaps = ax >= x1 and ax <= x2
        else
            local t1, t2 = (x1 - ax) / dx, (x2 - ax) / dx
            if t1 > t2 then t1, t2 = t2, t1 end
            t_min = math_max(t_min, t1)
            t_max = math_min(t_max, t2)
            overlaps = t_min <= t_max
        end

        if overlaps then
            if dy == 0 then
                overlaps = ay >= y1 and ay <= y2
            else
                local t1 = (y1 - ay) / dy
                local t2 = (y2 - ay) / dy
                if t1 > t2 then t1, t2 = t2, t1 end
                t_min = math_max(t_min, t1)
                t_max = math_min(t_max, t2)
                overlaps = t_min <= t_max
            end
        end

        if overlaps then
            return true
        end
    end

    -- box fully inside polygon
    local inside = false
    local j = n - 1
    for i = 1, n, 2 do
        local ax, ay = vertices[i], vertices[i + 1]
        local bx, by = vertices[j], vertices[j + 1]

        local crosses = (ay > y1) ~= (by > y1)
        local x_intersect = ((bx - ax) * (y1 - ay)) / (by - ay) + ax
        if crosses and (x1 < x_intersect) then
            inside = not inside
        end

        j = i
    end

    return inside
end