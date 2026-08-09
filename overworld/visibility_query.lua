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


--- @brief
function ow.VisibilityQuery:draw()
    rt.Palette.GREEN:bind()

    if true then return end

    if self._cache ~= nil then
        for _, entry in ipairs(self._cache) do
            love.graphics.line(entry.segment)
        end

        love.graphics.circle("fill", table.unpack(self._cursor))

        love.graphics.setLineWidth(0.5)
        local x, y = rt.SceneManager:get_current_scene():get_camera():screen_xy_to_world_xy(love.mouse.getPosition())
        for i = 1, #self._todo, 2 do
            love.graphics.line(x, y, self._todo[i], self._todo[i+1])
        end
    end
end

-- refactored: single contiguous array for angle ranges

function ow.VisibilityQuery:get_visible_subsegments(x, y, bounds)
    meta.assert(x, mt.Number, y, mt.Number, bounds, rt.AABB)

    local before = love.timer.getTime()

    x, y = rt.SceneManager:get_current_scene():get_camera():screen_xy_to_world_xy(love.mouse.getPosition())

    self._cursor = { x, y, 10 }

    -- caching
    local frame_i = rt.SceneManager:get_frame_index()
    local to_hash = {}

    for h in range(frame_i, x, y, bounds.x, bounds.y, bounds.width, bounds.height) do
        table.insert(to_hash, math.floor(h))
    end

    local hash = table.concat(to_hash, "_")
    if self._cache_hash == hash then
        dbg(rt.SceneManager:get_frame_index(), 0)
        return self._cache
    end

    local edges = {}
    for i, shape in ipairs(self._world:getShapesInArea(
        bounds.x, bounds.y,
        bounds.x + bounds.width,
        bounds.y + bounds.height
    )) do
        table.insert(edges, shape:getUserData())
    end

    local from = true
    local to = false

    self._todo = {}
    if #edges == 0 then return {} end

    local angles = table.new(#edges, 0)
    local angle_to_is_from = table.new(0, #edges * 2)
    local angle_to_is_to = table.new(0, #edges * 2)
    local edge_angle_ranges = table.new(#edges * 2, 0) -- [ min, max, min, max, min ... ]

    local angle_eps = -math.huge -- store as max distance for now

    local angle_set = {}
    for edge_i, data in ipairs(edges) do
        local ax, ay, bx, by = table.unpack(data.segment)
        local dxa, dya = math.subtract(ax, ay, x, y)
        local dxb, dyb = math.subtract(bx, by, x, y)
        local a_angle = math.normalize_angle(math.angle(dxa, dya))
        local b_angle = math.normalize_angle(math.angle(dxb, dyb))

        angle_set[a_angle] = true
        angle_set[b_angle] = true

        angle_to_is_from[a_angle] = true
        angle_to_is_to[b_angle] = true

        local min_angle = math.min(a_angle, b_angle)
        local max_angle = math.max(a_angle, b_angle)
        if max_angle - min_angle > math.pi then
            min_angle, max_angle = max_angle, min_angle
        end

        -- store in contiguous array at positions 2*edge_i-1 and 2*edge_i
        local idx = 2 * edge_i - 1
        edge_angle_ranges[idx] = min_angle
        edge_angle_ranges[idx + 1] = max_angle

        angle_eps = math.max(
            angle_eps,
            math.magnitude(dxa, dya),
            math.magnitude(dxb, dyb)
        )

        table.insert(self._todo, ax)
        table.insert(self._todo, ay)
        table.insert(self._todo, bx)
        table.insert(self._todo, by)
    end

    for angle in keys(angle_set) do
        table.insert(angles, angle)
    end

    table.sort(angles)

    -- convert to radians
    angle_eps = 0.25 / angle_eps -- n / radius is n px displacement along circle in radians

    -- dedupe angles
    do
        local i = #angles
        while i > 1 do
            local a, b = angles[i], angles[i - 1]
            if math.abs(a - b) < angle_eps then
                table.remove(angles, i)
                table.remove(angles, i - 1)
                table.insert(angles, i - 1, a)
            end

            i = i - 1
        end
    end

    local function ray_segment_distance(x, y, dir_x, dir_y, ax, ay, bx, by)
        local dx = bx - ax
        local dy = by - ay
        local det = dir_x * dy - dir_y * dx
        if math.abs(det) < math.eps then
            return nil
        end

        local oax = ax - x
        local oay = ay - y
        local distance = (oax * dy - oay * dx) / det

        if distance >= 0 then
            local hit_x = x + dir_x * distance
            local hit_y = y + dir_y * distance

            local u = (dir_y * oax - dir_x * oay) / det
            if u < 0 or u > 1 then return nil end

            return distance, hit_x, hit_y
        end
        return nil
    end

    local subsegments = {}
    local current_edge = nil
    local current_start_x, current_start_y = nil, nil
    local current_end_x, current_end_y = nil, nil

    local function push_current()
        if current_start_x ~= nil then
            table.insert(subsegments, {
                edge = current_edge,
                segment = { current_start_x, current_start_y, current_end_x, current_end_y }
            })
        end
    end

    local function _angle_in_range(a, mn, mx)
        if mn <= mx then
            return a >= mn and a <= mx
        else
            return a >= mn or a <= mx
        end
    end

    local ran = 0
    local function check_edges(angle)
        local dir_x, dir_y = math.cos(angle), math.sin(angle)
        local min_distance = math.huge
        local min_edge = nil
        local min_point_x, min_point_y = nil, nil
        for edge_i, edge in ipairs(edges) do
            local idx = 2 * edge_i - 1
            local min_angle = edge_angle_ranges[idx + 0]
            local max_angle = edge_angle_ranges[idx + 1]

            -- reject if angle span of edge is out of range
            if _angle_in_range(angle, min_angle, max_angle) then
                local distance, hit_x, hit_y = ray_segment_distance(
                    x, y, dir_x, dir_y,
                    table.unpack(edge.segment)
                )

                ran = ran + 1

                if distance ~= nil and distance < min_distance then
                    min_distance = distance
                    min_edge = edge
                    min_point_x, min_point_y = hit_x, hit_y
                end
            end
        end

        if min_edge ~= nil then
            if min_edge ~= current_edge then
                push_current()
                current_edge = min_edge
                current_start_x, current_start_y = min_point_x, min_point_y
                current_end_x, current_end_y = min_point_x, min_point_y
            else
                current_end_x, current_end_y = min_point_x, min_point_y
            end
        end
    end

    for angle_i = 1, #angles do
        local angle = angles[angle_i]
        if angle_to_is_from[angle] then
            check_edges(angle - angle_eps)
        end

        if angle_to_is_to[angle] then
            check_edges(angle + angle_eps)
        end
    end

    push_current() -- push final segment

    -- merge subsegment going across sweep start / end
    if #subsegments > 1 and subsegments[1].edge == subsegments[#subsegments].edge then
        local first = table.remove(subsegments, 1)
        local last = subsegments[#subsegments]
        last.segment[3] = first.segment[3]
        last.segment[4] = first.segment[4]
    end

    self._cache = subsegments
    self._cache_hash = hash
    dbg(ran / (#edges)^2)
    return subsegments
end