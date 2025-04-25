rt.settings.overworld.blood_splatter = {
    sensor_radius = 5
}

-- @class ow.BloodSplatter
ow.BloodSplatter = meta.class("BloodSplatter")

--- @brief
function ow.BloodSplatter:instantiate()
    meta.install(self, {
        _to_draw = {}
    })
end

local _current_hue = 0

local sensor_body, sensor_shape

--- @brief
function ow.BloodSplatter:add(x, y, hue)
    _current_hue = hue

    --[[
    self._world:queryShapesInArea(x - 1, y - 1, x + 1, y + 1, function(shape)
        local data = shape:getUserData()
        if data ~= nil then
            data.color = { rt.lcha_to_rgba(rt.LCHA(0.8, 1, _current_hue, 1):unpack()) }
            self._active_edges[shape] = true
        end
        return true
    end)
    ]]--

    if sensor_body == nil then
        sensor_body = love.physics.newBody(self._world, x, y, b2.BodyType.KINEMATIC)
        sensor_shape = love.physics.newCircleShape(sensor_body, rt.settings.overworld.blood_splatter.sensor_radius)
        sensor_body:setBullet(true)
    else
        sensor_body:setPosition(x, y)
    end


    self._world:update(0)
end

--- @brief
function ow.BloodSplatter:draw()
    for edge in values(self._edges) do
        local data = edge:getUserData()
        love.graphics.setColor(table.unpack(data.color))
        love.graphics.line(data.line)
    end
end

local _hash = function(points)
    local x1, y1, x2, y2 = points[1], points[2], points[3], points[4]
    if x1 > x2 or (x1 == x2 and y1 > y2) then -- swap so point order does not matter
        x1, y1, x2, y2 = x2, y2, x1, y1
    end
    return tostring(x1) .. "," .. tostring(y1) .. "," .. tostring(x2) .. "," .. tostring(y2)
end

local _unhash = function(hash)
    return hash:match("([^,]+),([^,]+),([^,]+),([^,]+)")
end

--- @brief
function ow.BloodSplatter:create_contour(segments)
    -- get all tuples of connected points, then filter unique
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

    local max_length = 5
    for hash, count in pairs(tuples) do
        if count == 1 then
            local x1, y1, x2, y2 = _unhash(hash)
            local dx, dy = x2 - x1, y2 - y1
            local length = math.sqrt(dx * dx + dy * dy)

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

                    local edge = love.physics.newEdgeShape(self._edge_body, sx1, sy1, sx2, sy2)
                    edge:setUserData({
                        color = {0, 0, 0, 1},
                        line = {sx1, sy1, sx2, sy2}
                    })
                    table.insert(self._edges, edge)
                end
            else
                local edge = love.physics.newEdgeShape(self._edge_body, x1, y1, x2, y2)
                edge:setUserData({
                    color = {0, 0, 0, 1},
                    line = {x1, y1, x2, y2}
                })
                table.insert(self._edges, edge)
            end
        end
    end

    self._world:setCallbacks(function(shape_a, shape_b, contact)
        for shape in range(shape_a, shape_b) do
            local data = shape:getUserData()
            if data ~= nil then
                data.color = { rt.lcha_to_rgba(rt.LCHA(0.8, 1, _current_hue, 1):unpack()) }
                self._active_edges[shape] = true
            end
        end
    end)
end