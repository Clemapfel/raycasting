require "common.delaunay_triangulation"

rt.settings.voronoi_tesselation = {
    seed_density = 1 / 350, -- #seeds per px^2
    randomization = 1 -- unitless
}

--- @class rt.VoronoiTesselation
rt.VoronoiTesselation = meta.class("VoronoiTesselation")

--- @brief
function rt.VoronoiTesselation:instantiate()
    self._seed_density = rt.settings.voronoi_tesselation.seed_density
end

-- check if point is in rotated rectangle
local _point_in_area = function(px, py, x0, y0, x1, y1, x2, y2, x3, y3)
    return (x1 - x0) * (py - y0) - (y1 - y0) * (px - x0) >= 0
        and (x2 - x1) * (py - y1) - (y2 - y1) * (px - x1) >= 0
        and (x3 - x2) * (py - y2) - (y3 - y2) * (px - x2) >= 0
        and (x0 - x3) * (py - y3) - (y0 - y3) * (px - x3) >= 0
end

local _squared_distance = function(x1, y1, x2, y2)
    local dx, dy = x2 - x1, y2 - y1
    return dx * dx + dy * dy
end

local _rand = function(a, b)
    local t = love.math.random()
    return t * a + (1 - t) * b
end

local _rotate = function(px, py, x, y, cos_angle, sin_angle)
    local dx, dy = px - x, py - y
    return x + dx * cos_angle - dy * sin_angle, y + dx * sin_angle + dy * cos_angle
end

--- @brief
function rt.VoronoiTesselation:rotate_rectangle(rect_x, rect_y, rect_w, rect_h, rect_origin_x, rect_origin_y, rect_angle)
    local rotate_cos, rotate_sin = math.cos(rect_angle), math.sin(rect_angle)
    local tl_x, tl_y = _rotate(rect_x, rect_y, rect_origin_x, rect_origin_y, rotate_cos, rotate_sin)
    local tr_x, tr_y = _rotate(rect_x + rect_w, rect_y, rect_origin_x, rect_origin_y, rotate_cos, rotate_sin)
    local br_x, br_y = _rotate(rect_x + rect_w, rect_y + rect_h, rect_origin_x, rect_origin_y, rotate_cos, rotate_sin)
    local bl_x, bl_y = _rotate(rect_x, rect_y + rect_h, rect_origin_x, rect_origin_y, rotate_cos, rotate_sin)

    return tl_x, tl_y, tr_x, tr_y, br_x, br_y, bl_x, bl_y
end

--- @brief
function rt.VoronoiTesselation:set_seed_density(density)
    self._seed_density = density
end

--- @brief
function rt.VoronoiTesselation:generate_seeds(
    origin_x, origin_y, tl_x, tl_y, tr_x, tr_y, br_x, br_y, bl_x, bl_y
)
    meta.assert(
        origin_x, "Number", origin_y, "Number",
        tl_x, "Number", tl_y, "Number",
        tr_x, "Number", tr_y, "Number",
        br_x, "Number", br_y, "Number",
        bl_x, "Number", bl_y, "Number"
    )

    local radius = math.sqrt(math.max(
        _squared_distance(origin_x, origin_y, tl_x, tl_y),
        _squared_distance(origin_x, origin_y, tr_x, tr_y),
        _squared_distance(origin_x, origin_y, br_x, br_y),
        _squared_distance(origin_x, origin_y, bl_x, bl_y)
    ))

    local t_easing = function(t)
        return rt.InterpolationFunctions.EXPONENTIAL_ACCELERATION(t)
    end

    local golden_angle = math.pi * (3 - math.sqrt(5))
    local circle_area = (math.pi * radius * radius)
    local n_particles = math.ceil(circle_area * self._seed_density)

    local seeds = {}
    local randomness = 4 * rt.SceneManager:get_elapsed() --rt.settings.voronoi_tesselation.randomization

    love.math.setRandomSeed(0)

    for t_raw = 0, t_easing(1), 1 / n_particles do
        local t = t_easing(t_raw)
        local distance = radius * math.sqrt(t)
        local angle = t_raw * n_particles * golden_angle

        local seed_x = origin_x + distance * math.cos(angle)
        local seed_y = origin_y + distance * math.sin(angle)

        local offset = randomness * (distance / math.sqrt(n_particles))
        seed_x = seed_x + _rand(-offset, offset)
        seed_y = seed_y + _rand(-offset, offset)

        if _point_in_area(seed_x, seed_y, tl_x, tl_y, tr_x, tr_y, br_x, br_y, bl_x, bl_y) then
            table.insert(seeds, seed_x)
            table.insert(seeds, seed_y)
        end
    end

    self._actual_n_seeds = #seeds / 2

    local max_dist = radius * 10
    for x in range(
        origin_x - max_dist, origin_y - max_dist,
        origin_x + max_dist, origin_y - max_dist,
        origin_x + max_dist, origin_y + max_dist,
        origin_x - max_dist, origin_y + max_dist,
        origin_x - max_dist, origin_y,
        origin_x + max_dist, origin_y,
        origin_x, origin_y - max_dist,
        origin_x, origin_y + max_dist
    ) do
        table.insert(seeds, x)
    end

    self._rect = { tl_x, tl_y, tr_x, tr_y, br_x, br_y, bl_x, bl_y }
    self._origin_x, self._origin_y = origin_x, origin_y
    self._seeds = seeds
    self._n_seeds = #seeds / 2
