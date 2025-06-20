require "common.contour"
local slick = require "dependencies.slick.slick"

rt.settings.overworld.blood_splatter = {
    sensor_radius = 5
}

-- @class ow.Mirror
ow.Mirror = meta.class("Mirror")

--- @brief
function ow.Mirror:instantiate(scene)
    meta.install(self, {
        _scene = scene,
        _edges = {},
        _world = nil
    })
end

--- @brief
function ow.Mirror:draw()
    love.graphics.setLineWidth(2)

    love.graphics.setColor(1, 1, 1, 1)

    for edge in values(self._edges) do
        local data = edge:getUserData()
        --love.graphics.line(table.unpack(data))
    end


    if self._visible ~= nil then
        for segment in values(self._visible) do
            love.graphics.line(segment)
        end
    end
end


local _round = function(x)
    return math.floor(x)
end

local _hash_to_segment = {}

local _hash = function(points)
    local x1, y1, x2, y2 = _round(points[1]), _round(points[2]), _round(points[3]), _round(points[4])
    if x1 < x2 or (x1 == x2 and y1 < y2) then -- swap so point order does not matter
        x1, y1, x2, y2 = x2, y2, x1, y1
    end
    local hash = tostring(x1) .. "," .. tostring(y1) .. "," .. tostring(x2) .. "," .. tostring(y2)
    _hash_to_segment[hash] = points
    return hash
end

local _unhash = function(hash)
    return table.unpack(_hash_to_segment[hash])
end

local function _area(tri)
    local x1, y1, x2, y2, x3, y3 = table.unpack(tri)
    return math.abs((x1 * (y2 - y3) + x2 * (y3 - y1) + x3 * (y1 - y2)) / 2)
end

--- @brief
function ow.Mirror:create_contour()
    _hash_to_segment = {}
    local tris = ow.Hitbox:get_slippery_tris()

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

    self._world = love.physics.newWorld(0, 0)
    self._edges = {}
    self._segments = {}
    self._edge_body = love.physics.newBody(self._world, 0, 0, b2.BodyType.STATIC)

    for hash, count in pairs(tuples) do
        if count == 1 then
            local x1, y1, x2, y2 = _unhash(hash)
            local edge = love.physics.newEdgeShape(self._edge_body, x1, y1, x2, y2)
            local segment = { x1, y1, x2, y2 }
            edge:setUserData(segment)

            table.insert(self._edges, edge)
            table.insert(self._segments, segment)
        end
    end
end

local eps = 1

