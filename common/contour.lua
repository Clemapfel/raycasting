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

function rt.generate_contour_highlight(contour, light_nx, light_ny, n_iterations, border)
    n_iterations = n_iterations or 250 -- default number of smoothing iterations
    if border == nil then border = 0 end

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
        table.insert(scaled, center_x + dx * (length - border))
        table.insert(scaled, center_y + dy * (length - border))
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

-- Optimal Transport Contour Morphing with Arc-Length Resampling

function rt.interpolate_contours(contour_a, contour_b, t)
    -- Helper: Compute signed area to determine orientation
    local function signed_area(contour)
        local area = 0
        local n = #contour / 2
        for i = 1, n do
            local x1, y1 = contour[2*i-1], contour[2*i]
            local j = (i % n) + 1
            local x2, y2 = contour[2*j-1], contour[2*j]
            area = area + (x1 * y2 - x2 * y1)
        end
        return area / 2
    end

    -- Helper: Ensure counter-clockwise orientation
    local function ensure_ccw(contour)
        if signed_area(contour) < 0 then
            local reversed = {}
            for i = #contour, 1, -2 do
                table.insert(reversed, contour[i-1])
                table.insert(reversed, contour[i])
            end
            return reversed
        else
            return contour
        end
    end

    -- Helper: Arc-length parameterization and resampling
    local function arc_length_table(contour)
        local n = math.floor(#contour / 2)
        local lengths = {0}
        local total = 0
        for i = 1, n do
            local x1, y1 = contour[2*i-1], contour[2*i]
            local j = (i % n) + 1
            local x2, y2 = contour[2*j-1], contour[2*j]
            local seg = math.sqrt((x2-x1)^2 + (y2-y1)^2)
            total = total + seg
            table.insert(lengths, total)
        end
        return lengths, total
    end

    local function resample_by_arclength(contour, n_samples)
        local lengths, total = arc_length_table(contour)
        local n = math.floor(#contour / 2)
        local result = {}
        for s = 0, n_samples-1 do
            local target = s * total / n_samples
            -- Find which segment this falls into
            local seg = 1
            while seg < #lengths and lengths[seg+1] < target do
                seg = seg + 1
            end
            local t = (target - lengths[seg]) / (lengths[seg+1] - lengths[seg])
            local x1, y1 = contour[2*seg-1], contour[2*seg]
            local j = (seg % n) + 1
            local x2, y2 = contour[2*j-1], contour[2*j]
            local x = x1 + t * (x2 - x1)
            local y = y1 + t * (y2 - y1)
            table.insert(result, x)
            table.insert(result, y)
        end
        return result
    end

    -- Helper: Align starting point of contour_b to best match contour_a
    local function align_starting_point(contour_a, contour_b)
        local n = #contour_a / 2
        local min_sum = math.huge
        local best_offset = 0
        for offset = 0, n-1 do
            local sum = 0
            for i = 1, n do
                local idx_a = 2*i-1
                local idx_b = 2*((i+offset-1)%n+1)-1
                local dx = contour_a[idx_a] - contour_b[idx_b]
                local dy = contour_a[idx_a+1] - contour_b[idx_b+1]
                sum = sum + dx*dx + dy*dy
            end
            if sum < min_sum then
                min_sum = sum
                best_offset = offset
            end
        end
        -- Rotate contour_b by best_offset
        local aligned = {}
        for i = 1, n do
            local idx = 2*((i+best_offset-1)%n+1)-1
            table.insert(aligned, contour_b[idx])
            table.insert(aligned, contour_b[idx+1])
        end
        return aligned
    end

    -- Preprocessing: Ensure both contours have same orientation
    contour_a = ensure_ccw(contour_a)
    contour_b = ensure_ccw(contour_b)

    -- Resample both contours by arc-length to the same number of points
    local n_a = #contour_a / 2
    local n_b = #contour_b / 2
    local n_points = math.max(n_a, n_b)
    contour_a = resample_by_arclength(contour_a, n_points)
    contour_b = resample_by_arclength(contour_b, n_points)

    -- Align starting points after resampling
    contour_b = align_starting_point(contour_a, contour_b)
    local n = n_points

    -- Helper function: squared Euclidean distance
    local function squared_distance(x1, y1, x2, y2)
        local dx = x1 - x2
        local dy = y1 - y2
        return dx * dx + dy * dy
    end

    -- Step 1: Create cost matrix
    local cost_matrix = {}
    for i = 1, n do
        cost_matrix[i] = {}
        local x_a = contour_a[2*i - 1]
        local y_a = contour_a[2*i]
        for j = 1, n do
            local x_b = contour_b[2*j - 1]
            local y_b = contour_b[2*j]
            cost_matrix[i][j] = squared_distance(x_a, y_a, x_b, y_b)
        end
    end

    -- Step 2: Sinkhorn algorithm for optimal transport
    local reg_param = 0.05
    local max_iter = 200
    local tolerance = 1e-8
    local mu = {}
    local nu = {}
    for i = 1, n do mu[i] = 1.0 / n end
    for j = 1, n do nu[j] = 1.0 / n end
    local K = {}
    for i = 1, n do
        K[i] = {}
        for j = 1, n do
            K[i][j] = math.exp(-cost_matrix[i][j] / reg_param)
        end
    end
    local u = {}
    local v = {}
    for i = 1, n do u[i] = 1.0 / n end
    for j = 1, n do v[j] = 1.0 / n end
    for iter = 1, max_iter do
        local u_prev = {}
        for i = 1, n do u_prev[i] = u[i] end
        for i = 1, n do
            local sum = 0
            for j = 1, n do
                sum = sum + K[i][j] * v[j]
            end
            u[i] = mu[i] / sum
        end
        for j = 1, n do
            local sum = 0
            for i = 1, n do
                sum = sum + K[i][j] * u[i]
            end
            v[j] = nu[j] / sum
        end
        local diff = 0
        for i = 1, n do
            diff = diff + math.abs(u[i] - u_prev[i])
        end
        if diff < tolerance then
            break
        end
    end
    local transport_matrix = {}
    for i = 1, n do
        transport_matrix[i] = {}
        for j = 1, n do
            transport_matrix[i][j] = u[i] * K[i][j] * v[j]
        end
    end

    -- Step 3: Interpolate using transport plan
    local function source_based()
        local result = {}
        for i = 1, n do
            local x_a = contour_a[2*i - 1]
            local y_a = contour_a[2*i]
            local weighted_x, weighted_y = 0, 0
            local total_weight = 0
            for j = 1, n do
                local weight = transport_matrix[i][j]
                if weight > 1e-12 then
                    local x_b = contour_b[2*j - 1]
                    local y_b = contour_b[2*j]
                    weighted_x = weighted_x + weight * x_b
                    weighted_y = weighted_y + weight * y_b
                    total_weight = total_weight + weight
                end
            end
            if total_weight > 1e-12 then
                weighted_x = weighted_x / total_weight
                weighted_y = weighted_y / total_weight
            else
                local min_dist = math.huge
                for j = 1, n do
                    local x_b = contour_b[2*j - 1]
                    local y_b = contour_b[2*j]
                    local dist = squared_distance(x_a, y_a, x_b, y_b)
                    if dist < min_dist then
                        min_dist = dist
                        weighted_x, weighted_y = x_b, y_b
                    end
                end
            end
            result[2*i - 1] = (1 - t) * x_a + t * weighted_x
            result[2*i]     = (1 - t) * y_a + t * weighted_y
        end
        return result
    end

    local function target_based()
        local result = {}
        for j = 1, n do
            local x_b = contour_b[2*j - 1]
            local y_b = contour_b[2*j]
            local weighted_x, weighted_y = 0, 0
            local total_weight = 0
            for i = 1, n do
                local weight = transport_matrix[i][j]
                if weight > 1e-12 then
                    local x_a = contour_a[2*i - 1]
                    local y_a = contour_a[2*i]
                    weighted_x = weighted_x + weight * x_a
                    weighted_y = weighted_y + weight * y_a
                    total_weight = total_weight + weight
                end
            end
            if total_weight > 1e-12 then
                weighted_x = weighted_x / total_weight
                weighted_y = weighted_y / total_weight
            else
                local min_dist = math.huge
                for i = 1, n do
                    local x_a = contour_a[2*i - 1]
                    local y_a = contour_a[2*i]
                    local dist = squared_distance(x_b, y_b, x_a, y_a)
                    if dist < min_dist then
                        min_dist = dist
                        weighted_x, weighted_y = x_a, y_a
                    end
                end
            end
            result[2*j - 1] = (1 - t) * weighted_x + t * x_b
            result[2*j]     = (1 - t) * weighted_y + t * y_b
        end
        return result
    end

    local interpolated
    if t == 0 then
        interpolated = contour_a
    elseif t == 1 then
        interpolated = contour_b
    else
        local s = source_based()
        local d = target_based()
        local alpha = 1 - t
        interpolated = {}
        local max_distance = -math.huge
        for i = 1, #s, 2 do
            local from_x, from_y = s[i+0], s[i+1]
            local to_x, to_y = d[i+0], d[i+1]
            max_distance = math.max(max_distance, math.distance(from_x, from_y, to_x, to_y))
        end

        for i = 1, #s, 2 do
            local from_x, from_y = s[i+0], s[i+1]
            local to_x, to_y = d[i+0], d[i+1]
            local distance = math.distance(from_x, from_y, to_x, to_y)
            interpolated[i+0], interpolated[i+1] = math.mix2(from_x, from_y, to_x, to_y, math.clamp(t * (1 + distance / max_distance), 0, 1))
        end
    end

    return interpolated
end