end

-- sutherland-hodgkins clip against infinite line
local _clip_polygon = function(polygon, ax, ay, bx, by, side)
    if side == nil then side = 1 end

    local delta_x, delta_y = bx - ax, by - ay
    local normal_x, normal_y = -delta_y * side, delta_x * side
    local vertex_count = #polygon

    local all_inside = true
    local all_outside = true
    for i = 1, vertex_count, 2 do
        if math.dot(normal_x, normal_y, polygon[i] - ax, polygon[i + 1] - ay) >= 0 then
            all_outside = false
        else
            all_inside = false
        end

        if not all_inside and not all_outside then break end
    end

    if all_inside then return polygon end
    if all_outside then return {} end

    local output = table.new and table.new(vertex_count, 0) or {}
    local output_count = 0

    local start_x, start_y = polygon[vertex_count - 1], polygon[vertex_count]
    local start_distance = math.dot(normal_x, normal_y, start_x - ax, start_y - ay)

    for i = 1, vertex_count, 2 do
        local end_x, end_y = polygon[i], polygon[i + 1]
        local end_distance = math.dot(normal_x, normal_y, end_x - ax, end_y - ay)

        if (start_distance >= 0) ~= (end_distance >= 0) then
            local t = start_distance / (start_distance - end_distance)
            output_count = output_count + 2
            output[output_count - 1] = math.mix(start_x, end_x, t)
            output[output_count] = math.mix(start_y, end_y, t)
        end

        if end_distance >= 0 then
            output_count = output_count + 2
            output[output_count - 1] = end_x
            output[output_count] = end_y
        end

        start_x, start_y, start_distance = end_x, end_y, end_distance
    end

    return output
end

