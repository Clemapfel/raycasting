local _round = function(x)
    return math.floor(x)
end

local _hash_to_points = nil

local _hash = function(points)
    local x1, y1, x2, y2 = _round(points[1]), _round(points[2]), _round(points[3]), _round(points[4])
    if x1 < x2 or (x1 == x2 and y1 < y2) then -- swap so point order does not matter
        x1, y1, x2, y2 = x2, y2, x1, y1
    end
    local hash = tostring(x1) .. "," .. tostring(y1) .. "," .. tostring(x2) .. "," .. tostring(y2)
    _hash_to_points[hash] = points
    return hash
end

local _unhash = function(hash)
    return _hash_to_points[hash]
end

--- @brief construct contour from list of triangles
rt.contour_from_tris = function(tris, close_loop)
    if close_loop == nil then close_loop = true end
    local segments = {}
    for tri in values(tris) do
        for segment in range(
            {tri[1], tri[2], tri[3], tri[4]},
            {tri[3], tri[4], tri[5], tri[6]},
            {tri[1], tri[2], tri[5], tri[6]}
        ) do
            table.insert(segments, segment)
        end
    end

    -- filter so only outer segments remain
    _hash_to_points = {}
    local tuples = {}
    local n_total = 0
    for segment in values(segments) do
        local hash = _hash(segment)
        local current = tuples[hash]
        if current == nil then
            tuples[hash] = 1
        else
            tuples[hash] = current + 1
        end
        n_total = n_total + 1
    end

    local outline = {}
    for hash, count in pairs(tuples) do
        if count == 1 then
            table.insert(outline, _unhash(hash))
        end
    end

    -- link segments so they are ordered
    local function points_equal(x1, y1, x2, y2)
        return math.abs(x1 - x2) < 1e-6 and math.abs(y1 - y2) < 1e-6
    end

    local ordered = {outline[1]}
    table.remove(outline, 1)

    while #outline > 0 do
        local last = ordered[#ordered]
        local x2, y2 = last[3], last[4]
        local found = false

        for i, segment in ipairs(outline) do
            local sx1, sy1, sx2, sy2 = segment[1], segment[2], segment[3], segment[4]
            if points_equal(x2, y2, sx1, sy1) then
                table.insert(ordered, segment)
                table.remove(outline, i)
                found = true
                break
            elseif points_equal(x2, y2, sx2, sy2) then
                -- Reverse the segment
                table.insert(ordered, {sx2, sy2, sx1, sy1})
                table.remove(outline, i)
                found = true
                break
            end
        end

        if not found then
            rt.warning("In rt.contour_from_tris: contour has duplicate edges")
            break
        end -- degenerate contour with duplicate segments
    end

    local contour = {}
    for segment in values(ordered) do
        table.insert(contour, segment[1])
        table.insert(contour, segment[2])
    end
    --table.insert(contour, contour[1])
    --table.insert(contour, contour[2])

    return contour
end

-- ###

function rt.subdivide_contour(contour, segment_length)
    local subdivided = {}
    for i = 1, #contour, 2 do
        local x1, y1 = contour[i], contour[i+1]
        local next_i = (i + 2 > #contour) and 1 or i + 2
        local x2, y2 = contour[next_i], contour[next_i+1]
        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local n_segments = math.ceil(length / segment_length)
        for s = 0, n_segments - 1 do
            local t = s / n_segments
            local sx = x1 + t * dx
            local sy = y1 + t * dy
            table.insert(subdivided, sx)
            table.insert(subdivided, sy)
        end
    end
    return subdivided
end

--- ###

function rt.smooth_contour(contour, n_iterations)
    local points = contour
    for smoothing_i = 1, n_iterations do
        local smoothed = {}
        for j = 1, #points, 2 do
            local prev_j = (j - 2 < 1) and (#points - 1) or (j - 2)
            local next_j = (j + 2 > #points) and 1 or (j + 2)
            local x = (points[prev_j] + points[j] + points[next_j]) / 3
            local y = (points[prev_j+1] + points[j+1] + points[next_j+1]) / 3
            table.insert(smoothed, x)
            table.insert(smoothed, y)
        end
        points = smoothed
    end

    -- connect loops that retracted after smoothing
    --points[1] = points[#points - 1]
    --points[2] = points[#points - 0]
    return points
end

--- ###

function rt.round_contour(points, radius, samples_per_corner)
    local n = math.floor(#points / 2)
    radius = radius or 10
    samples_per_corner = samples_per_corner or 5

    local new_points = {}

    for i = 1, n do
        local previous_idx = ((i - 2 + n) % n) + 1
        local current_idx = i
        local next_idx = (i % n) + 1

        local previous_x, previous_y = points[ 2 * previous_idx - 1], points[2 *previous_idx]
        local current_x, current_y = points[2 * current_idx - 1], points[2 * current_idx]
        local next_x, next_y = points[2 * next_idx-1], points[2 * next_idx]

        local v1x = current_x - previous_x
        local v1y = current_y - previous_y
        local v2x = next_x - current_x
        local v2y = next_y - current_y

        -- shorten current segment by corner radius
        local v1nx, v1ny = math.normalize(v1x, v1y)
        local v2nx, v2ny = math.normalize(v2x, v2y)
        local len1 = math.min(radius, math.magnitude(v1x, v1y) / 2)
        local len2 = math.min(radius, math.magnitude(v2x, v2y) / 2)

        local p1x = current_x + v1nx * -len1
        local p1y = current_y + v1ny * -len1
        local p2x = current_x + v2nx * len2
        local p2y = current_y + v2ny * len2

        -- resample bezier curve to replace missing vertices
        local curve = love.math.newBezierCurve({
            p1x, p1y,
            current_x, current_y,
            p2x, p2y
        })

        for s = 1, samples_per_corner do
            local t = s / samples_per_corner
            local x, y = curve:evaluate(t)
            table.insert(new_points, x)
            table.insert(new_points, y)
        end
    end

    -- close loop
    table.insert(new_points, new_points[1])
    table.insert(new_points, new_points[2])

    return new_points
end

function rt.is_contour_convex(vertices)
    local n = #vertices / 2
    if n < 3 then
        return false
    end

    local sign = nil

    for i = 0, n - 1 do
        local curr_idx = i * 2 + 1
        local next_idx = ((i + 1) % n) * 2 + 1
        local prev_idx = ((i - 1 + n) % n) * 2 + 1

        local curr_x, curr_y = vertices[curr_idx], vertices[curr_idx + 1]
        local next_x, next_y = vertices[next_idx], vertices[next_idx + 1]
        local prev_x, prev_y = vertices[prev_idx], vertices[prev_idx + 1]

        local edge1_x = curr_x - prev_x
        local edge1_y = curr_y - prev_y
        local edge2_x = next_x - curr_x
        local edge2_y = next_y - curr_y

        local cross_product = math.cross(edge1_x, edge1_y, edge2_x, edge2_y)

        if math.abs(cross_product) > math.eps then
            local current_sign = cross_product > 0 and 1 or -1

            if sign == nil then
                sign = current_sign
            elseif sign ~= current_sign then
                return false
            end
        end
    end

    return true
end

function rt.generate_contour_highlight(contour, light_nx, light_ny, n_iterations)
    n_iterations = n_iterations or 250 -- default number of smoothing iterations

    local center_x, center_y, n = 0, 0, 0
    for i = 1, #contour, 2 do
        local x, y = contour[i+0], contour[i+1]
        center_x = center_x + x
        center_y = center_y + y
        n = n + 1
    end

    center_x = center_x / n
    center_y = center_y / n

    local light_dir_x, light_dir_y = math.normalize(light_nx, light_ny)

    local scaled = {}
    local normals = {}
    for i = 1, #contour, 2 do
        local x, y = contour[i+0], contour[i+1]
        local dx, dy = x - center_x, y - center_y
        local length = math.magnitude(dx, dy)
        dx, dy = math.normalize(dx, dy)
        table.insert(scaled, center_x + dx * (length))
        table.insert(scaled, center_y + dy * (length))
        table.insert(normals, dx)
        table.insert(normals, dy)
    end

    -- Apply n iterations of Laplacian smoothing with light-based weighting
    local num_vertices = #scaled / 2

    for iteration = 1, n_iterations do
        local smoothed = {}

        for i = 1, num_vertices do
            local curr_idx = (i - 1) * 2 + 1
            local prev_idx = ((i - 2 + num_vertices) % num_vertices) * 2 + 1
            local next_idx = (i % num_vertices) * 2 + 1

            -- Current vertex position
            local curr_x, curr_y = scaled[curr_idx], scaled[curr_idx + 1]

            -- Neighbor positions
            local prev_x, prev_y = scaled[prev_idx], scaled[prev_idx + 1]
            local next_x, next_y = scaled[next_idx], scaled[next_idx + 1]

            -- Calculate Laplacian (average of neighbors minus current)
            local neighbor_avg_x = (prev_x + next_x) * 0.5
            local neighbor_avg_y = (prev_y + next_y) * 0.5
            local laplacian_x = neighbor_avg_x - curr_x
            local laplacian_y = neighbor_avg_y - curr_y

            -- Get normal for this vertex
            local normal_idx = (i - 1) * 2 + 1
            local normal_x, normal_y = normals[normal_idx], normals[normal_idx + 1]

            -- Calculate alignment with light direction
            -- Dot product: 1 = aligned with light, -1 = opposite to light
            local alignment = math.dot(light_dir_x, light_dir_y, normal_x, normal_y)

            -- Convert alignment to smoothing weight
            -- Vertices aligned with light (alignment close to 1) get less smoothing
            -- Vertices perpendicular or opposite to light get more smoothing
            local smoothing_weight = math.mix(0.05, 1, math.max(alignment, 0))

            -- Apply weighted Laplacian smoothing
            local new_x = curr_x + laplacian_x * smoothing_weight
            local new_y = curr_y + laplacian_y * smoothing_weight

            table.insert(smoothed, new_x)
            table.insert(smoothed, new_y)
        end

        scaled = smoothed
    end

    return scaled
end
