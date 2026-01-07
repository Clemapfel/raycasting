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
        _offset_y = 0,
        _impulse = rt.ImpulseSubscriber()
    })
end

function ow.BloodSplatter:set_bloom_factor(f)
    self._bloom_factor = f
end

-- get part of segment that overlaps circle
local function _clip_segment_in_circle(x1, y1, x2, y2, cx, cy, radius)
    local px1, py1 = x1 - cx, y1 - cy
    local px2, py2 = x2 - cx, y2 - cy

    local distnace_1 = math.distance(0, 0, px1, py1)
    local distance_2 = math.distance(0, 0, px2, py2)

    local p1_inside = distnace_1 <= radius
    local p2_inside = distance_2 <= radius

    if p1_inside and p2_inside then
        return x1, y1, x2, y2
    end

    local dx, dy = px2 - px1, py2 - py1
    local segment_length = math.magnitude(dx, dy)

    -- early exit: closest point on segment is farther away than radius
    if not p1_inside and not p2_inside then
        local ndx, ndy = dx / segment_length, dy / segment_length
        local t = math.clamp(-math.dot(px1, py1, ndx, ndy), 0, segment_length)
        local closest_x, closest_y = px1 + t * ndx, py1 + t * ndy
        if math.dot(closest_x, closest_y, closest_x, closest_y) > radius * radius then
            return nil
        end
    end

    if segment_length == 0 then -- point segment
        if p1_inside then
            return x1, y1, x2, y2
        else
            return nil
        end
    end

    local ndx, ndy = math.normalize(dx, dy)

    -- ray-circle intersection using quadratic formula
    -- ray: p = px1 + t * (ndx, ndy), t in [0, seg_length]
    -- circle: x^2 + y^2 = radius^2
    -- substituting: (px1 + t*ndx)^2 + (py1 + t*ndy)^2 = radius^2

    local a = 1.0 -- ndx^2 + ndy^2 = 1 (normalized)
    local b = 2 * (px1 * ndx + py1 * ndy)
    local c = px1 * px1 + py1 * py1 - radius * radius

    local discriminant = b * b - 4 * a * c
    if discriminant < 0 then -- no intersection
        return nil
    end

    local t1 = (-b - math.sqrt(discriminant)) / (2 * a)
    local t2 = (-b + math.sqrt(discriminant)) / (2 * a)

    local t_min = math.max(0, t1)
    local t_max = math.min(segment_length, t2)

    if t_min > t_max then -- no overlap
        return nil
    end

    local ix1, iy1 = px1 + t_min * ndx, py1 + t_min * ndy
    local ix2, iy2 = px1 + t_max * ndx, py1 + t_max * ndy

    return ix1 + cx, iy1 + cy, ix2 + cx, iy2 + cy
end

--- @brief
function ow.BloodSplatter:add(x, y, radius, color_r, color_g, color_b, opacity, allow_override)
    if opacity == nil then opacity = 1 end
    if allow_override == nil then allow_override = true end

    local r = radius
    local was_added = false
    x = x - self._offset_x
    y = y - self._offset_y

    for shape in values(self._world:getShapesInArea(x - r, y - r, x + r, y + r)) do
        local data = shape:getUserData()
        if data == nil then goto continue end

        -- check for line-circle overlap
        local x1, y1, x2, y2 = table.unpack(data.line)
        local ix1, iy1, ix2, iy2 = _clip_segment_in_circle(
            x1, y1, x2, y2,
            x, y, r
        )

        if ix1 == nil then goto continue end

        -- get left and right bounds as fraction in [0, 1]
        local distance_1 = math.distance(ix1, iy1, x1, y1)
        local distance_2 = math.distance(ix2, iy2, x1, y1)

        if distance_2 < distance_1 then
            distance_2 = math.distance(ix1, iy1, x2, y2)
            distance_1 = math.distance(ix2, iy2, x2, y2)
        end

        local length = math.distance(x1, y1, x2, y2)

        if length < math.eps then goto continue end

        local left_fraction = distance_1 / length
        local right_fraction = distance_2 / length

        -- swap, segment has wrong winding
        if left_fraction > right_fraction then
            x1, y1, x2, y2 = x2, y2, x1, y1
            left_fraction, right_fraction = right_fraction, left_fraction
            distance_1, distance_2 = distance_2, distance_1
        end

        -- color all subdivsions in this interval
        local color = rt.RGBA(color_r, color_g, color_b, opacity)
        local hue = select(1, rt.rgba_to_hsva(color_r, color_g, color_b, opacity))
        for division in values(data.subdivisions) do
            -- if not already colored
            if not (allow_override == false and self._active_divisions[division] == true) then

                -- check interval overlap
                local left_f, right_f = division.left_fraction, division.right_fraction
                if (left_f >= left_fraction and left_f <= right_fraction)
                    or (right_f >= left_fraction and right_f <= right_fraction)
                then
                    division.color = color
                    division.hue = hue
                    if not division.is_active then
                        self._active_divisions[division] = true
                        division.is_active = true
                    end

                    was_added = true
                end
            end
        end

        ::continue::
    end

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

    for shape in values(self._world:getShapesInArea(x, y, x + w, y + h)) do
        visible[shape] = true
    end

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)

    local t = self._bloom_factor -- experimentally determined to compensate best
    local brightness_offset = math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._impulse:get_pulse())
    for division in keys(self._active_divisions) do
        if visible[division.shape] == true then
            local r, g, b, a = division.color:unpack()
            love.graphics.setColor(
                (r - t) * brightness_offset,
                (g - t) * brightness_offset,
                (b - t) * brightness_offset,
                a
            )
            love.graphics.line(division.line)
        end
    end

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
function ow.BloodSplatter:create_contour(tris, occluding_tris)
    _hash_to_segment = {}
    local hash_to_is_valid = {}

    local segments = {}
    for tris_and_is_valid in range(
        { tris, true },
        { occluding_tris, false }
    ) do
        local to_iterate, is_valid = table.unpack(tris_and_is_valid)
        for tri in values(to_iterate) do
            for segment in range(
                {tri[1], tri[2], tri[3], tri[4]},
                {tri[3], tri[4], tri[5], tri[6]},
                {tri[1], tri[2], tri[5], tri[6]}
            ) do
                table.insert(segments, segment)
                local hash = _hash(segment)
                hash_to_is_valid[hash] = is_valid
            end
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
        if count == 1 and hash_to_is_valid[hash] == true then
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
function ow.BloodSplatter:get_segment_light_sources(bounds)
    meta.assert(bounds, rt.AABB)
    local segments, colors = {}, {}

    local n = 0

    for shape in values(self._world:getShapesInArea(
        bounds.x - self._offset_x,
        bounds.y - self._offset_y,
        bounds.x + bounds.width,
        bounds.y + bounds.height
    )) do
        local edge = shape:getUserData()
        local before = nil
        for current in values(edge.subdivisions) do
            if self._active_divisions[current] == true then
                local inserted = false
                if before ~= nil and before.right_fraction == current.left_fraction
                    and math.abs(before.hue - current.hue) < 0.01
                then
                    -- extend last colinear segment
                    segments[n][3] = current.line[3]
                    segments[n][4] = current.line[4]
                    inserted = true
                else
                    table.insert(segments, current.line)
                    table.insert(colors, current.color)
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
    end

    return segments, colors
end

--- @brief
function ow.BloodSplatter:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end

--- @brief
function ow.BloodSplatter:get_offset()
    return self._offset_x, self._offset_y
end