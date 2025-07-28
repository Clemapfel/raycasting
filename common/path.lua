--- @class rt.Path
--- @brief arc-length parameterized chain of line segments, unlike spline, extremely fast to evaluate
rt.Path = meta.class("Path")

--- @brief
function rt.Path:instantiate(points, ...)
    if meta.is_number(points) then
        points = {points, ...}
    end

    assert(#points >= 2 and #points % 2 == 0)
    local out = meta.install(self, {
        _points = points,
        _segments = {},      -- Flattened segment data for cache efficiency
        _n_segments = 0,
        _length = 0
    })
    out:create_from(points, ...)
    return out
end

do
    local _sqrt = math.sqrt
    local _atan2, _sin, _cos = math.atan2, math.sin, math.cos
    local _floor = math.floor

    --- @brief Build optimized segment data structure with lookup table
    function rt.Path:_update()
        local points = self._points
        local n_points = #points
        local n_segments = (n_points / 2) - 1

        -- Pre-allocate flat arrays for better cache performance
        local segments = {}
        local total_length = 0

        -- Build segments with all needed data in flat structure
        for i = 1, n_segments do
            local idx = (i - 1) * 2 + 1
            local x1, y1 = points[idx], points[idx + 1]
            local x2, y2 = points[idx + 2], points[idx + 3]

            local dx, dy = x2 - x1, y2 - y1
            local length = _sqrt(dx * dx + dy * dy)
            local cos_angle, sin_angle = 0, 0

            if length > 0 then
                cos_angle, sin_angle = dx / length, dy / length
            end

            -- Store segment data in flat structure for cache efficiency
            local segment_base = (i - 1) * 8
            segments[segment_base + 1] = x1              -- from_x
            segments[segment_base + 2] = y1              -- from_y
            segments[segment_base + 3] = cos_angle       -- cos(angle)
            segments[segment_base + 4] = sin_angle       -- sin(angle)
            segments[segment_base + 5] = length          -- segment length
            segments[segment_base + 6] = total_length    -- cumulative distance
            segments[segment_base + 7] = 0               -- fraction (filled below)
            segments[segment_base + 8] = 0               -- fraction_length (filled below)

            total_length = total_length + length
        end

        -- Calculate fractions in second pass to avoid division by zero
        if total_length > 0 then
            for i = 1, n_segments do
                local seg_base = (i - 1) * 8
                local cumulative = segments[seg_base + 6]
                local length = segments[seg_base + 5]

                segments[seg_base + 7] = cumulative / total_length      -- fraction
                segments[seg_base + 8] = length / total_length          -- fraction_length
            end
        else
            -- Handle degenerate case
            for i = 1, n_segments do
                local seg_base = (i - 1) * 8
                segments[seg_base + 7] = 0  -- fraction
                segments[seg_base + 8] = (i == 1) and 1 or 0  -- fraction_length
            end
        end

        -- Build lookup table for O(1) segment finding
        -- Use adaptive resolution based on number of segments
        local lookup_size = math.clamp(n_segments * 4, 64, 1024)
        local lookup_table = {}

        for i = 0, lookup_size do
            local t = i / lookup_size
            local segment_idx = 1

            -- Find which segment this t falls into
            for j = 1, n_segments do
                local seg_base = (j - 1) * 8
                local fraction = segments[seg_base + 7]
                local fraction_end = fraction + segments[seg_base + 8]

                if t >= fraction and t < fraction_end then
                    segment_idx = j
                    break
                elseif j == n_segments then
                    segment_idx = j  -- Last segment for t=1
                end
            end

            lookup_table[i] = segment_idx
        end

        self._segments = segments
        self._n_segments = n_segments
        self._length = total_length
        self._lookup_table = lookup_table
        self._lookup_size = lookup_size
    end

    --- @brief Ultra-fast O(1) at function using lookup table
    function rt.Path:at(t)
        t = math.clamp(t, 0, 1)

        local n_segments = self._n_segments
        local segments = self._segments

        if n_segments <= 0 then
            return self._points[1] or 0, self._points[2] or 0
        end

        -- Handle edge cases
        if t <= 0 then
            return segments[1], segments[2]  -- First point
        end
        if t >= 1 then
            local last_base = (n_segments - 1) * 8
            local last_x = segments[last_base + 1]
            local last_y = segments[last_base + 2]
            local last_cos = segments[last_base + 3]
            local last_sin = segments[last_base + 4]
            local last_length = segments[last_base + 5]
            return last_x + last_length * last_cos, last_y + last_length * last_sin
        end

        -- O(1) lookup using pre-computed table
        local lookup_idx = _floor(t * self._lookup_size + 0.5)
        local segment_idx = self._lookup_table[lookup_idx]

        -- Verify segment is correct (handles edge cases in lookup)
        local seg_base = (segment_idx - 1) * 8
        local fraction = segments[seg_base + 7]
        local fraction_end = fraction + segments[seg_base + 8]

        -- If lookup was slightly off, do a quick local search
        if t < fraction and segment_idx > 1 then
            segment_idx = segment_idx - 1
            seg_base = (segment_idx - 1) * 8
            fraction = segments[seg_base + 7]
        elseif t >= fraction_end and segment_idx < n_segments then
            segment_idx = segment_idx + 1
            seg_base = (segment_idx - 1) * 8
            fraction = segments[seg_base + 7]
        end

        -- Interpolate within the found segment
        local from_x = segments[seg_base + 1]
        local from_y = segments[seg_base + 2]
        local cos_angle = segments[seg_base + 3]
        local sin_angle = segments[seg_base + 4]
        local length = segments[seg_base + 5]
        local fraction_length = segments[seg_base + 8]

        -- Calculate distance along this segment
        local local_t = (fraction_length > 0) and ((t - fraction) / fraction_length) or 0
        local distance = local_t * length

        return from_x + distance * cos_angle, from_y + distance * sin_angle
    end
end

--- @brief
function rt.Path:create_from(points, ...)
    if meta.is_number(points) then points = {points, ...} end
    self._points = points
    local n_points = #points
    assert(n_points >= 4, "In rt.Path: need at least 2 points to draw a path")
    assert(n_points % 2 == 0, "In rt.Path: number of point coordinates is not a multiple of two")
    self:_update()
end

--- @brief
function rt.Path:list_points()
    local out = {}
    for i = 1, #self._points, 2 do
        table.insert(out, self._points[i])
        table.inserT(out, self._points[i+1])
    end
    return out
end

--- @brief
function rt.Path:get_length()
    return self._length
end

--- @brief
function rt.Path:draw()
    love.graphics.line(self._points)
end

--- @brief override arclength parameterization with custom per-edge fraction
--- @param ... Number n-1 values, where n is the number of points, has to sum to 1
function rt.Path:override_parameterization(...)
    local n_args = select("#", ...)
    if n_args ~= self._n_segments then
        rt.error("In rt.Path.override_parametrization: expected `" .. self._n_segments .. "` parameters, got `" .. n_args .. "`")
        return
    end

    local total = 0
    local fraction = 0

    -- Validate and calculate total first
    for i = 1, n_args do
        total = total + select(i, ...)
    end

    if math.abs(total - 1) > 1e-10 then
        rt.error("In rt.Path:override_parametrization: total length of override parameters is `" .. total .. "`, but `1` was expected")
        return
    end

    -- Apply override to flat segment data
    for i = 1, self._n_segments do
        local seg_base = (i - 1) * 8
        local fraction_length = select(i, ...)

        self._segments[seg_base + 7] = fraction      -- fraction
        self._segments[seg_base + 8] = fraction_length  -- fraction_length

        fraction = fraction + fraction_length
    end
end