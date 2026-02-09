--- @class rt.Path
--- @brief arc-length parameterized chain of line segments, unlike spline, extremely fast to evaluate
rt.Path = meta.class("Path")

rt.Path2D = rt.Path -- alias to be consistent with `Path3D`

--- @brief
function rt.Path:instantiate(points, ...)
    if points == nil then points = { 0, 0, 0, 0 } end

    if meta.is_number(points) then
        points = { points, ... }
    end

    rt.assert(#points % 2 == 0, "In rt.Path: number of point coordinates must be even")

    local out = meta.install(self, {
        _points = points,
        _entries = {},
        _n_points = #points,
        _n_entries = 0,
        _length = 0,
        _first_distance = 0,
        _last_distance = 0,
        _use_arclength = false,  -- track whether to use arc-length parameterization
        _orientation = 0         -- winding orientation: 1 (CCW), -1 (CW), 0 (degenerate)
    })
    out:create_from(points, ...)
    return out
end

--- @brief
function rt.Path:_update()
    local entries = {}
    local points = self._points
    local n_points = self._n_points
    local total_length = 0
    local n_entries = 0

    -- compute winding based on signed area (shoelace); positive => CCW, negative => CW
    local signed_area2 = 0
    if n_points >= 6 then
        for i = 1, n_points - 2, 2 do
            local x1, y1 = points[i], points[i + 1]
            local x2, y2 = points[i + 2], points[i + 3]
            signed_area2 = signed_area2 + (x1 * y2 - x2 * y1)
        end
        -- close the polygon by adding last -> first
        local lx, ly = points[n_points - 1], points[n_points]
        local fx, fy = points[1], points[2]
        signed_area2 = signed_area2 + (lx * fy - fx * ly)
    end

    local orientation = 0
    if math.abs(signed_area2) > math.eps then
        orientation = signed_area2 > 0 and 1 or -1
    end
    self._orientation = orientation

    -- create entries for each line segment
    for i = 1, n_points - 2, 2 do
        local x1, y1 = points[i], points[i+1]
        local x2, y2 = points[i+2], points[i+3]

        local dx = x2 - x1
        local dy = y2 - y1
        local distance = math.distance(x1, y1, x2, y2)
        dx, dy = math.normalize(dx, dy)

        -- precompute normal using winding
        local nx, ny
        if orientation >= 0 then
            -- CCW or degenerate: use left-hand normal
            nx, ny = -dy, dx
        else
            -- CW: use right-hand normal
            nx, ny = dy, -dx
        end

        local entry = {
            from_x = x1,
            from_y = y1,
            to_x = x2,
            to_y = y2,
            dx = dx,  -- normalized direction vector
            dy = dy,
            nx = nx,  -- precomputed normal vector
            ny = ny,
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
function rt.Path:_find_segment(t)
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
function rt.Path:at(t)
    t = math.clamp(t, 0, 1)

    local segment = self:_find_segment(t)

    -- handle degenerate segment (zero length) - return start point
    if segment.fraction_length < 1e-10 then
        return segment.from_x, segment.from_y
    end

    local local_t = (t - segment.fraction) / segment.fraction_length

    local distance_along_segment = local_t * segment.distance
    return math.add(
        segment.from_x,
        segment.from_y,
        segment.dx * distance_along_segment,
        segment.dy * distance_along_segment
    )
end

--- @brief
function rt.Path:get_segment(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.from_x, segment.from_y, segment.to_x, segment.to_y
end

--- @brief
function rt.Path:tangent_at(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.dx, segment.dy
end

--- @brief return normal at parameter t [0, 1]; normal is precomputed per segment and depends on path winding
function rt.Path:get_normal_at(t)
    local segment = self:_find_segment(math.clamp(t, 0, 1))
    return segment.nx, segment.ny
end

--- @brief
function rt.Path:_create_from(reparameterize_as_uniform, use_arclength, points, ...)
    if meta.is_number(points) then
        points = { points, ... }
    end

    if points == nil or #points < 2 then
        points = { 0, 0, 0, 0 }
    elseif #points < 4 then
        table.insert(points, points[1])
        table.insert(points, points[2])
    end

    local n_points = #points
    rt.assert(n_points % 2 == 0, "In rt.Path: number of point coordinates must be even")

    -- reparameterize to uniform spacing if requested
    if reparameterize_as_uniform then
        local num_points = n_points / 2

        -- calculate cumulative distances
        local distances = { 0 }
        local total_length = 0
        for i = 1, n_points - 2, 2 do
            local dist = math.distance(points[i], points[i+1], points[i+2], points[i+3])
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

                local point_idx = segment_idx * 2 - 1
                local x1, y1 = points[point_idx], points[point_idx + 1]
                local x2, y2 = points[point_idx + 2], points[point_idx + 3]

                local out_idx = i * 2 + 1
                uniform_points[out_idx], uniform_points[out_idx + 1] = math.mix2(x1, y1, x2, y2, local_t)
            end

            -- last point
            local last_idx = (num_points - 1) * 2 + 1
            uniform_points[last_idx] = points[n_points - 1]
            uniform_points[last_idx + 1] = points[n_points]

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

--- @brief
function rt.Path:create_from(...)
    return self:_create_from(
        false, -- resample with uniform spacing
        false, -- arc-length parameterize
        ...
    )
end

--- @brief
function rt.Path:create_from_and_reparameterize(...)
    return self:_create_from(
        false,
        true,
        ...
    )
end

--- @brief
function rt.Path:create_from_and_resample(...)
    return self:_create_from(
        true,
        true,
        ...
    )
end

--- @brief
function rt.Path:get_points()
    local out = {}
    for i = 1, self._n_points, 2 do
        table.insert(out, {self._points[i], self._points[i+1]})
    end
    return out
end

--- @brief
function rt.Path:get_length()
    return self._length
end

--- @brief override arclength parameterization with custom per-segment fraction
--- @param, . Number of values equal to number of segments, must sum to 1
function rt.Path:override_parameterization(...)
    local n_args = select("#", ...)
    if n_args ~= self._n_entries then
        rt.error("In rt.Path.override_parameterization: expected `",  self._n_entries,  "` parameters, got `",  n_args,  "`")
        return
    end

    local total = 0
    local args = {...}

    -- validate arguments sum to 1
    for i = 1, n_args do
        local arg = args[i]
        if type(arg) ~= "number" or arg < 0 then
            rt.error("In rt.Path:override_parameterization: parameter ",  i,  " must be a non-negative number")
            return
        end
        total = total + arg
    end

    if math.abs(total - 1) > 1e-10 then
        rt.error("In rt.Path:override_parameterization: total length of override parameters is `",  total,  "`, but `1` was expected")
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
function rt.Path:get_segment_count()
    return self._n_entries
end

--- @brief helper function to find closest point on a specific line segment
--- @param x Number query point x
--- @param y Number query point y
--- @param entry Table segment entry from self._entries
--- @return Number, Number, Number closest point x, y and global parameter t
function rt.Path:_closest_point_on_segment(x, y, entry)
    local x1, y1 = entry.from_x, entry.from_y
    local x2, y2 = entry.to_x, entry.to_y

    -- vector from start to end of segment
    local segment_dx = x2 - x1
    local segment_dy = y2 - y1
    local segment_length_sq = segment_dx * segment_dx + segment_dy * segment_dy

    if segment_length_sq < 1e-10 then
        -- degenerate segment
        local global_t = entry.fraction + entry.fraction_length * 0.5
        return x1, y1, global_t
    end

    local dot = (x - x1) * segment_dx + (y - y1) * segment_dy
    local local_t = math.clamp(dot / segment_length_sq, 0, 1)

    local closest_x = x1 + local_t * segment_dx
    local closest_y = y1 + local_t * segment_dy
    local global_t = entry.fraction + entry.fraction_length * local_t

    return closest_x, closest_y, global_t
end

--- @brief
function rt.Path:get_closest_point(x, y)
    if self._n_entries == 0 then
        return nil, nil, nil
    end

    local closest_distance_sq = math.huge
    local closest_x, closest_y = nil, nil
    local closest_t = 0

    for i = 1, self._n_entries do
        local entry = self._entries[i]
        local segment_x, segment_y, segment_t = self:_closest_point_on_segment(x, y, entry)

        local dx = segment_x - x
        local dy = segment_y - y
        local distance_sq = dx * dx + dy * dy

        if distance_sq < closest_distance_sq then
            closest_distance_sq = distance_sq
            closest_x = segment_x
            closest_y = segment_y
            closest_t = segment_t
        end
    end

    return closest_x, closest_y, closest_t
end

--- perpendicular distance from point to line segment
local function _perpendicular_distance(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local mag_sq = math.dot(dx, dy, dx, dy)

    if mag_sq < math.eps then
        -- degenerate line segment, return distance to point
        return math.distance(px, py, x1, y1)
    end

    -- project point onto line and calculate perpendicular distance
    -- using the cross product formula: distance = |cross(v1, v2)| / |v2|
    local vx = px - x1
    local vy = py - y1

    -- cross product in 2D: vx * dy - vy * dx
    local cross = math.abs(vx * dy - vy * dx)
    local mag = math.sqrt(mag_sq)

    return cross / mag
end

--- @brief recursive RDP helper
--- @param points Table flat array of coordinates
--- @param start_idx Number starting index (1-based, points to x coordinate)
--- @param end_idx Number ending index (1-based, points to x coordinate)
--- @param epsilon Number distance threshold
--- @param keep Table boolean array marking which points to keep
function rt.Path:_rdp_recursive(points, start_idx, end_idx, epsilon, keep)
    if end_idx - start_idx <= 2 then
        -- only two points, keep both
        return
    end

    local x1, y1 = points[start_idx], points[start_idx + 1]
    local x2, y2 = points[end_idx], points[end_idx + 1]

    local max_distance = 0
    local max_idx = 0

    -- find point with maximum perpendicular distance
    for i = start_idx + 2, end_idx - 2, 2 do
        local px, py = points[i], points[i + 1]
        local distance = _perpendicular_distance(px, py, x1, y1, x2, y2)

        if distance > max_distance then
            max_distance = distance
            max_idx = i
        end
    end

    -- if max distance exceeds epsilon, keep that point and recurse
    if max_distance > epsilon then
        keep[max_idx] = true
        self:_rdp_recursive(points, start_idx, max_idx, epsilon, keep)
        self:_rdp_recursive(points, max_idx, end_idx, epsilon, keep)
    end
end

--- @brief decimate path using Ramer-Douglas-Peucker algorithm
--- @param epsilon Number maximum perpendicular distance threshold
function rt.Path:decimate(epsilon)
    meta.assert(epsilon, "Number")

    if self._n_points < 4 then
        return self
    end

    local points = self._points
    local n_points = self._n_points
    local n_entries = self._n_entries

    -- mark which points to keep
    local keep = {}

    -- always keep start and end
    keep[1] = true
    keep[n_points - 1] = true

    self:_rdp_recursive(points, 1, n_points - 1, epsilon, keep)

    -- build new points array and compute merged fraction lengths
    local new_points = {}
    local new_fractions = {}
    local point_to_segment = {} -- map point index to segment index

    -- build mapping from point indices to segment indices
    for i = 1, n_entries do
        local seg_start_idx = (i - 1) * 2 + 1
        point_to_segment[seg_start_idx] = i
    end

    local current_fraction_sum = 0
    local last_kept_segment = 0

    for i = 1, n_points - 1, 2 do
        if keep[i] then
            table.insert(new_points, points[i])
            table.insert(new_points, points[i + 1])

            -- accumulate fractions from segments that were merged
            local segment_idx = point_to_segment[i]
            if segment_idx then
                -- add all fractions from last kept segment to current
                for j = last_kept_segment + 1, segment_idx do
                    if j <= n_entries then
                        current_fraction_sum = current_fraction_sum + self._entries[j].fraction_length
                    end
                end

                table.insert(new_fractions, current_fraction_sum)
                current_fraction_sum = 0
                last_kept_segment = segment_idx
            end
        end
    end

    -- add remaining fractions for the last segment
    for j = last_kept_segment + 1, n_entries do
        current_fraction_sum = current_fraction_sum + self._entries[j].fraction_length
    end
    if current_fraction_sum > 0 then
        table.insert(new_fractions, current_fraction_sum)
    end

    -- preserve parameterization type
    local use_arclength = self._use_arclength
    local reparameterize = false

    self:_create_from(reparameterize, use_arclength, new_points)

    -- if we have custom fractions, apply them to the new path
    if #new_fractions > 0 and #new_fractions == self._n_entries then
        self:override_parameterization(table.unpack(new_fractions))
    end

    return self
end

--- @brief
function rt.Path:get_points()
    return self._points
end