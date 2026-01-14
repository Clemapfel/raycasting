--- @class rt.Path1D
--- @brief arc-length parameterized chain of line segments for 1D values
rt.Path1D = meta.class("Path1D")

--- @brief
function rt.Path1D:instantiate(values, ...)
    if meta.is_number(values) then
        values = { values, ... }
    end

    local out = meta.install(self, {
        _values = values,
        _entries = {},
        _n_values = #values,
        _n_entries = 0,
        _length = 0,
        _first_distance = 0,
        _last_distance = 0,
        _use_arclength = false
    })
    out:create_from(values, ...)
    return out
end

--- @brief
function rt.Path1D:_update()
    local entries = {}
    local values = self._values
    local n_values = self._n_values
    local total_length = 0
    local n_entries = 0

    -- create entries for each segment
    for i = 1, n_values - 1 do
        local v1 = values[i]
        local v2 = values[i+1]

        local dv = v2 - v1
        local distance = math.abs(dv)
        local direction = dv >= 0 and 1 or -1

        local entry = {
            from_v = v1,
            to_v = v2,
            dv = direction,  -- normalized direction (-1 or 1)
            distance = distance,
            cumulative_distance = total_length,
            fraction = 0,
            fraction_length = 0
        }

        table.insert(entries, entry)
        total_length = total_length + distance
        n_entries = n_entries + 1
    end

    if n_entries == 1 then
        entries[1].fraction = 0
        entries[1].fraction_length = 1
    else
        -- calculate fractions based on whether arc-length parameterization is enabled
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

--- @brief
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

    -- binary search for the correct segment
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

--- @brief get value at parameter t [0, 1]
function rt.Path1D:at(t)
    t = math.clamp(t, 0, 1)

    local segment = self:_find_segment(t)
    if segment.fraction_length == 0 then
        return segment.from_v
    end

    local local_t = (t - segment.fraction) / segment.fraction_length
    local distance_along_segment = local_t * segment.distance

    return segment.from_v + segment.dv * distance_along_segment
end

--- @brief
function rt.Path1D:get_segment(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.from_v, segment.to_v
end

--- @brief
function rt.Path1D:tangent_at(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.dv
end

--- @brief
function rt.Path1D:_create_from(reparameterize_as_uniform, use_arclength, values, ...)
    if meta.is_number(values) then
        values = { values, ... }
    end

    if values == nil or #values < 1 then
        values = { 0, 0 }
    elseif #values < 2 then
        table.insert(values, values[1])
    end

    local n_values = #values

    -- reparameterize to uniform spacing if requested
    if reparameterize_as_uniform then
        local num_values = n_values

        -- calculate cumulative distances
        local distances = { 0 }
        local total_length = 0
        for i = 1, n_values - 1 do
            local dist = math.abs(values[i+1] - values[i])
            total_length = total_length + dist
            distances[#distances + 1] = total_length
        end

        if total_length > 0 then
            local uniform_values = {}
            local target_spacing = total_length / (num_values - 1)
            local num_segments = #distances - 1

            -- first value
            uniform_values[1] = values[1]

            -- intermediate values
            local segment_idx = 1
            for i = 1, num_values - 2 do
                local target_dist = i * target_spacing

                -- advance segment_idx
                while segment_idx < num_segments and target_dist > distances[segment_idx + 1] do
                    segment_idx = segment_idx + 1
                end

                -- interpolate within the segment
                local seg_start_dist = distances[segment_idx]
                local seg_end_dist = distances[segment_idx + 1]
                local seg_length = seg_end_dist - seg_start_dist

                local local_t = (target_dist - seg_start_dist) / seg_length

                local v1 = values[segment_idx]
                local v2 = values[segment_idx + 1]

                uniform_values[i + 1] = v1 + (v2 - v1) * local_t
            end

            -- last value
            uniform_values[num_values] = values[n_values]

            values = uniform_values
            n_values = #values
        end
    end

    self._values = values
    self._n_values = n_values
    self._use_arclength = use_arclength
    self:_update()
    return self
end

--- @brief
function rt.Path1D:create_from(...)
    return self:_create_from(
        false, -- resample with uniform spacing
        false, -- arc-length parameterize
        ...
    )
end

--- @brief
function rt.Path1D:create_from_and_reparameterize(...)
    return self:_create_from(
        false,
        true,
        ...
    )
end

--- @brief
function rt.Path1D:create_from_and_resample(...)
    return self:_create_from(
        true,
        true,
        ...
    )
end

--- @brief
function rt.Path1D:get_values()
    local out = {}
    for i = 1, self._n_values do
        table.insert(out, self._values[i])
    end
    return out
end

--- @brief
function rt.Path1D:get_length()
    return self._length
end

--- @brief override arclength parameterization with custom per-segment fraction
--- @param ... Number of values equal to number of segments, must sum to 1
function rt.Path1D:override_parameterization(...)
    local n_args = select("#", ...)
    if n_args ~= self._n_entries then
        rt.error("In rt.Path1D.override_parameterization: expected `", self._n_entries, "` parameters, got `", n_args, "`")
        return
    end

    local total = 0
    local args = {...}

    -- validate arguments sum to 1
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