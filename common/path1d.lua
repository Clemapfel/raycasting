--- @class rt.Path1D
--- @brief arc-length parameterized chain of line segments for scalar values, unlike spline, extremely fast to evaluate
rt.Path1D = meta.class("Path1D")

--- @brief
function rt.Path1D:instantiate(points, ...)
    if meta.is_number(points) then
        points = { points, ... }
    end

    rt.assert(points ~= nil and #points >= 2, "In rt.Path1D: expected at least two values")

    local out = meta.install(self, {
        _points = points,
        _entries = {},
        _n_points = #points,
        _n_entries = 0,
        _length = 0,
        _first_distance = 0,
        _last_distance = 0,
        _use_arclength = false  -- track whether to use arc-length parameterization
    })
    out:create_from(points, ...)
    return out
end

--- @brief recompute internal segment entries from current points
function rt.Path1D:_update()
    local entries = {}
    local points = self._points
    local n_points = self._n_points
    local total_length = 0
    local n_entries = 0

    -- create entries for each line segment
    for i = 1, n_points - 1 do
        local v1 = points[i]
        local v2 = points[i + 1]

        local dv = v2 - v1
        local distance = math.abs(dv)
        local dir = 0
        if dv > 0 then dir = 1 elseif dv < 0 then dir = -1 end

        local entry = {
            from = v1,
            to = v2,
            dv = dv,                -- non-normalized delta (to - from)
            dir = dir,              -- normalized direction in 1D (-1, 0, 1)
            distance = distance,    -- length of segment in 1D
            cumulative_distance = total_length,
            fraction = 0,           -- set below
            fraction_length = 0     -- set below
        }

        table.insert(entries, entry)
        total_length = total_length + distance
        n_entries = n_entries + 1
    end

    if n_entries == 1 then
        entries[1].fraction = 0
        entries[1].fraction_length = 1
    elseif n_entries > 1 then
        if self._use_arclength then
            -- arc-length: fractions based on cumulative distance
            for i = 1, n_entries do
                local entry = entries[i]
                if total_length > 0 then
                    entry.fraction = entry.cumulative_distance / total_length
                    if i < n_entries then
                        local next_entry = entries[i + 1]
                        entry.fraction_length = (next_entry.cumulative_distance - entry.cumulative_distance) / total_length
                    else
                        entry.fraction_length = (total_length - entry.cumulative_distance) / total_length
                    end
                else
                    -- handle degenerate case where all segments have zero length
                    entry.fraction = i == 1 and 0 or 1
                    entry.fraction_length = 0
                end
            end
        else
            -- uniform: equal fraction for each segment
            local fraction_per_segment = 1 / n_entries
            for i = 1, n_entries do
                local entry = entries[i]
                entry.fraction = (i - 1) * fraction_per_segment
                entry.fraction_length = fraction_per_segment
            end
        end
    end

    self._entries = entries
    self._n_entries = n_entries
    self._length = total_length
    self._first_distance = n_entries > 0 and entries[1].fraction or 0
    self._last_distance = n_entries > 0 and entries[n_entries].fraction or 0
end

--- @brief binary search segment by global parameter t in [0, 1]
function rt.Path1D:_find_segment(t)
    local entries = self._entries
    local n_entries = self._n_entries

    if n_entries == 0 then
        return nil
    end

    if n_entries == 1 then
        return entries[1]
    end

    if t <= 0 then
        return entries[1]
    elseif t >= 1 then
        return entries[n_entries]
    end

    local low = 1
    local high = n_entries

    while low <= high do
        local mid = math.floor((low + high) / 2)
        local entry = entries[mid]
        local entry_end = entry.fraction + entry.fraction_length

        if t >= entry.fraction and t <= entry_end then
            return entry
        elseif t < entry.fraction then
            high = mid - 1
        else
            low = mid + 1
        end
    end

    return entries[math.clamp(low, 1, n_entries)]
end

--- @brief get value at parameter t in [0, 1]
function rt.Path1D:at(t)
    t = math.clamp(t, 0, 1)

    local segment = self:_find_segment(t)
    local local_t = (t - segment.fraction) / segment.fraction_length

    -- linear interpolation in 1D
    return segment.from + local_t * segment.dv
end

--- @brief get segment endpoints (from, to) at parameter t
function rt.Path1D:get_segment(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.from, segment.to
end

--- @brief get 1D tangent (direction) at parameter t; returns -1, 0, or 1
function rt.Path1D:tangent_at(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.dir
end

--- @brief internal creator handling reparameterization and arclength toggles
function rt.Path1D:_create_from(reparameterize_as_uniform, use_arclength, points, ...)
    if meta.is_number(points) then
        points = { points, ... }
    end

    if points == nil or #points < 1 then
        points = { 0, 0 }
    elseif #points < 2 then
        table.insert(points, points[1])
    end

    local n_points = #points
    rt.assert(n_points >= 2, "In rt.Path1D: expected at least two values")

    -- reparameterize to uniform spacing if requested
    if reparameterize_as_uniform then
        local num_points = n_points

        -- calculate cumulative distances (arc-length in 1D)
        local distances = { 0 }
        local total_length = 0
        for i = 1, n_points - 1 do
            local dist = math.abs(points[i + 1] - points[i])
            total_length = total_length + dist
            distances[#distances + 1] = total_length
        end

        if total_length > 0 then
            local uniform_points = {}
            local target_spacing = total_length / (num_points - 1)
            local num_segments = #distances - 1

            -- first point
            uniform_points[1] = points[1]

            -- intermediate points
            local segment_idx = 1
            for i = 1, num_points - 2 do
                local target_dist = i * target_spacing

                -- advance segment index to the correct segment
                while segment_idx < num_segments and target_dist > distances[segment_idx + 1] do
                    segment_idx = segment_idx + 1
                end

                local seg_start_dist = distances[segment_idx]
                local seg_end_dist = distances[segment_idx + 1]
                local seg_length = seg_end_dist - seg_start_dist

                local local_t = (target_dist - seg_start_dist) / seg_length

                local v1 = points[segment_idx]
                local v2 = points[segment_idx + 1]

                uniform_points[i + 1] = v1 + local_t * (v2 - v1)
            end

            -- last point
            uniform_points[num_points] = points[n_points]

            points = uniform_points
            n_points = #points
        end
    end

    self._points = points
    self._n_points = n_points
    self._use_arclength = use_arclength
    self:_update()
    return self
end

--- @brief create from values, uniform parameterization
function rt.Path1D:create_from(...)
    return self:_create_from(
        false, -- resample with uniform spacing
        false, -- arc-length parameterize
        ...
    )
end

--- @brief create from values, arc-length parameterization (no resampling)
function rt.Path1D:create_from_and_reparameterize(...)
    return self:_create_from(
        false,
        true,
        ...
    )
end

--- @brief create from values, resample to uniform spacing and arc-length parameterize
function rt.Path1D:create_from_and_resample(...)
    return self:_create_from(
        true,
        true,
        ...
    )
end

--- @brief return a copy of the underlying values
function rt.Path1D:get_points()
    return self._points
end

--- @brief total arc-length in 1D
function rt.Path1D:get_length()
    return self._length
end

--- @brief override arclength parameterization with custom per-segment fractions
--- @param, . Number of values equal to number of segments, must sum to 1
function rt.Path1D:override_parameterization(...)
    local n_args = select("#", ...)
    if n_args ~= self._n_entries then
        rt.error("In rt.Path1D.override_parameterization: expected `", self._n_entries, "` parameters, got `", n_args, "`")
        return
    end

    local total = 0
    local args = { ... }

    for i = 1, n_args do
        local arg = args[i]
        if type(arg) ~= "number" or arg < 0 then
            rt.error("In rt.Path1D:override_parameterization: parameter ", i, " must be a non-negative number")
            return
        end
        total = total + arg
    end

    if math.abs(total - 1) > 1e-10 then
        rt.error("In rt.Path1D:override_parameterization: total length of override parameters is `", total, "`, but `1` was expected")
        return
    end

    local fraction = 0
    for i = 1, self._n_entries do
        local entry = self._entries[i]
        entry.fraction = fraction
        entry.fraction_length = args[i]
        fraction = fraction + args[i]
    end
end

--- @brief Get the number of segments in the path
function rt.Path1D:get_segment_count()
    return self._n_entries
end

--- @brief helper function to find closest value on a specific line segment
--- @param v Number query value
--- @param entry Table segment entry from self._entries
--- @return Number, Number closest value and global parameter t
function rt.Path1D:_closest_value_on_segment(v, entry)
    local v1 = entry.from
    local v2 = entry.to
    local dv = v2 - v1
    local seg_len_sq = dv * dv

    if seg_len_sq < 1e-20 then
        -- degenerate segment
        local global_t = entry.fraction + entry.fraction_length * 0.5
        return v1, global_t
    end

    local local_t = math.clamp((v - v1) / dv, 0, 1)
    local closest_v = v1 + local_t * dv
    local global_t = entry.fraction + entry.fraction_length * local_t
    return closest_v, global_t
end

--- @brief get closest value on path to query value; returns closest value and its parameter t
function rt.Path1D:get_closest_value(v)
    if self._n_entries == 0 then
        return nil, nil
    end

    local closest_dist = math.huge
    local closest_v = nil
    local closest_t = 0

    for i = 1, self._n_entries do
        local entry = self._entries[i]
        local seg_v, seg_t = self:_closest_value_on_segment(v, entry)
        local d = math.abs(seg_v - v)

        if d < closest_dist then
            closest_dist = d
            closest_v = seg_v
            closest_t = seg_t
        end
    end

    return closest_v, closest_t
end