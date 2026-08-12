--- @class ow.VisiblityQuery
ow.VisibilityQuery = meta.class("VisibilityQuery")

--- @enum ow.ContourType
ow.ContourType = {
    REFLECTIVE = true,
    NON_REFLECTIVE = false
}
ow.ContourType = meta.enum("ContourType", ow.ContourType)

local function _dedupe(list, eps)
    local result = {}
    for i = 1, #list do
        local value = list[i]
        local last = result[#result]

        if last == nil or math.abs(value - last) > eps then
            table.insert(result, value)
        else
            result[#result] = (value + last) / 2
        end
    end

    return result
end

--- @brief
function ow.VisibilityQuery:initialize(non_reflective_contours, reflective_contours)
    if reflective_contours == nil then reflective_contours = {} end
    if non_reflective_contours == nil then non_reflective_contours = {} end
    meta.assert(non_reflective_contours, mt.Table, reflective_contours, mt.Table)

    self._world = love.physics.newWorld(0, 0, false)
    self._body = love.physics.newBody(self._world, 0, 0, b2.BodyType.STATIC)
    self._shapes = {}

    self._cache_hash = nil
    self._cache = nil

    local metatable = {
        __index = function(self, key)
            rt.error("In ow.VisibilityQuery: trying to access property `", key, "` of a segment, but it does not exist")
        end
    }

    -- collect segments from contours
    local raw_segments = {}
    for contours_and_type in range(
        { reflective_contours, ow.ContourType.REFLECTIVE },
        { non_reflective_contours, ow.ContourType.NON_REFLECTIVE }
    ) do
        local contours, type = table.unpack(contours_and_type)
        for contour in values(contours) do
            for i = 1, #contour - 2, 2 do
                table.insert(raw_segments, {
                    segment = { contour[i+0], contour[i+1], contour[i+2], contour[i+3] },
                    contour = contour,
                    type = type,
                    splits = {} -- list of t values where this segment must be cut
                })
            end
        end
    end

    local function _segment_intersection(a, b)
        local ax1, ay1, ax2, ay2 = table.unpack(a)
        local bx1, by1, bx2, by2 = table.unpack(b)
        local d1x, d1y = ax2 - ax1, ay2 - ay1
        local d2x, d2y = bx2 - bx1, by2 - by1

        local denom = d1x * d2y - d1y * d2x
        if math.abs(denom) < 1e-12 then
            return nil
        end

        local dx, dy = bx1 - ax1, by1 - ay1
        local t = (dx * d2y - dy * d2x) / denom
        local u = (dx * d1y - dy * d1x) / denom

        local margin = 1 -- px
        local t_eps = margin / math.magnitude(d1x, d1y)
        local u_eps = margin / math.magnitude(d2x, d2y)

        if t_eps > 1 then t_eps = 0 end
        if u_eps > 1 then u_eps = 0 end

        if t > t_eps and t < 1 - t_eps and u > u_eps and u < 1 - u_eps then
            return t, u, ax1 + t * d1x, ay1 + t * d1y
        end

        return nil
    end

    -- check pairwise intersection
    for a_i = 1, #raw_segments do
        for b_i = 1, #raw_segments do
            if a_i ~= b_i then
                local a = raw_segments[a_i]
                local b = raw_segments[b_i]
                local t, u = _segment_intersection(a.segment, b.segment)

                if t ~= nil and u ~= nil then
                    table.insert(a.splits, t)
                    table.insert(b.splits, u)
                end
            end
        end
    end

    -- remove duplicate / close together split points
    local t_eps = 1e-4
    for entry in values(raw_segments) do
        table.sort(entry.splits)
        entry.splits = _dedupe(entry.splits, t_eps)
    end

    -- compute final split segments
    local final_segments = {}
    for raw in values(raw_segments) do
        if #raw.splits == 0 then
            local segment = raw.segment
            table.insert(final_segments, {
                segment = { table.unpack(segment) },
                contour = raw.contour,
                type = raw.type
            })
        else
            local raw_x1, raw_y1, raw_x2, raw_y2 = table.unpack(raw.segment)
            local dx, dy = raw_x2 - raw_x1, raw_y2 - raw_y1

            local previous_x, previous_y = raw_x1, raw_y1
            local last_t = nil

            for _, t in ipairs(raw.splits) do
                local px, py = raw_x1 + t * dx, raw_y1 + t * dy
                table.insert(final_segments, {
                    segment = { previous_x, previous_y, px, py },
                    contour = raw.contour,
                    type = raw.type
                })

                previous_x, previous_y = px, py
                last_t = t
            end

            if 1 - last_t > t_eps then
                table.insert(final_segments, {
                    segment = { previous_x, previous_y, raw_x2, raw_y2 },
                    contour = raw.contour,
                    type = raw.type
                })
            end
        end
    end

    -- export as physics shapes
    local userdatas = {}
    for _, final in ipairs(final_segments) do
        local shape = love.physics.newEdgeShape(self._body, table.unpack(final.segment))
        local userdata = setmetatable({
            shape = shape,
            segment = final.segment,
            contour = final.contour,
            type = final.type
        }, metatable)

        shape:setUserData(userdata)
        table.insert(self._shapes, shape)
        table.insert(userdatas, userdata)
    end

    return userdatas
end

--- @brief
function ow.VisibilityQuery:get_segments()
    local result = {}
    for _, shape in ipairs(self._shapes) do
        table.insert(result, shape:getUserData())
    end

    return result
end

--- @brief
function ow.VisibilityQuery:get_segments_in_area(aabb)
    meta.assert(aabb, rt.AABB)

    local shapes = self._world:getShapesInArea(
        aabb.x,
        aabb.y,
        aabb.x + aabb.width,
        aabb.y + aabb.height
    )

    local result = {}
    for _, shape in ipairs(shapes) do
        table.insert(result, shape:getUserData())
    end

    return result
end

do
    local function _ray_line_intersect(clamp_to_segment, x, y, dir_x, dir_y, ax, ay, bx, by)
        local dx = bx - ax
        local dy = by - ay
        local det = dir_x * dy - dir_y * dx

        local eps = 1e-5

        -- ray is parallel to the segment
        if math.abs(det) < eps then
            if clamp_to_segment then
                -- line segment: no intersection
                return nil
            else
                -- infinite line: fallback to nearest end point
                local dist_a = (ax - x)^2 + (ay - y)^2
                local dist_b = (bx - x)^2 + (by - y)^2
                if dist_a < dist_b then
                    return ax, ay
                else
                    return bx, by
                end
            end
        end

        local oax = ax - x
        local oay = ay - y
        local distance = (oax * dy - oay * dx) / det
        local hit_x = x + dir_x * distance
        local hit_y = y + dir_y * distance

        if not clamp_to_segment then
            return hit_x, hit_y
        end

        if distance < 0 then
            -- ray starts behind line segment
            return nil
        end

        local u = (dir_y * oax - dir_x * oay) / det
        if u < 0 - eps or u > 1 + eps then
            -- intersection outside of segment
            return nil
        end

        return distance, hit_x, hit_y
    end

    local function _angle_in_range(a, mn, mx)
        if mn <= mx then
            return a >= mn and a <= mx
        else
            return a >= mn or a <= mx
        end
    end

    local _HALF_PI = math.pi / 2
    local _TAU = 2 * math.pi

    --- @brief get all subsegments that are visible from a point
    function ow.VisibilityQuery:get_visible_subsegments(x, y, bounds, compute_polygon)
        if compute_polygon == nil then compute_polygon = false end
        meta.assert(x, mt.Number, y, mt.Number, bounds, rt.AABB, compute_polygon, mt.Boolean)

        -- caching
        local to_hash = {}
        for h in range(
            x, y,
            bounds.x, bounds.y,
            bounds.width, bounds.height,
            ternary(compute_polygon, 0, 1)
        ) do
            table.insert(to_hash, math.floor(h))
        end

        local hash = table.concat(to_hash, "_")
        if self._cache_hash == hash then
            return self._cache.subsegments, self._cache.tris
        end

        self._dbg = {}
        local edges = {}
        for i, shape in ipairs(self._world:getShapesInArea(
            bounds.x, bounds.y,
            bounds.x + bounds.width,
            bounds.y + bounds.height
        )) do
            table.insert(edges, shape:getUserData())
        end

        -- insert dummy edges for visibility polygon tris
        local edge_to_is_bound = {}
        if compute_polygon then
            do
                local bx, by, bw, bh = bounds.x, bounds.y, bounds.width, bounds.height
                local top = { segment = { bx, by, bx + bw, by } }
                local right = { segment = { bx + bw, by, bx + bw, by + bh } }
                local bottom = { segment = { bx + bw, by + bh, bx, by + bh } }
                local left = { segment = { bx, by + bh, bx, by } }

                for edge in range(top, right, bottom, left) do
                    edge_to_is_bound[edge] = true
                end

                table.insert(edges, top)
                table.insert(edges, right)
                table.insert(edges, bottom)
                table.insert(edges, left)
            end
        end

        local angles = table.new(#edges * 2, 0)
        local edge_angle_ranges = table.new(#edges * 2, 0)

        local angle_eps = -math.huge
        local angle_set = {}

        for edge_i, data in ipairs(edges) do
            local ax, ay, bx, by = table.unpack(data.segment)
            local dxa, dya = math.subtract(ax, ay, x, y)
            local dxb, dyb = math.subtract(bx, by, x, y)
            local a_angle = math.normalize_angle(math.angle(dxa, dya))
            local b_angle = math.normalize_angle(math.angle(dxb, dyb))

            angle_set[a_angle] = true
            angle_set[b_angle] = true

            local min_angle, max_angle
            if a_angle < b_angle then
                min_angle, max_angle = a_angle, b_angle
            else
                min_angle, max_angle = b_angle, a_angle
            end

            if max_angle - min_angle > math.pi then
                min_angle, max_angle = max_angle, min_angle
            end

            local idx = 2 * edge_i - 1
            edge_angle_ranges[idx] = min_angle
            edge_angle_ranges[idx + 1] = max_angle

            angle_eps = math.max(
                angle_eps,
                math.magnitude(dxa, dya),
                math.magnitude(dxb, dyb)
            )
        end

        for angle in keys(angle_set) do
            table.insert(angles, angle)
        end

        table.sort(angles)

        angle_eps = 0.25 / angle_eps
        for i = 1, #angles do
            angles[i] = math.floor(angles[i] / angle_eps + 0.5) * angle_eps
        end

        -- dedupe angles
        do
            local i = #angles
            while i > 1 do
                local a, b = angles[i], angles[i - 1]
                if math.abs(a - b) < angle_eps then
                    table.remove(angles, i)
                end
                i = i - 1
            end
        end

        local subsegments = {}
        local tris = {}

        local current_edge = nil
        local current_start_x, current_start_y = nil, nil
        local current_end_x, current_end_y = nil, nil

        local function push_current()
            if current_edge ~= nil
                and (not compute_polygon or edge_to_is_bound[current_edge] ~= true)
                and current_start_x ~= nil
            then
                if math.distance(current_start_x, current_start_y, current_end_x, current_end_y) > 1 then
                    table.insert(subsegments, {
                        edge = current_edge,
                        subsegment = { current_start_x, current_start_y, current_end_x, current_end_y }
                    })
                end
            end
            current_edge = nil
        end

        local trig_cache = table.new(0, 6 * #angles)
        local cos = function(angle)
            local value = trig_cache[angle]
            if value == nil then
                value = math.cos(angle)
                trig_cache[angle] = value
            end
            return value
        end

        local sin = function(angle)
            return cos((angle - _HALF_PI) % _TAU)
        end

        if #angles > 0 then
            for i = 1, #angles do
                local angle1 = angles[i]
                local angle2 = angles[i % #angles + 1]

                local diff = angle2 - angle1
                if diff <= 0 then
                    diff = diff + (2 * math.pi)
                end

                -- bisect angle sector
                local mid_angle = math.normalize_angle(angle1 + (diff / 2))

                -- find closest segment to each critical point
                local min_distance = math.huge
                local min_edge = nil
                for edge_i, edge in ipairs(edges) do
                    local idx = 2 * edge_i - 1
                    local min_angle = edge_angle_ranges[idx + 0]
                    local max_angle = edge_angle_ranges[idx + 1]

                    if _angle_in_range(mid_angle, min_angle, max_angle) then
                        local distance = _ray_line_intersect(
                            true,
                            x, y,
                            cos(mid_angle), sin(mid_angle),
                            table.unpack(edge.segment)
                        )

                        if distance ~= nil and distance < min_distance then
                            min_distance = distance
                            min_edge = edge
                        end
                    end
                end

                if min_edge ~= nil then
                    local hit1_x, hit1_y = _ray_line_intersect(
                        false, x, y,
                        cos(angle1), sin(angle1),
                        table.unpack(min_edge.segment)
                    )

                    local hit2_x, hit2_y = _ray_line_intersect(
                        false,
                        x, y,
                        cos(angle2), sin(angle2),
                        table.unpack(min_edge.segment)
                    )

                    if hit1_x and hit2_x then
                        if compute_polygon then
                            table.insert(tris, { x, y, hit1_x, hit1_y, hit2_x, hit2_y })
                        end

                        if min_edge ~= current_edge then
                            -- segment changed: push subsegment, start new
                            push_current()
                            current_edge = min_edge
                            current_start_x, current_start_y = hit1_x, hit1_y
                            current_end_x, current_end_y = hit2_x, hit2_y
                        else
                            -- extend subsegment
                            current_end_x, current_end_y = hit2_x, hit2_y
                        end
                    end
                else
                    -- end of regular segment, push subsegment
                    push_current()
                end
            end

            -- push final unfinished segment
            push_current()
        end

        -- merge subsegment going across sweep start / end
        if #subsegments > 1 and subsegments[1].edge == subsegments[#subsegments].edge then
            local first = table.remove(subsegments, 1)
            local last = subsegments[#subsegments]
            last.subsegment[3] = first.subsegment[3]
            last.subsegment[4] = first.subsegment[4]
        end

        self._cache = {
            subsegments = subsegments,
            tris = tris
        }
        self._cache_hash = hash

        return subsegments, tris
    end
end