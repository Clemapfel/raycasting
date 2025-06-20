rt.settings.overworld.blood_splatter = {
    sensor_radius = 5
}

-- @class ow.Mirror
ow.Mirror = meta.class("Mirror")

--- @brief
function ow.Mirror:instantiate()
    meta.install(self, {
        _edges = {},
        _world = nil
    })
end

--- @brief
function ow.Mirror:draw()
    love.graphics.setLineWidth(2)

    for edge in values(self._edges) do
        local data = edge:getUserData()
        love.graphics.line(table.unpack(data))
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
function ow.Mirror:destroy()
    self._world:destroy()
end