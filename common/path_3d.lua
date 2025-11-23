--- @class rt.Path3D
--- @brief arc-length parameterized chain of line segments in 3D; fast to evaluate (binary search for segment)
rt.Path3D = meta.class("Path3D")

--- @brief
function rt.Path3D:instantiate(points, ...)
    if meta.is_number(points) then
        points = { points, ... }
    end

    rt.assert(#points >= 6, "In rt.Path3D: need at least 2 points (6 coordinates) to create a path")
    rt.assert(#points % 3 == 0, "In rt.Path3D: number of point coordinates must be divisible by 3")

    local out = meta.install(self, {
        _points = points,
        _entries = {},
        _n_points = #points,         -- number of scalars (flattened x,y,z,...)
        _n_entries = 0,
        _length = 0,
        _first_distance = 0,
        _last_distance = 0
    })
    out:create_from(points, ...)
    return out
end

--- @brief
function rt.Path3D:_update()
    local entries = {}
    local points = self._points
    local n_points = self._n_points
    local total_length = 0
    local n_entries = 0

    -- create entries for each line segment
    for i = 1, n_points - 3, 3 do
        local x1, y1, z1 = points[i], points[i + 1], points[i + 2]
        local x2, y2, z2 = points[i + 3], points[i + 4], points[i + 5]

        local dx = x2 - x1
        local dy = y2 - y1
        local dz = z2 - z1
        local distance = math.distance(x1, y1, z1, x2, y2, z2)
        dx, dy, dz = math.normalize(dx, dy, dz)

        local entry = {
            from_x = x1,
            from_y = y1,
            from_z = z1,
            to_x = x2,
            to_y = y2,
            to_z = z2,
            dx = dx,  -- normalized direction vector
            dy = dy,
            dz = dz,
            distance = distance,
            cumulative_distance = total_length,
            fraction = 0, -- set below
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
        -- calculate fractions for multiple segments
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
    end

    self._entries = entries
    self._n_entries = n_entries
    self._length = total_length
    self._first_distance = n_entries > 0 and entries[1].fraction or 0
    self._last_distance = n_entries > 0 and entries[n_entries].fraction or 0
end

--- @brief
function rt.Path3D:_find_segment(t)
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

--- @brief get position at parameter t [0, 1]
--- @return Number, Number, Number
function rt.Path3D:at(t)
    t = math.clamp(t, 0, 1)

    local segment = self:_find_segment(t)
    local local_t = (t - segment.fraction) / segment.fraction_length

    local distance_along_segment = local_t * segment.distance
    return math.add(
        segment.from_x,
        segment.from_y,
        segment.from_z,
        segment.dx * distance_along_segment,
        segment.dy * distance_along_segment,
        segment.dz * distance_along_segment
    )
end

--- @brief
--- @return Number, Number, Number, Number, Number, Number
function rt.Path3D:get_segment(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.from_x, segment.from_y, segment.from_z, segment.to_x, segment.to_y, segment.to_z
end

--- @brief
--- @return Number, Number, Number
function rt.Path3D:get_tangent(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.dx, segment.dy, segment.dz
end

--- @brief
function rt.Path3D:_create_from(reparameterize_as_uniform, points, ...)
    if meta.is_number(points) then
        points = { points, ... }
    end

    local n_points = #points
    rt.assert(n_points >= 6, "In rt.Path3D: need at least 2 points (6 coordinates) to draw a path")
    rt.assert(n_points % 3 == 0, "In rt.Path3D: number of point coordinates must be divisible by 3")

    -- reparameterize to uniform spacing if requested
    if reparameterize_as_uniform then
        local dim = 3
        local num_points = n_points / dim

        -- calculate cumulative distances
        local distances = { 0 }
        local total_length = 0
        for i = 1, n_points - dim, dim do
            local dist = math.distance(
                points[i], points[i + 1], points[i + 2],
                points[i + 3], points[i + 4], points[i + 5]
            )
            total_length = total_length + dist
            distances[#distances + 1] = total_length
        end

        if total_length > 0 then
            local uniform_points = {}
            local target_spacing = total_length / (num_points - 1)
            local num_segments = #distances - 1

            -- first point
            uniform_points[1] = points[1]
            uniform_points[2] = points[2]
            uniform_points[3] = points[3]

            -- intermediate points
            local segment_idx = 1
            for i = 1, num_points - 2 do
                local target_dist = i * target_spacing

                -- advance segment_idx (distances are sorted, so we can start from last position)
                while segment_idx < num_segments and target_dist > distances[segment_idx + 1] do
                    segment_idx = segment_idx + 1
                end

                -- interpolate within the segment
                local seg_start_dist = distances[segment_idx]
                local seg_end_dist = distances[segment_idx + 1]
                local seg_length = seg_end_dist - seg_start_dist

                local local_t = (target_dist - seg_start_dist) / seg_length

                local point_idx = (segment_idx - 1) * dim + 1
                local x1, y1, z1 = points[point_idx], points[point_idx + 1], points[point_idx + 2]
                local x2, y2, z2 = points[point_idx + 3], points[point_idx + 4], points[point_idx + 5]

                local out_idx = i * dim + 1
                -- inline mix3 to avoid dependency; math.mix2 exists, but we compute component-wise for 3D
                uniform_points[out_idx]     = x1 * (1 - local_t) + x2 * local_t
                uniform_points[out_idx + 1] = y1 * (1 - local_t) + y2 * local_t
                uniform_points[out_idx + 2] = z1 * (1 - local_t) + z2 * local_t
            end

            -- last point
            local last_idx = (num_points - 1) * dim + 1
            uniform_points[last_idx]     = points[n_points - 2]
            uniform_points[last_idx + 1] = points[n_points - 1]
            uniform_points[last_idx + 2] = points[n_points]

            points = uniform_points
            n_points = #points
        end
    end

    self._points = points
    self._n_points = n_points
    self:_update()
end

--- @brief
function rt.Path3D:create_from(...)
    self:_create_from(false, ...)
end

--- @brief
function rt.Path3D:create_from_and_reparameterize(...)
    self:_create_from(true, ...)
end

--- @brief
function rt.Path3D:list_points()
    local out = {}
    for i = 1, self._n_points, 3 do
        table.insert(out, { self._points[i], self._points[i + 1], self._points[i + 2] })
    end
    return out
end

--- @brief
function rt.Path3D:get_length()
    return self._length
end

--- @brief draw (not implemented for 3D)
function rt.Path3D:draw()
    -- 3D rendering is outside the scope of this class
end

--- @brief override arclength parameterization with custom per-segment fraction
--- @param, . Number of values equal to number of segments, must sum to 1
function rt.Path3D:override_parameterization(...)
    local n_args = select("#", ...)
    if n_args ~= self._n_entries then
        rt.error("In rt.Path3D.override_parameterization: expected `", self._n_entries, "` parameters, got `", n_args, "`")
        return
    end

    local total = 0
    local args = { ... }

    -- validate arguments sum to 1
    for i = 1, n_args do
        local arg = args[i]
        if type(arg) ~= "number" or arg < 0 then
            rt.error("In rt.Path3D:override_parameterization: parameter ", i, " must be a non-negative number")
            return
        end
        total = total + arg
    end

    if math.abs(total - 1) > 1e-10 then
        rt.error("In rt.Path3D:override_parameterization: total length of override parameters is `", total, "`, but `1` was expected")
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
function rt.Path3D:get_segment_count()
    return self._n_entries
end

--- @brief helper function to find closest point on a specific line segment
--- @param x Number query point x
--- @param y Number query point y
--- @param z Number query point z
--- @param entry Table segment entry from self._entries
--- @return Number, Number, Number, Number closest point x, y, z and global parameter t
function rt.Path3D:_closest_point_on_segment(x, y, z, entry)
    local x1, y1, z1 = entry.from_x, entry.from_y, entry.from_z
    local x2, y2, z2 = entry.to_x, entry.to_y, entry.to_z

    -- vector from start to end of segment
    local segment_dx = x2 - x1
    local segment_dy = y2 - y1
    local segment_dz = z2 - z1
    local segment_length_sq = segment_dx * segment_dx + segment_dy * segment_dy + segment_dz * segment_dz

    if segment_length_sq < 1e-10 then
        -- degenerate segment
        local global_t = entry.fraction + entry.fraction_length * 0.5
        return x1, y1, z1, global_t
    end

    local dot = (x - x1) * segment_dx + (y - y1) * segment_dy + (z - z1) * segment_dz
    local local_t = math.clamp(dot / segment_length_sq, 0, 1)

    local closest_x = x1 + local_t * segment_dx
    local closest_y = y1 + local_t * segment_dy
    local closest_z = z1 + local_t * segment_dz
    local global_t = entry.fraction + entry.fraction_length * local_t

    return closest_x, closest_y, closest_z, global_t
end

--- @brief find closest point on the path to a 3D query point
--- @return Number, Number, Number, Number closest x, y, z, and parameter t
function rt.Path3D:get_closest_point(x, y, z)
    if self._n_entries == 0 then
        return nil, nil, nil, nil
    end

    local closest_distance_sq = math.huge
    local closest_x, closest_y, closest_z = nil, nil, nil
    local closest_t = 0

    for i = 1, self._n_entries do
        local entry = self._entries[i]
        local segment_x, segment_y, segment_z, segment_t = self:_closest_point_on_segment(x, y, z, entry)

        local dx = segment_x - x
        local dy = segment_y - y
        local dz = segment_z - z
        local distance_sq = dx * dx + dy * dy + dz * dz

        if distance_sq < closest_distance_sq then
            closest_distance_sq = distance_sq
            closest_x = segment_x
            closest_y = segment_y
            closest_z = segment_z
            closest_t = segment_t
        end
    end

    return closest_x, closest_y, closest_z, closest_t
end

--- @brief
function rt.Path3D:get_points()
    return self._points
end