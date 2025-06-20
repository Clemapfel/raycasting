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

local eps = 1 / 1

-- Check if two points are approximately equal
local function pointsEqual(x1, y1, x2, y2)
    local epsilon = eps
    return math.abs(x1 - x2) < epsilon and math.abs(y1 - y2) < epsilon
end

-- Calculate the cross product of vectors (x1,y1) and (x2,y2)
-- Note: This works the same regardless of y-axis direction because it's relative
local function cross(x1, y1, x2, y2)
    return x1 * y2 - x2 * y1
end

-- Check if point (x,y) is on segment (x1,y1)-(x2,y2)
-- Modified to handle downward y-axis (y increases downward)
local function isPointOnSegment(x, y, x1, y1, x2, y2)
    if math.abs(cross(x2 - x1, y2 - y1, x - x1, y - y1)) > eps then
        return false
    end

    -- For downward y-axis, y1 might be greater than y2
    local minX = math.min(x1, x2)
    local maxX = math.max(x1, x2)
    local minY = math.min(y1, y2)
    local maxY = math.max(y1, y2)

    return x >= minX - eps and x <= maxX + eps and
        y >= minY - eps and y <= maxY + eps
end

-- Check if two segments intersect (including endpoints)
local function segmentsIntersect(seg1, seg2)
    local x1, y1, x2, y2 = seg1[1], seg1[2], seg1[3], seg1[4]
    local x3, y3, x4, y4 = seg2[1], seg2[2], seg2[3], seg2[4]

    -- Check if any endpoints are shared
    if pointsEqual(x1, y1, x3, y3) or pointsEqual(x1, y1, x4, y4) or
        pointsEqual(x2, y2, x3, y3) or pointsEqual(x2, y2, x4, y4) then
        return false
    end

    local a1 = y2 - y1
    local b1 = x1 - x2
    local c1 = x2*y1 - x1*y2

    local a2 = y4 - y3
    local b2 = x3 - x4
    local c2 = x4*y3 - x3*y4

    local denom = a1*b2 - a2*b1

    if math.abs(denom) < eps then
        -- Lines are parallel or coincident
        return false
    end

    local x = (b1*c2 - b2*c1) / denom
    local y = (a2*c1 - a1*c2) / denom

    -- Check if intersection point is on both segments
    return isPointOnSegment(x, y, x1, y1, x2, y2) and
        isPointOnSegment(x, y, x3, y3, x4, y4)
end

-- Check if segment is visible from point (px, py)
-- Modified to handle downward y-axis
local function isSegmentVisible(seg, px, py, segments)
    local x1, y1, x2, y2 = seg[1], seg[2], seg[3], seg[4]

    -- Create a test segment from the point to the midpoint of the target segment
    local midX = (x1 + x2) / 2
    local midY = (y1 + y2) / 2
    local testSeg = {px, py, midX, midY}

    -- Check if this test segment intersects any other segment
    for _, otherSeg in ipairs(segments) do
        if otherSeg ~= seg and segmentsIntersect(testSeg, otherSeg) then
            return false
        end
    end

    return true
end

-- Main function to find all visible segments from point (px, py)
function findVisibleSegments(segments, px, py)
    local visible = {}

    for _, seg in ipairs(segments) do
        if isSegmentVisible(seg, px, py, segments) then
            table.insert(visible, seg)
        end
    end

    return visible
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
    local a = love.timer.getTime()
    self._visible = findVisibleSegments(segments, px, py)
    dbg((love.timer.getTime() - a) / (1 / 60))
end

--- @brief
function ow.Mirror:destroy()
    self._world:destroy()
end