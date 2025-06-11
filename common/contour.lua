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
    end

    local contour = {}
    for segment in values(ordered) do
        table.insert(contour, segment[1])
        table.insert(contour, segment[2])
    end
    table.insert(contour, contour[1])
    table.insert(contour, contour[2])

    return contour
end