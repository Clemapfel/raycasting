rt.settings.overworld.blood_splatter = {
    sensor_radius = 5
}

-- @class ow.BloodSplatter
ow.BloodSplatter = meta.class("BloodSplatter")

--- @brief
function ow.BloodSplatter:instantiate()
    meta.install(self, {
        _edges = {},
        _active_divisions = {}
    })
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
    local r = 0.5
    self._world:queryShapesInArea(x - r, y - r, x + r, y + r, function(shape)
        local data = shape:getUserData()
        if data ~= nil then
            local x1, y1, x2, y2 = table.unpack(data.line)
            local cx, cy = x, y
            local ix1, iy1, ix2, iy2 = _overlap(x1, y1, x2, y2, cx, cy, radius)

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
                    if not division.is_active then
                        self._active_divisions[division] = true
                        division.is_active = true
                    end
                end
            end
        end

        return true
    end)
end

--- @brief
function ow.BloodSplatter:draw()
    love.graphics.setLineWidth(2)

    for division in keys(self._active_divisions) do
        love.graphics.setColor(table.unpack(division.color))
        love.graphics.line(division.line)
    end

    rt.graphics.set_blend_mode(nil)
end

local _round = function(x)
    return math.floor(x)
end

local _hash = function(points)
    local x1, y1, x2, y2 = _round(points[1]), _round(points[2]), _round(points[3]), _round(points[4])
    if x1 < x2 or (x1 == x2 and y1 < y2) then -- swap so point order does not matter
        x1, y1, x2, y2 = x2, y2, x1, y1
    end
    return tostring(x1) .. "," .. tostring(y1) .. "," .. tostring(x2) .. "," .. tostring(y2)
end

local _unhash = function(hash)
    return hash:match("([^,]+),([^,]+),([^,]+),([^,]+)")
end

--- @brief
function ow.BloodSplatter:create_contour()
    local tris = ow.Hitbox:get_all_tris()
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
                        line = {sx1, sy1, sx2, sy2},
                        left_fraction = left_fration,
                        right_fraction = right_fraction,
                        is_active = false,
                        color = nil
                    })
                end
            else
                table.insert(subdivisions, {
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
        end
    end
end

--- @brief
function ow.BloodSplatter:destroy()
    self._world:destroy()
end