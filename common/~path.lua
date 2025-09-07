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
        _length = 0,
        _lookup_table = {},
        _lookup_size = 0
    })
    out:create_from(points, ...)
    return out
end

do
    local _sqrt = math.sqrt
    local _floor = math.floor

    --- Rebuild the lookup table from current _segments fractions in O(n_segments + lookup_size)
    function rt.Path:_rebuild_lookup_table()
        local n_segments = self._n_segments
        local segments = self._segments

        -- Adaptive resolution as before
        local lookup_size = math.clamp(n_segments * 4, 64, 1024)
        self._lookup_size = lookup_size

        local lookup_table = {}

        if n_segments <= 0 then
            for i = 0, lookup_size do
                lookup_table[i] = 1
            end
            self._lookup_table = lookup_table
            return
        end

        local function base(j) return (j - 1) * 8 end

        -- Initialize first segment window
        local j = 1
        local b = base(j)
        local fraction = segments[b + 7] or 0
        local fraction_end = fraction + (segments[b + 8] or 0)

        for i = 0, lookup_size do
            local t = i / lookup_size

            -- Advance to the segment that contains t (skip zero-length fractions)
            while j < n_segments and t >= fraction_end do
                j = j + 1
                b = base(j)
                fraction = segments[b + 7] or 0
                fraction_end = fraction + (segments[b + 8] or 0)
            end

            lookup_table[i] = j
        end

        self._lookup_table = lookup_table
    end

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
            -- Handle degenerate case: all lengths zero
            for i = 1, n_segments do
                local seg_base = (i - 1) * 8
                segments[seg_base + 7] = 0                    -- fraction
                segments[seg_base + 8] = (i == 1) and 1 or 0  -- fraction_length
            end
        end

        self._segments = segments
        self._n_segments = n_segments
        self._length = total_length

        -- Build lookup table from current fractions
        self:_rebuild_lookup_table()
    end

    --- @brief Ultra-fast at function using lookup table with robust local correction
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

        -- O(1) lookup using pre-computed table (round to nearest slot)
        local lookup_idx = _floor(t * self._lookup_size + 0.5)
        local segment_idx = self._lookup_table[lookup_idx] or 1

        -- Ensure segment_idx is valid
        if segment_idx < 1 then segment_idx = 1 end
        if segment_idx > n_segments then segment_idx = n_segments end

        -- Verify segment is correct; adjust with bounded while loops
        local function seg_base(i) return (i - 1) * 8 end

        local sb = seg_base(segment_idx)
        local fraction = segments[sb + 7]
        local fraction_end = fraction + segments[sb + 8]

        -- Move left if t is before this segment's range
        while segment_idx > 1 and t < fraction do
            segment_idx = segment_idx - 1
            sb = seg_base(segment_idx)
            fraction = segments[sb + 7]
            fraction_end = fraction + segments[sb + 8]
        end

        -- Move right if t is after this segment's range
        while segment_idx < n_segments and t >= fraction_end do
            segment_idx = segment_idx + 1
            sb = seg_base(segment_idx)
            fraction = segments[sb + 7]
            fraction_end = fraction + segments[sb + 8]
        end

        -- Interpolate within the found segment
        local from_x = segments[sb + 1]
        local from_y = segments[sb + 2]
        local cos_angle = segments[sb + 3]
        local sin_angle = segments[sb + 4]
        local length = segments[sb + 5]
        local fraction_length = segments[sb + 8]

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
        table.insert(out, self._points[i + 1])
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

    if math.abs(total - 1) > 0.05 then
        rt.error("In rt.Path:override_parametrization: total length of override parameters is `" .. total .. "`, but `1` was expected")
        return
    end

    -- Apply override to flat segment data
    for i = 1, self._n_segments do
        local seg_base = (i - 1) * 8
        local fraction_length = select(i, ...)

        self._segments[seg_base + 7] = fraction         -- fraction
        self._segments[seg_base + 8] = fraction_length   -- fraction_length

        fraction = fraction + fraction_length
    end

    -- IMPORTANT: fractions changed => rebuild lookup
    self:_rebuild_lookup_table()
end