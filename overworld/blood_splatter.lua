require "common.contour"

rt.settings.overworld.blood_splatter = {
    sensor_radius = 5
}

-- @class ow.BloodSplatter
ow.BloodSplatter = meta.class("BloodSplatter")

--- @brief
function ow.BloodSplatter:instantiate(scene)
    meta.install(self, {
        _scene = scene,
        _edges = {},
        _active_divisions = {},
        _world = nil,
        _bloom_factor = 0,
        _offset_x = 0,
        _offset_y = 0
    })
end

function ow.BloodSplatter:set_bloom_factor(f)
    self._bloom_factor = f
end

function _overlap(x1, y1, x2, y2, cx, cy, radius)
    -- overlap of segment xy and segment c - radius, c + radius
    -- with c - radius, c + radius clamped to only lie on xy
    local dx, dy = math.normalize(x1 - x2, y1 - y2)

    local dx_up, dy_up = dx * radius, dy * radius
    local up_distance = math.distance(cx, cy, x1, y1)
    if math.magnitude(dx_up, dy_up) > up_distance then
        dx_up = dx * up_distance
        dy_up = dy * up_distance
    end

    local dx_down, dy_down = dx * radius, dy * radius
    local down_distance = math.distance(cx, cy, x2, y2)
    if math.magnitude(dx_down, dy_down) > down_distance then
        dx_down = dx * down_distance
        dy_down = dy * down_distance
    end

    local ix1, iy1 = cx + dx_up, cy + dy_up
    local ix2, iy2 = cx - dx_down, cy - dy_down

    return ix1, iy1, ix2, iy2
end

--- @brief
function ow.BloodSplatter:add(x, y, radius, hue)
    local r = radius
    local was_added = false
    x = x - self._offset_x
    y = y - self._offset_y

    self._world:queryShapesInArea(x - r, y - r, x + r, y + r, function(shape)
        local data = shape:getUserData()
        if data ~= nil then
            local x1, y1, x2, y2 = table.unpack(data.line)
            local cx, cy = x, y
            local ix1, iy1, ix2, iy2 = _overlap(x1, y1, x2, y2, cx, cy, r)

            -- get left and right bounds as fraction in [0, 1]
            local distance_1 = math.distance(ix1, iy1, x1, y1)
            local distance_2 = math.distance(ix2, iy2, x1, y1)

            if distance_2 < distance_1 then
                distance_2 = math.distance(ix1, iy1, x2, y2)
                distance_1 = math.distance(ix2, iy2, x2, y2)
            end

            local length = math.distance(x1, y1, x2, y2)
            local left_fraction = distance_1 / length
            local right_fraction = distance_2 / length
            assert(left_fraction <= right_fraction)

            local color = { rt.lcha_to_rgba(rt.LCHA(0.9, 1, hue, 1):unpack()) }

            for division in values(data.subdivisions) do
                -- check if segment overlaps interval
                local left_f, right_f = division.left_fraction, division.right_fraction
                if (left_f >= left_fraction and left_f <= right_fraction) or (right_f >= left_fraction and right_f <= right_fraction) then
                    division.color = color
                    division.hue = hue
                    if not division.is_active then
                        self._active_divisions[division] = true
                        division.is_active = true
                    end

                    was_added = true
                    return false -- only use first result
                end
            end
        end

        return true
    end)

    return was_added
end

--- @brief
function ow.BloodSplatter:draw()
    love.graphics.setLineWidth(3.5)

    local x, y, w, h = self._scene:get_camera():get_world_bounds():unpack()
    x = x - self._offset_x
    y = y - self._offset_y
    local visible = {}
    self._world:update(0)
    self._world:queryShapesInArea(x, y, x + w, y + h, function(shape)
        visible[shape] = true
        return true
    end)

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)

    local t = self._bloom_factor -- experimentally determined to compensate best
    for division in keys(self._active_divisions) do
        if visible[division.shape] == true then
            local r, g, b, a = table.unpack(division.color)
            love.graphics.setColor(
                r - t,
                g - t,
                b - t,
                a
            )
            love.graphics.line(division.line)
        end
    end

    --[[
    if self._dbg then
        love.graphics.setColor(1, 1, 1, 1)
        for edge in values(self._edges) do
            love.graphics.line(edge:getUserData().line)
        end
    end
    ]]--

    love.graphics.pop()
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

