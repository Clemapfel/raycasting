rt.settings.overworld.shatter_surface = {
    shapes_per_px = 1 / 1000,
    angle_variance = 0, -- in 0, 1
    radius_variance = 0, -- in 0, 1
    merge_probability = 0.5, -- probability of merging neighboring shapes
    radial_angle_tolerance = math.pi / 12 -- tolerance for radial alignment (15 degrees)
}

--- @class ow.ShatterSurface
ow.ShatterSurface = meta.class("ShatterSurface")

--- @brief
function ow.ShatterSurface:instantiate(x, y, width, height)
    self._bounds = rt.AABB(x, y, width, height)
    self:reset()
end

--- @brief
function ow.ShatterSurface:reset()
    self._is_broken = false
    self._parts = {}
end

--- @brief Helper to check if point is inside polygon
local function point_in_polygon(x, y, vertices)
    local inside = false
    local p1x, p1y = vertices[#vertices - 1], vertices[#vertices]
    for i = 1, #vertices, 2 do
        local p2x, p2y = vertices[i], vertices[i + 1]
        if ((p2y > y) ~= (p1y > y)) and (x < (p1x - p2x) * (y - p2y) / (p1y - p2y) + p2x) then
            inside = not inside
        end
        p1x, p1y = p2x, p2y
    end
    return inside
end

--- @brief Helper to clip polygon to rectangle bounds
local function clip_polygon_to_rect(vertices, x, y, w, h)
    local function clip_edge(verts, edge_x, edge_y, edge_w, edge_h, axis, positive)
        local output = {}
        if #verts < 6 then return verts end

        local prev_x, prev_y = verts[#verts - 1], verts[#verts]
        local prev_inside

        if axis == "x" then
            prev_inside = positive and (prev_x <= edge_x + edge_w) or (prev_x >= edge_x)
        else
            prev_inside = positive and (prev_y <= edge_y + edge_h) or (prev_y >= edge_y)
        end

        for i = 1, #verts, 2 do
            local curr_x, curr_y = verts[i], verts[i + 1]
            local curr_inside

            if axis == "x" then
                curr_inside = positive and (curr_x <= edge_x + edge_w) or (curr_x >= edge_x)
            else
                curr_inside = positive and (curr_y <= edge_y + edge_h) or (curr_y >= edge_y)
            end

            if curr_inside ~= prev_inside then
                -- Calculate intersection
                local t
                if axis == "x" then
                    local edge = positive and (edge_x + edge_w) or edge_x
                    t = (edge - prev_x) / (curr_x - prev_x)
                else
                    local edge = positive and (edge_y + edge_h) or edge_y
                    t = (edge - prev_y) / (curr_y - prev_y)
                end

                local int_x = prev_x + t * (curr_x - prev_x)
                local int_y = prev_y + t * (curr_y - prev_y)
                table.insert(output, int_x)
                table.insert(output, int_y)
            end

            if curr_inside then
                table.insert(output, curr_x)
                table.insert(output, curr_y)
            end

            prev_x, prev_y = curr_x, curr_y
            prev_inside = curr_inside
        end

        return output
    end

    -- Clip against all four edges
    vertices = clip_edge(vertices, x, y, w, h, "x", false)  -- left
    vertices = clip_edge(vertices, x, y, w, h, "x", true)   -- right
    vertices = clip_edge(vertices, x, y, w, h, "y", false)  -- top
    vertices = clip_edge(vertices, x, y, w, h, "y", true)   -- bottom

    return vertices
end

--- @brief Generate seeds using Fibonacci spiral pattern
local function generate_fibonacci_spiral_seeds(origin_x, origin_y, num_seeds, max_radius, variance)
    local seeds = {}
    local golden_angle = math.pi * (3 - math.sqrt(5))

    -- Add impact point as the center seed
    table.insert(seeds, {x = origin_x, y = origin_y})

    local easing = rt.InterpolationFunctions.LINEAR
    local max_angle_variance = rt.settings.overworld.shatter_surface.angle_variance * 2 * math.pi
    local max_radius_variance = rt.settings.overworld.shatter_surface.radius_variance

    local max_offset = debugger.get("max_offset")

    -- Calculate radial line density to match spiral
    local n_lines = 32
    local spiral_density_at_edge = math.sqrt(num_seeds) / max_radius
    local average_spiral_spacing = max_radius / math.sqrt(num_seeds)
    local n_steps = math.floor(max_radius / average_spiral_spacing)

    local step = max_radius / n_steps

    for i = 1, n_lines do
        local angle = (i - 1) / n_lines * 2 * math.pi
        angle = angle + rt.random.number(-1, 1) * debugger.get("angle_offset") * 2 * math.pi
        local dx, dy = math.cos(angle), math.sin(angle)
        for j = 1, n_steps do
            local length = easing(j / n_steps) * max_radius

            local offset_x = rt.random.number(-1, 1) * debugger.get("step_x_offset") * step
            local offset_y = rt.random.number(-1, 1) * debugger.get("step_y_offset") * step

            local x = origin_x + dx * (length + offset_x)
            local y = origin_y + dy * (length + offset_y)
            x = x + rt.random.noise(x, y) * rt.random.number(-1, 1) * max_offset * length
            y = y + rt.random.noise(-y, x) * rt.random.number(-1, 1) * max_offset * length

            table.insert(seeds, {
                x = x, y = y
            })
        end
    end

    return seeds
end

--- @brief Check if two line segments share a common edge (within tolerance)
local function segments_overlap(x1, y1, x2, y2, x3, y3, x4, y4, tolerance)
    tolerance = tolerance or 1e-6

    -- Check if segments are collinear and overlapping
    local function point_on_segment(px, py, sx, sy, ex, ey)
        local cross = (py - sy) * (ex - sx) - (px - sx) * (ey - sy)
        if math.abs(cross) > tolerance then return false end

        local dot = (px - sx) * (ex - sx) + (py - sy) * (ey - sy)
        local len_sq = (ex - sx) * (ex - sx) + (ey - sy) * (ey - sy)

        return dot >= -tolerance and dot <= len_sq + tolerance
    end

    -- Check if any endpoint of one segment lies on the other
    return point_on_segment(x1, y1, x3, y3, x4, y4) or
        point_on_segment(x2, y2, x3, y3, x4, y4) or
        point_on_segment(x3, y3, x1, y1, x2, y2) or
        point_on_segment(x4, y4, x1, y1, x2, y2)
end

--- @brief Check if an edge is aligned radially from the origin
local function is_edge_radial(x1, y1, x2, y2, origin_x, origin_y, tolerance)
    -- Calculate the angle of the edge
    local edge_angle = math.atan2(y2 - y1, x2 - x1)

    -- Calculate the angle from origin to the midpoint of the edge
    local mid_x = (x1 + x2) / 2
    local mid_y = (y1 + y2) / 2
    local radial_angle = math.atan2(mid_y - origin_y, mid_x - origin_x)

    -- Calculate the angle difference
    local angle_diff = math.abs(edge_angle - radial_angle)

    -- Normalize angle difference to [0, pi]
    if angle_diff > math.pi then
        angle_diff = 2 * math.pi - angle_diff
    end

    -- Check if edge is perpendicular to radial direction (tangential)
    -- or aligned with radial direction
    local perpendicular_diff = math.abs(angle_diff - math.pi / 2)
    local aligned_diff = math.min(angle_diff, math.abs(angle_diff - math.pi))

    -- We want edges that are aligned with the radial direction (not perpendicular)
    return aligned_diff <= tolerance
end

--- @brief Find neighboring shapes that share radially-aligned edges
local function find_neighbors(parts, origin_x, origin_y)
    local neighbors = {}
    local settings = rt.settings.overworld.shatter_surface

    for i = 1, #parts do
        neighbors[i] = {}
        local part_a = parts[i]

        for j = i + 1, #parts do
            local part_b = parts[j]
            local shared_radial_edge_found = false

            -- Check each edge of part_a against each edge of part_b
            for k = 1, #part_a.vertices, 2 do
                local next_k = k + 2
                if next_k > #part_a.vertices then next_k = 1 end

                local ax1, ay1 = part_a.vertices[k], part_a.vertices[k + 1]
                local ax2, ay2 = part_a.vertices[next_k], part_a.vertices[next_k + 1]

                for l = 1, #part_b.vertices, 2 do
                    local next_l = l + 2
                    if next_l > #part_b.vertices then next_l = 1 end

                    local bx1, by1 = part_b.vertices[l], part_b.vertices[l + 1]
                    local bx2, by2 = part_b.vertices[next_l], part_b.vertices[next_l + 1]

                    -- Check if segments overlap
                    if segments_overlap(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2) then
                        -- Check if the shared edge is radially aligned
                        if is_edge_radial(ax1, ay1, ax2, ay2, origin_x, origin_y, settings.radial_angle_tolerance) then
                            shared_radial_edge_found = true
                            break
                        end
                    end
                end

                if shared_radial_edge_found then break end
            end

            if shared_radial_edge_found then
                table.insert(neighbors[i], j)
                if neighbors[j] == nil then neighbors[j] = {} end
                table.insert(neighbors[j], i)
            end
        end
    end

    return neighbors
end

--- @brief Merge two polygons by removing their shared edge
local function merge_polygons(poly1, poly2)
    -- This is a simplified merge - in practice, you'd want a more robust
    -- polygon union algorithm. For now, we'll create a convex hull of all points.
    local all_points = {}

    -- Collect all vertices
    for i = 1, #poly1, 2 do
        table.insert(all_points, {x = poly1[i], y = poly1[i + 1]})
    end
    for i = 1, #poly2, 2 do
        table.insert(all_points, {x = poly2[i], y = poly2[i + 1]})
    end

    -- Simple convex hull using gift wrapping algorithm
    local function cross_product(o, a, b)
        return (a.x - o.x) * (b.y - o.y) - (a.y - o.y) * (b.x - o.x)
    end

    -- Find leftmost point
    local leftmost = 1
    for i = 2, #all_points do
        if all_points[i].x < all_points[leftmost].x then
            leftmost = i
        end
    end

    local hull = {}
    local current = leftmost

    repeat
        table.insert(hull, all_points[current])
        local next_point = 1

        for i = 1, #all_points do
            if i == current then goto continue end

            if next_point == current or
                cross_product(all_points[current], all_points[i], all_points[next_point]) > 0 then
                next_point = i
            end

            ::continue::
        end

        current = next_point
    until current == leftmost

    -- Convert back to flat array
    local result = {}
    for _, point in ipairs(hull) do
        table.insert(result, point.x)
        table.insert(result, point.y)
    end

    return result
end

--- @brief Merge random neighboring shapes with radially-aligned edges
local function merge_random_neighbors(parts, origin_x, origin_y, merge_probability)
    local neighbors = find_neighbors(parts, origin_x, origin_y)
    local merged_indices = {}
    local new_parts = {}

    -- Randomly select pairs to merge
    for i = 1, #parts do
        if merged_indices[i] then goto continue end

        if neighbors[i] and #neighbors[i] > 0 and rt.random.number(0, 1) < merge_probability then
            -- Pick a random neighbor
            local neighbor_idx = neighbors[i][rt.random.integer(1, #neighbors[i])]

            if not merged_indices[neighbor_idx] then
                -- Merge the two shapes
                local merged_vertices = merge_polygons(parts[i].vertices, parts[neighbor_idx].vertices)

                table.insert(new_parts, {
                    vertices = merged_vertices,
                    color = parts[i].color -- Keep the first shape's color
                })

                merged_indices[i] = true
                merged_indices[neighbor_idx] = true
            else
                -- Neighbor already merged, keep original
                table.insert(new_parts, parts[i])
            end
        else
            -- No merge, keep original
            table.insert(new_parts, parts[i])
        end

        ::continue::
    end

    return new_parts
end

--- @brief
function ow.ShatterSurface:shatter(origin_x, origin_y)
    self._is_broken = true
    self._parts = {}
    self._origin_x = origin_x
    self._origin_y = origin_y

    local settings = rt.settings.overworld.shatter_surface
    local min_x, min_y = self._bounds.x, self._bounds.y
    local max_x, max_y = self._bounds.x + self._bounds.width, self._bounds.y + self._bounds.height

    -- Calculate number of shards and maximum radius
    local num_shards = math.floor((self._bounds.width * self._bounds.height) * settings.shapes_per_px)
    local max_radius = math.max(self._bounds.width, self._bounds.height) / 2

    -- Generate seeds using Fibonacci spiral
    local seeds = generate_fibonacci_spiral_seeds(origin_x, origin_y, num_shards, max_radius, settings.shatter_variance)
    self._seeds = seeds

    -- Create Voronoi cells (simplified approach using perpendicular bisectors)
    for i, seed in ipairs(seeds) do
        local vertices = {}

        -- Start with a large polygon (the entire bounds)
        local poly = {
            min_x - 100, min_y - 100,
            max_x + 100, min_y - 100,
            max_x + 100, max_y + 100,
            min_x - 100, max_y + 100
        }

        -- Clip against perpendicular bisectors with other seeds
        for j, other in ipairs(seeds) do
            if i ~= j then
                -- Calculate perpendicular bisector
                local mid_x = (seed.x + other.x) / 2
                local mid_y = (seed.y + other.y) / 2

                local dx = other.x - seed.x
                local dy = other.y - seed.y

                -- Perpendicular direction
                local perp_x = -dy
                local perp_y = dx

                -- Normalize
                local len = math.sqrt(perp_x * perp_x + perp_y * perp_y)
                if len > 0 then
                    perp_x = perp_x / len
                    perp_y = perp_y / len
                end

                -- Clip polygon against this half-plane
                local new_poly = {}
                for k = 1, #poly, 2 do
                    local px, py = poly[k], poly[k + 1]
                    local next_k = k + 2
                    if next_k > #poly then next_k = 1 end
                    local nx, ny = poly[next_k], poly[next_k + 1]

                    -- Check which side of the line points are on
                    local d1 = (px - mid_x) * dx + (py - mid_y) * dy
                    local d2 = (nx - mid_x) * dx + (ny - mid_y) * dy

                    if d1 <= 0 then
                        table.insert(new_poly, px)
                        table.insert(new_poly, py)
                    end

                    -- If edge crosses the line, add intersection
                    if (d1 < 0 and d2 > 0) or (d1 > 0 and d2 < 0) then
                        local t = d1 / (d1 - d2)
                        local int_x = px + t * (nx - px)
                        local int_y = py + t * (ny - py)
                        table.insert(new_poly, int_x)
                        table.insert(new_poly, int_y)
                    end
                end
                poly = new_poly

                if #poly < 6 then break end
            end
        end

        -- Clip to bounds and add to parts
        if #poly >= 6 then
            poly = clip_polygon_to_rect(poly, min_x, min_y, self._bounds.width, self._bounds.height)
            if #poly >= 6 then
                table.insert(self._parts, {
                    vertices = poly,
                    color = {}
                })
            end
        end
    end

    -- Merge random neighboring shapes with radially-aligned edges
    self._parts = merge_random_neighbors(self._parts, origin_x, origin_y, settings.merge_probability)

    -- Assign colors after merging
    for i, entry in ipairs(self._parts) do
        entry.color = { rt.lcha_to_rgba(0.8, 0, 2 * i / #self._parts, 1) }
    end
end

--- @brief
function ow.ShatterSurface:draw()
    if self._is_broken == false then
        love.graphics.rectangle("fill", self._bounds:unpack())
    else
        love.graphics.setLineWidth(1)
        for part in values(self._parts) do
            love.graphics.setColor(part.color)
            love.graphics.polygon("fill", part.vertices)

            love.graphics.setColor(0, 0, 0, 1)
            love.graphics.polygon("line", part.vertices)
        end

        if self._seeds ~= nil then
            for seed in values(self._seeds) do
                --love.graphics.circle("fill", seed.x, seed.y, 2)
            end
        end
    end
end