function _get_visible_subsegments(segments, px, py)
    local visible_segments = {}

    -- Helper function to check if two line segments intersect and return intersection point
    local function segments_intersect_with_point(seg1, seg2)
        local x1, y1, x2, y2 = seg1[1], seg1[2], seg1[3], seg1[4]
        local x3, y3, x4, y4 = seg2[1], seg2[2], seg2[3], seg2[4]

        local denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        if math.abs(denom) < eps then
            return false, nil, nil -- Lines are parallel
        end

        local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom

        if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
            local ix = x1 + t * (x2 - x1)
            local iy = y1 + t * (y2 - y1)
            return true, ix, iy
        end

        return false, nil, nil
    end

    -- Helper function to get distance between two points
    local function distance(x1, y1, x2, y2)
        return math.sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))
    end

    -- Helper function to check if point is on line segment
    local function point_on_segment(px, py, seg)
        local x1, y1, x2, y2 = seg[1], seg[2], seg[3], seg[4]

        -- Check if point is collinear with segment
        local cross_product = (py - y1) * (x2 - x1) - (px - x1) * (y2 - y1)
        if math.abs(cross_product) > eps then
            return false
        end

        -- Check if point is within segment bounds
        local dot_product = (px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)
        local squared_length = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)

        return dot_product >= 0 and dot_product <= squared_length
    end

    -- Helper function to parametrize a point on a segment (0 = start, 1 = end)
    local function parametrize_point_on_segment(px, py, seg)
        local x1, y1, x2, y2 = seg[1], seg[2], seg[3], seg[4]
        local dx, dy = x2 - x1, y2 - y1
        local length_squared = dx * dx + dy * dy

        if length_squared == 0 then
            return 0
        end

        return ((px - x1) * dx + (py - y1) * dy) / length_squared
    end

    -- Helper function to get point at parameter t on segment
    local function point_at_parameter(seg, t)
        local x1, y1, x2, y2 = seg[1], seg[2], seg[3], seg[4]
        return x1 + t * (x2 - x1), y1 + t * (y2 - y1)
    end

    -- Process each segment to find visible subsegments
    for i, current_segment in ipairs(segments) do
        local x1, y1, x2, y2 = current_segment[1], current_segment[2], current_segment[3], current_segment[4]

        -- Collect all intersection points along this segment from blocking segments
        local intersections = {}

        -- Add segment endpoints
        table.insert(intersections, {t = 0, x = x1, y = y1, is_endpoint = true})
        table.insert(intersections, {t = 1, x = x2, y = y2, is_endpoint = true})

        -- Find intersections with rays from observer to segment points
        for j, blocking_segment in ipairs(segments) do
            if i ~= j then
                -- Check intersection with ray to start point
                local ray_to_start = {px, py, x1, y1}
                local intersects, ix, iy = segments_intersect_with_point(ray_to_start, blocking_segment)
                if intersects then
                    local dist_to_intersection = distance(px, py, ix, iy)
                    local dist_to_segment_start = distance(px, py, x1, y1)

                    -- Only consider if blocking segment is closer
                    if dist_to_intersection < dist_to_segment_start then
                        if point_on_segment(ix, iy, current_segment) then
                            local t = parametrize_point_on_segment(ix, iy, current_segment)
                            table.insert(intersections, {t = t, x = ix, y = iy, is_blocking = true})
                        end
                    end
                end

                -- Check intersection with ray to end point
                local ray_to_end = {px, py, x2, y2}
                intersects, ix, iy = segments_intersect_with_point(ray_to_end, blocking_segment)
                if intersects then
                    local dist_to_intersection = distance(px, py, ix, iy)
                    local dist_to_segment_end = distance(px, py, x2, y2)

                    -- Only consider if blocking segment is closer
                    if dist_to_intersection < dist_to_segment_end then
                        if point_on_segment(ix, iy, current_segment) then
                            local t = parametrize_point_on_segment(ix, iy, current_segment)
                            table.insert(intersections, {t = t, x = ix, y = iy, is_blocking = true})
                        end
                    end
                end

                -- Also check if the blocking segment itself intersects the current segment
                intersects, ix, iy = segments_intersect_with_point(current_segment, blocking_segment)
                if intersects then
                    local t = parametrize_point_on_segment(ix, iy, current_segment)
                    table.insert(intersections, {t = t, x = ix, y = iy, is_intersection = true})
                end
            end
        end

        -- Sort intersections by parameter t
        table.sort(intersections, function(a, b) return a.t < b.t end)

        -- Remove duplicates (points very close to each other)
        local filtered_intersections = {}
        for k, intersection in ipairs(intersections) do
            local is_duplicate = false
            for l, existing in ipairs(filtered_intersections) do
                if math.abs(intersection.t - existing.t) < 1e-6 then
                    is_duplicate = true
                    break
                end
            end
            if not is_duplicate then
                table.insert(filtered_intersections, intersection)
            end
        end

        -- Create subsegments between consecutive intersection points
        for k = 1, #filtered_intersections - 1 do
            local start_point = filtered_intersections[k]
            local end_point = filtered_intersections[k + 1]

            -- Get midpoint of this subsegment to test visibility
            local mid_t = (start_point.t + end_point.t) / 2
            local mid_x, mid_y = point_at_parameter(current_segment, mid_t)

            -- Check if this subsegment is visible
            local is_visible = true
            local ray_to_mid = {px, py, mid_x, mid_y}
            local dist_to_mid = distance(px, py, mid_x, mid_y)

            for j, blocking_segment in ipairs(segments) do
                if i ~= j then
                    local intersects, ix, iy = segments_intersect_with_point(ray_to_mid, blocking_segment)
                    if intersects then
                        local dist_to_intersection = distance(px, py, ix, iy)
                        if dist_to_intersection < dist_to_mid - 1e-6 then -- Small epsilon for floating point comparison
                            is_visible = false
                            break
                        end
                    end
                end
            end

            -- If visible, add this subsegment
            if is_visible and distance(start_point.x, start_point.y, end_point.x, end_point.y) > 1e-6 then
                table.insert(visible_segments, {start_point.x, start_point.y, end_point.x, end_point.y})
            end
        end
    end

    return visible_segments
end

--- @brief
function ow.Mirror:update(delta)
    local x, y, w, h = self._scene:get_camera():get_world_bounds()

    local segments = {}

    self._world:update(delta)
    self._world:queryShapesInArea(x, y, x + w, y + h, function(shape)
        table.insert(segments, shape:getUserData())
        return true
    end)

    local px, py = self._scene:get_player():get_position()
    self._visible = _get_visible_subsegments(segments, px, py)
end

--- @brief
function ow.Mirror:destroy()
    self._world:destroy()
end