--- @brief
function ow.BloodSplatter:create_contour(tris)
    _hash_to_segment = {}

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
    self._active_edges = {}

    self._edge_body = love.physics.newBody(self._world, 0, 0, b2.BodyType.STATIC)

    local max_length = rt.settings.player.radius / 2
    for hash, count in pairs(tuples) do
        if count == 1 then
            local x1, y1, x2, y2 = _unhash(hash)
            local dx, dy = x2 - x1, y2 - y1
            local length = math.sqrt(dx * dx + dy * dy)

            local edge = love.physics.newEdgeShape(self._edge_body, x1, y1, x2, y2)
            local subdivisions = {}

            if length > max_length then
                local num_segments = math.ceil(length / max_length)
                local segment_length = length / num_segments
                local segment_dx = dx / num_segments
                local segment_dy = dy / num_segments

                for i = 0, num_segments - 1 do
                    local sx1 = x1 + i * segment_dx
                    local sy1 = y1 + i * segment_dy
                    local sx2 = x1 + (i + 1) * segment_dx
                    local sy2 = y1 + (i + 1) * segment_dy

                    -- precompute left and right fraction for overlap test
                    local left_fration = math.distance(sx1, sy1, x1, y1)
                    local right_fraction = math.distance(sx2, sy2, x1, y1)

                    if right_fraction < left_fration then
                        right_fraction = math.distance(sx1, sy1, x2, y2)
                        left_fration = math.distance(sx2, sy2, x2, y2)
                    end

                    left_fration = left_fration / length
                    right_fraction = right_fraction / length

                    table.insert(subdivisions, {
                        shape = edge,
                        line = {sx1, sy1, sx2, sy2},
                        left_fraction = left_fration,
                        right_fraction = right_fraction,
                        is_active = false,
                        hue = nil,
                        color = nil
                    })
                end
            else
                table.insert(subdivisions, {
                    shape = edge,
                    line = {x1, y1, x2, y2},
                    left_fraction = 0,
                    right_fraction = 1,
                    is_active = false,
                    color = nil
                })
            end

            edge:setUserData({
                line = {x1, y1, x2, y2},
                subdivisions = subdivisions
            })

            table.insert(self._edges, edge)
        end
    end
end

--- @brief
function ow.BloodSplatter:destroy()
    self._world:destroy()
end

--- @brief
function ow.BloodSplatter:get_visible_segments(bounds)
    meta.assert(bounds, rt.AABB)
    local segments, colors, n = {}, {}, 0

    --[[
    for subdivision in keys(self._active_divisions) do
        if bounds:intersects(table.unpack(subdivision.line)) then
            table.insert(segments, table.deepcopy(subdivision.line))
            table.insert(colors, table.deepcopy(subdivision.color))
            n = n + 1
        end
    end
    ]]--

    self._world:queryShapesInArea(bounds.x - self._offset_x, bounds.y - self._offset_y, bounds.x + bounds.width, bounds.y + bounds.height, function(shape)
        local edge = shape:getUserData()

        local before = nil
        for current in values(edge.subdivisions) do
            if self._active_divisions[current] == true then
                local inserted = false
                if before ~= nil and before.right_fraction == current.left_fraction and math.abs(before.hue - current.hue) < 0.05 then
                    -- extend last colinear segment
                    segments[n][3] = current.line[3]
                    segments[n][4] = current.line[4]
                    inserted = true
                else
                    table.insert(segments, table.deepcopy(current.line))
                    table.insert(colors, table.deepcopy(current.color))
                    n = n + 1
                    inserted = true
                end

                if inserted then
                    before = current
                end
            else
                before = nil
            end
        end

        return true
    end)

    return segments, colors, n
end

--- @brief
function ow.BloodSplatter:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end

--- @brief
function ow.BloodSplatter:get_offset()
    return self._offset_x, self._offset_y
end