--- @brief
function rt.VoronoiTesselation:tesselate()
    self._triangulation = rt.DelaunayTriangulation(self._seeds)
    self._tri_indices = self._triangulation:get_triangle_vertex_map()

    coroutine.yield()

    self._tris = {}
    self._polygons = {}
    self._polygon_to_needs_clipping = {} -- Restored tracking table

    local point_eps = 1
    local determinant_eps = 1e-6
    local clip_eps = determinant_eps

    local seeds = self._seeds
    local top_left_x, top_left_y, top_right_x, top_right_y, bottom_right_x, bottom_right_y, bottom_left_x, bottom_left_y = table.unpack(self._rect)

    -- Transform basis to check if cell vertices are inside the bounding box
    local basis_u_x, basis_u_y = math.subtract2(top_right_x, top_right_y, top_left_x, top_left_y)
    local basis_v_x, basis_v_y = math.subtract2(bottom_left_x, bottom_left_y, top_left_x, top_left_y)
    local basis_u_length_squared = math.dot2(basis_u_x, basis_u_y, basis_u_x, basis_u_y)
    local basis_v_length_squared = math.dot2(basis_v_x, basis_v_y, basis_v_x, basis_v_y)

    local point_cells = {}
    for index = 1, self._actual_n_seeds do
        point_cells[index] = {}
    end

    for triangle_index = 1, #self._tri_indices, 3 do
        local i1 = self._tri_indices[triangle_index]
        local i2 = self._tri_indices[triangle_index + 1]
        local i3 = self._tri_indices[triangle_index + 2]

        if i1 ~= i2 and i1 ~= i3 and i2 ~= i3 then
            local i1x, i1y = seeds[i1 * 2 - 1], seeds[i1 * 2]
            local i2x, i2y = seeds[i2 * 2 - 1], seeds[i2 * 2]
            local i3x, i3y = seeds[i3 * 2 - 1], seeds[i3 * 2]

            local d1x, d1y = math.subtract2(i2x, i2y, i1x, i1y)
            local d2x, d2y = math.subtract2(i3x, i3y, i1x, i1y)

            local determinant = 2 * math.cross2(d1x, d1y, d2x, d2y)

            if math.abs(determinant) > determinant_eps then
                local magnitude1 = math.dot2(d1x, d1y, d1x, d1y)
                local magnitude2 = math.dot2(d2x, d2y, d2x, d2y)

                local circumcenter_x = i1x + (d2y * magnitude1 - d1y * magnitude2) / determinant
                local circumcenter_y = i1y + (d1x * magnitude2 - d2x * magnitude1) / determinant

                local cell1, cell2, cell3 = point_cells[i1], point_cells[i2], point_cells[i3]

                if cell1 then table.insert(cell1, circumcenter_x) table.insert(cell1, circumcenter_y) end
                if cell2 then table.insert(cell2, circumcenter_x) table.insert(cell2, circumcenter_y) end
                if cell3 then table.insert(cell3, circumcenter_x) table.insert(cell3, circumcenter_y) end
            end
        end
    end

    local vertex_indices = {}
    local angles = {}

    local comparator = function(a, b)
        return angles[a] < angles[b]
    end

    local clear = table.clear and table.clear or function(t)
        for i = 1, #t do t[i] = nil end
    end

    for point_i = 1, self._actual_n_seeds do
        local cell = point_cells[point_i]
        local n_vertices = #cell / 2

        if n_vertices >= 3 then
            local seed_x, seed_y = seeds[point_i * 2 - 1], seeds[point_i * 2]

            clear(vertex_indices)
            clear(angles)

            for vertex_i = 1, n_vertices do
                vertex_indices[vertex_i] = vertex_i
                angles[vertex_i] = math.fast_angle(
                    cell[vertex_i * 2] - seed_y,
                    cell[vertex_i * 2 - 1] - seed_x
                )
            end

            table.sort(vertex_indices, comparator)

            local polygon = {}
            local output_index = 1
            local last_x, last_y
            local needs_clipping = false

            for vertex_i = 1, n_vertices do
                local index = vertex_indices[vertex_i]
                local vertex_x, vertex_y = cell[index * 2 - 1], cell[index * 2]

                if vertex_i == 1
                    or math.abs(vertex_x - last_x) > point_eps
                    or math.abs(vertex_y - last_y) > point_eps
                then
                    polygon[output_index] = vertex_x
                    polygon[output_index + 1] = vertex_y
                    output_index = output_index + 2
                    last_x, last_y = vertex_x, vertex_y

                    if not needs_clipping then
                        local relative_x, relative_y = math.subtract2(vertex_x, vertex_y, top_left_x, top_left_y)
                        local u = math.dot2(relative_x, relative_y, basis_u_x, basis_u_y) / basis_u_length_squared
                        local v = math.dot2(relative_x, relative_y, basis_v_x, basis_v_y) / basis_v_length_squared

                        if u < 0 - clip_eps or u > 1 + clip_eps or v < 0 - clip_eps or v > 1 + clip_eps then
                            needs_clipping = true
                        end
                    end
                end
            end

            if output_index > 6
                and math.abs(polygon[1] - last_x) <= point_eps
                and math.abs(polygon[2] - last_y) <= point_eps
            then
                polygon[output_index - 2] = nil
                polygon[output_index - 1] = nil
            end

            if #polygon >= 6 then
                table.insert(self._polygons, polygon)

                if needs_clipping then
                    self._polygon_to_needs_clipping[polygon] = true
                end
            end
        end
    end

    coroutine.yield()

    local to_remove = {}

    for i = 1, #self._polygons do
        local polygon = self._polygons[i]
        if self._polygon_to_needs_clipping[polygon] == true then
            polygon = _clip_polygon(polygon, top_left_x, top_left_y, top_right_x, top_right_y)
            polygon = _clip_polygon(polygon, top_right_x, top_right_y, bottom_right_x, bottom_right_y)
            polygon = _clip_polygon(polygon, bottom_right_x, bottom_right_y, bottom_left_x, bottom_left_y)
            polygon = _clip_polygon(polygon, bottom_left_x, bottom_left_y, top_left_x, top_left_y)

            if #polygon >= 6 then
                self._polygons[i] = polygon
            else
                table.insert(to_remove, 1, i)
            end
        end
    end

    for i in values(to_remove) do
        table.remove(self._polygons, i)
    end

    return self._polygons
end

--- @brief
function rt.VoronoiTesselation:get_polyons()
    return self._polygons
end

--- @brief
function rt.VoronoiTesselation:draw()
    for i = #self._polygons, 1, -1 do
        local hue = (i - 1) / #self._polygons
        love.graphics.setColor(hue, hue, hue, 1)
        love.graphics.setColor(rt.lcha_to_rgba(0.8, 1, hue, 1))
        love.graphics.polygon("fill", self._polygons[i])
    end

    love.graphics.setLineWidth(1)
    love.graphics.setColor(0, 0, 0, 1)
    for i = #self._polygons, 1, -1 do
        local hue = (i - 1) / #self._polygons
        love.graphics.polygon("line", self._polygons[i])
    end

    --[[
    love.graphics.setLineWidth(0.25)
    love.graphics.setColor(0, 0, 0, 0.0)
    if self._triangulation ~= nil then
        for tri in values(self._tris) do
            love.graphics.line(tri)
        end
    end
    ]]
end
