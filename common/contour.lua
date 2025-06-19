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
    points[1] = points[#points - 1]
    points[2] = points[#points - 0]
    return points
end