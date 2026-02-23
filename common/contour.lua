if rt.contour == nil then rt.contour = {} end

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
rt.contour.from_tris = function(tris, close_loop)
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
            rt.warning("In rt.contour.from_tris: contour has duplicate edges")
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
--- @param contour Table<Number>
--- @param length Number
--- @param contour Table<Number>
--- @param segment_length Number
function rt.contour.subdivide(contour, segment_length)
    local subdivided = {}

    for i = 1, #contour, 2 do
        local x1, y1 = contour[i], contour[i+1]
        local next_i = (i + 2 > #contour) and 1 or i + 2
        local x2, y2 = contour[next_i], contour[next_i+1]

        table.insert(subdivided, x1)
        table.insert(subdivided, y1)

        local dx, dy = x2 - x1, y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local n_segments = math.max(1, math.floor(length / segment_length))

        for s = 1, n_segments - 1 do
            local t = s / n_segments
            local sx = x1 + t * dx
            local sy = y1 + t * dy
            table.insert(subdivided, sx)
            table.insert(subdivided, sy)
        end
    end

    return subdivided
end

--- @param contour Table<Number>
--- @return Table<Number>
--- @param contour Table<Number>
--- @return Table<Number>
function rt.contour.get_normals(contour)
    local normals = {}
    local num_vertices = #contour / 2

    -- Determine winding order using signed area
    local signed_area = 0
    for i = 1, #contour, 2 do
        local x1, y1 = contour[i], contour[i+1]
        local next_i = (i + 2 > #contour) and 1 or (i + 2)
        local x2, y2 = contour[next_i], contour[next_i+1]
        signed_area = signed_area + (x1 * y2 - x2 * y1)
    end

    -- If signed area is negative, contour is clockwise, use turn_right
    -- If positive, contour is counter-clockwise, use turn_left
    local turn_func = (signed_area < 0) and math.turn_right or math.turn_left

    for i = 1, #contour, 2 do
        local x1, y1 = contour[i], contour[i+1]

        -- Get previous point (wrapping around for closed contour)
        local prev_i = (i - 2 < 1) and (#contour - 1) or (i - 2)
        local x0, y0 = contour[prev_i], contour[prev_i+1]

        -- Get next point (wrapping around for closed contour)
        local next_i = (i + 2 > #contour) and 1 or (i + 2)
        local x2, y2 = contour[next_i], contour[next_i+1]

        -- Compute tangent as average of incoming and outgoing directions
        local dx_in = x1 - x0
        local dy_in = y1 - y0
        local dx_out = x2 - x1
        local dy_out = y2 - y1

        -- Average tangent
        local tx = dx_in + dx_out
        local ty = dy_in + dy_out

        -- Normalize tangent
        local tangent_length = math.sqrt(tx * tx + ty * ty)
        if tangent_length > 0 then
            tx = tx / tangent_length
            ty = ty / tangent_length
        end

        -- Get normal by rotating tangent 90 degrees (outward facing)
        local nx, ny = turn_func(tx, ty)

        table.insert(normals, nx)
        table.insert(normals, ny)
    end

    return normals
end

--- ###

function rt.contour.smooth(contour, n_iterations)
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

function rt.contour.round(points, radius, samples_per_corner)
    -- Adaptive corner rounding:
    -- Replaces each sharp corner by a quadratic Bezier (p1 -> current as control -> p2)
    -- and adaptively samples it based on a flatness (curvature) tolerance to minimize vertices
    -- while preserving detail.

    -- Backward compatibility:
    -- - If 'samples_per_corner' is a number, it will be interpreted as a "quality" hint and
    --   converted to a flatness tolerance (smaller error for larger numbers).
    -- - If it's a table, you may pass:
    --     { max_error = <pixels>, min_segments = <int>, max_segments = <int>, max_depth = <int> }
    --   Defaults:
    --     max_error     = max(0.75, radius * 0.02)  -- pixels
    --     min_segments  = 1
    --     max_segments  = 64
    --     max_depth     = ceil(log2(max_segments))
    --
    -- Notes:
    -- - This implementation avoids constructing love.math.BezierCurve for performance.
    -- - The flatness test uses squared distance of the control point to chord AB.

    local n = math.floor(#points / 2)
    if n < 2 then return { } end

    radius = radius or 10

    -- Interpret options
    local opts = {}
    if type(samples_per_corner) == "table" then
        opts = samples_per_corner
    elseif type(samples_per_corner) == "number" then
        -- Map "samples_per_corner" (legacy) to a reasonable pixel error tolerance.
        -- Larger samples_per_corner -> smaller error. Clamp to avoid pathological values.
        local q = math.max(1, samples_per_corner)
        -- Heuristic: error ~= radius / (4*q^2), but clamp to a sensible range
        opts.max_error = math.max(0.25, math.min(radius / (4 * q * q), radius * 0.25))
    end

    local max_error = opts.max_error
        or math.max(0.75, radius * 0.02)           -- default error in pixels (strikes a good balance)
    local min_segments = math.max(1, opts.min_segments or 1)
    local max_segments = math.max(min_segments, opts.max_segments or 64)
    local max_depth = opts.max_depth
    if not max_depth then
        -- 2^depth ~= max_segments
        max_depth = math.ceil(math.log(max_segments) / math.log(2))
    end
    local flatness2 = max_error * max_error

    local new_points = {}

    for i = 1, n do
        local previous_idx = ((i - 2 + n) % n) + 1
        local current_idx = i
        local next_idx = (i % n) + 1

        local previous_x, previous_y = points[2 * previous_idx - 1], points[2 * previous_idx]
        local current_x, current_y   = points[2 * current_idx - 1], points[2 * current_idx]
        local next_x, next_y         = points[2 * next_idx - 1], points[2 * next_idx]

        local v1x, v1y = current_x - previous_x, current_y - previous_y
        local v2x, v2y = next_x - current_x, next_y - current_y

        -- Shorten current segments by corner radius
        local v1nx, v1ny = math.normalize(v1x, v1y)
        local v2nx, v2ny = math.normalize(v2x, v2y)
        local len1 = math.min(radius, math.magnitude(v1x, v1y) / 2)
        local len2 = math.min(radius, math.magnitude(v2x, v2y) / 2)

        local p1x = current_x - v1nx * len1
        local p1y = current_y - v1ny * len1
        local p2x = current_x + v2nx * len2
        local p2y = current_y + v2ny * len2

        -- Adaptive sampling of the quadratic Bezier curve (p1 -> current as control -> p2)
        local before_len = #new_points

        -- Stack-based iterative traversal to avoid recursion
        local stack = { { p1x, p1y, current_x, current_y, p2x, p2y, 0 } }

        while #stack > 0 do
            local entry = table.remove(stack)
            local ax, ay, cx, cy, bx, by, depth = entry[1], entry[2], entry[3], entry[4], entry[5], entry[6], entry[7]

            -- Prevent runaway recursion
            if depth >= max_depth then
                new_points[#new_points + 1] = bx
                new_points[#new_points + 1] = by
            else
                -- Squared distance from point C (control) to infinite line AB
                local abx, aby = bx - ax, by - ay
                local acx, acy = cx - ax, cy - ay
                local ab2 = math.dot(abx, aby, abx, aby)

                local is_flat = false
                if ab2 < math.eps then
                    -- Degenerate chord; treat as flat
                    is_flat = true
                else
                    -- 2D cross product magnitude squared divided by |AB|^2
                    local cross = math.cross(acx, acy, abx, aby)
                    is_flat = (cross * cross) / ab2 <= flatness2
                end

                -- If curve is sufficiently flat, approximate with a single segment (A->B).
                if is_flat then
                    new_points[#new_points + 1] = bx
                    new_points[#new_points + 1] = by
                else
                    -- De Casteljau split at t=0.5
                    local q0x, q0y = 0.5 * (ax + cx), 0.5 * (ay + cy)
                    local q1x, q1y = 0.5 * (cx + bx), 0.5 * (cy + by)
                    local rx, ry   = 0.5 * (q0x + q1x), 0.5 * (q0y + q1y)

                    -- Push right curve first (processed last)
                    stack[#stack + 1] = { rx, ry, q1x, q1y, bx, by, depth + 1 }
                    -- Push left curve (processed first)
                    stack[#stack + 1] = { ax, ay, q0x, q0y, rx, ry, depth + 1 }
                end
            end
        end

        local added_points = math.floor((#new_points - before_len) / 2)

        -- Guarantee a minimum number of segments if requested
        if min_segments > 1 and added_points < min_segments then
            -- Generate additional points uniformly in parameter space
            -- to reach at least min_segments end points.
            local to_add = min_segments - added_points
            for k = 1, to_add do
                local t = k / min_segments
                local it = 1 - t
                -- Quadratic Bezier formula
                local x = it * it * p1x + 2 * it * t * current_x + t * t * p2x
                local y = it * it * p1y + 2 * it * t * current_y + t * t * p2y
                new_points[#new_points + 1] = x
                new_points[#new_points + 1] = y
            end
        end
    end

    -- Close the contour
    if #new_points >= 2 then
        new_points[#new_points + 1] = new_points[1]
        new_points[#new_points + 1] = new_points[2]
    end

    return new_points
end

function rt.contour.is_convex(vertices)
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

--- @brief
function rt.contour.close(contour)
    if #contour < 4 then return contour end

    local last_x, last_y = contour[#contour-1], contour[#contour]
    local first_x, first_y = contour[1], contour[2]
    if math.distance(last_x, last_y, first_x, first_y) > math.eps then
        table.insert(contour, first_x)
        table.insert(contour, first_y)
    end

    return contour
end

--- @brief
function rt.contour.get_aabb(contour)
    if #contour < 4 then return rt.AABB(0, 0, 0, 0) end

    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge

    for i = 1, #contour, 2 do
        local x, y = contour[i+0], contour[i+1]
        min_x = math.min(min_x, x)
        min_y = math.min(min_y, y)
        max_x = math.max(max_x, x)
        max_y = math.max(max_y, y)
    end

    return rt.AABB(
        min_x, min_y,
        max_x - min_x, max_y - min_y
    )
end

