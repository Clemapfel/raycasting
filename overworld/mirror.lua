require "common.contour"
local slick = require "dependencies.slick.slick"

rt.settings.overworld.mirror = {
    distance_threshold = math.huge,
    player_attenuation_radius = 0.25, -- fraction of screen size
    segment_detection_radius_factor = 3, -- time player radius
    max_n_mirror_segments = 8
}

--- @class ow.Mirror
ow.Mirror = meta.class("Mirror")

local _shader = rt.Shader("overworld/mirror.glsl")
local _noop = function() end

--- @brief
function ow.Mirror:instantiate(
    scene,
    draw_mirror_mask_callback,
    draw_occluding_mask_callback -- optional
)
    if draw_mirror_mask_callback == nil then draw_occluding_mask_callback = _noop end

    meta.assert(
        scene, "OverworldScene",
        draw_mirror_mask_callback, "Function"
    )

    meta.install(self, {
        _scene = scene,
        _draw_mirror_mask_callback = draw_mirror_mask_callback,
        _draw_occluding_mask_callback = draw_occluding_mask_callback,
        _edges = {},
        _world = nil,
        _offset_x = 0,
        _offset_y = 0
    })
end

--- @brief
function ow.Mirror:draw()
    local should_stencil = self._draw_mirror_mask_callback ~= nil

    -- stencil mirror areas
    if should_stencil then
        local stencil_value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)

        love.graphics.push()
        love.graphics.translate(self._offset_x, self._offset_y)

        self._draw_mirror_mask_callback()

        if self._draw_occluding_mask_callback ~= nil then
            love.graphics.setStencilState("replace", "always", 0)
            love.graphics.setColorMask(false)

            -- exclude occluding
            self._draw_occluding_mask_callback()
        end

        love.graphics.pop()

        rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)
    end

    -- draw canvases
    local canvas, scale_x, scale_y = self._scene:get_player_canvas()
    local canvas_w, canvas_h = canvas:get_size()

    local camera = self._scene:get_camera()
    local player = self._scene:get_player()
    local player_opacity = ternary(player:get_is_visible(), 1, 0)

    _shader:bind()
    _shader:send("player_color", { player:get_color():unpack() })
    _shader:send("player_position", { camera:world_xy_to_screen_xy(player:get_position()) })
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("camera_offset", { camera:get_offset() })
    _shader:send("camera_scale", camera:get_final_scale())

    local n_drawn = 0
    for image in values(self._mirror_images) do
        local flip_x, flip_y
        if image.flip_x == true then flip_x = -1 else flip_x = 1 end
        if image.flip_y == true then flip_y = -1 else flip_y = 1 end

        local x1, y1, x2, y2 = table.unpack(image.segment)
        x1 = x1 + self._offset_x
        y1 = y1 + self._offset_y
        x2 = x2 + self._offset_x
        y2 = y2 + self._offset_y

        local lx1, ly1 = camera:world_xy_to_screen_xy(x1, y1)
        local lx2, ly2 = camera:world_xy_to_screen_xy(x2, y2)

        _shader:send("axis_of_reflection", { lx1, ly1, lx2, ly2 })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            canvas:get_native(),
            image.x + self._offset_x, image.y + self._offset_y,
            image.angle,
            flip_x / scale_x,
            flip_y / scale_y,
            0.5 * canvas_w, 0.5 * canvas_h
        )

        n_drawn = n_drawn + 1
        if n_drawn >= rt.settings.overworld.mirror.max_n_mirror_segments then
            -- safety check for degenerate geometry
            -- segment priority is distance to player
            break
        end
    end
    _shader:unbind()

    if should_stencil then
        rt.graphics.set_stencil_mode(nil)
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
function ow.Mirror:create_contour(mirror_tris, occluding_tris)
    if occluding_tris == nil then occluding_tris = {} end
    meta.assert(mirror_tris, "Table", occluding_tris, "Table")

    local mirror_segments, occluding_segments = {}, {}

    for segments_tris in range(
        { mirror_segments, mirror_tris },
        { occluding_segments, occluding_tris }
    ) do
        _hash_to_segment = {}

        local segments, tris = table.unpack(segments_tris)
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

        for hash, count in pairs(tuples) do
            if count == 1 then
                table.insert(segments, { _unhash(hash) })
            end
        end
    end

    self._world = love.physics.newWorld(0, 0)
    self._edges = {}
    self._edge_body = love.physics.newBody(self._world, 0, 0, b2.BodyType.STATIC)

    for segment in values(mirror_segments) do
        local x1, y1, x2, y2 = table.unpack(segment)
        local edge = love.physics.newEdgeShape(self._edge_body, x1, y1, x2, y2)
        edge:setUserData({
            is_mirror = true,
            segment = segment
        })

        table.insert(self._edges, edge)
    end

    for segment in values(occluding_segments) do
        local x1, y1, x2, y2 = table.unpack(segment)
        local edge = love.physics.newEdgeShape(self._edge_body, x1, y1, x2, y2)
        edge:setUserData({
            is_mirror = false,
            segment = segment
        })

        table.insert(self._edges, edge)
    end
end

--- Calculates the intersection of two lines defined by a point and a direction vector.
--- It returns the parametric multipliers 't' and 'u' such that:
--- intersection_point = (x1, y1) + t * (dx1, dy1) = (x2, y2) + u * (dx2, dy2)
--- @param x1 Number Starting x of the first line.
--- @param y1 Number Starting y of the first line.
--- @param dx1 Number X-direction of the first line.
--- @param dy1 Number Y-direction of the first line.
--- @param x2 Number Starting x of the second line.
--- @param y2 Number Starting y of the second line.
--- @param dx2 Number X-direction of the second line.
--- @param dy2 Number Y-direction of the second line.
--- @return Number or nil The parameter 't' for the first line.
--- @return Number or nil The parameter 'u' for the second line.
local function _get_line_intersection_params(x1, y1, dx1, dy1, x2, y2, dx2, dy2)
    -- The denominator is the 2D cross-product of the direction vectors.
    -- If it's zero, the lines are parallel or collinear.
    local denominator = dx1 * dy2 - dy1 * dx2
    if math.abs(denominator) < 1e-9 then
        return nil, nil
    end

    -- Using Cramer's rule to solve the system of linear equations for t and u
    local t = ((x2 - x1) * dy2 - (y2 - y1) * dx2) / denominator
    local u = ((x2 - x1) * dy1 - (y2 - y1) * dx1) / denominator
    return t, u
end

-- get all visible subsegments of `segments`, any segment in `segments` or `occluding_segments` can occlude
local function _get_visible_subsegments(segments, px, py, occluding_segments)
    local eps = 10e-4
    local _ray_segment_intersection = function(px, py, dx, dy, x1, y1, x2, y2)
        local sx = x2 - x1
        local sy = y2 - y1

        local denom = dx * sy - dy * sx
        if math.abs(denom) < eps then return nil end

        local t = ((x1 - px) * sy - (y1 - py) * sx) / denom
        local u = ((x1 - px) * dy - (y1 - py) * dx) / denom

        if t >= 0 and u >= 0 and u <= 1 then
            return px + t * dx, py + t * dy
        end

        return nil
    end

    local angle_quantization = 1 / 0.0001

    -- collect critical angles
    local critical_points = {}
    local add_point = function(segment, is_mirror)
        local x1, y1, x2, y2 = table.unpack(segment)

        local true_angle_a = math.angle(x1 - px, y1 - py)
        local true_angle_b = math.angle(x2 - px, y2 - py)

        local angle_a = math.floor(true_angle_a * angle_quantization) / angle_quantization
        local angle_b = math.floor(true_angle_b * angle_quantization) / angle_quantization

        table.insert(critical_points, {
            angle = math.normalize_angle(angle_a),
            segment = segment,
            is_mirror = is_mirror
        })

        table.insert(critical_points, {
            angle = math.normalize_angle(angle_b),
            segment = segment,
            is_mirror = is_mirror
        })
    end

    -- candidate for subsegments, also occlude
    for segment in values(segments) do add_point(segment, true) end

    -- only occlude
    for segment in values(occluding_segments) do add_point(segment, false) end

    table.sort(critical_points, function(a, b)
        return a.angle < b.angle
    end)

    local subsegments_to_intervals = {}
    local n_critical_points = #critical_points
    if n_critical_points == 0 then return {} end

    for i = 1, n_critical_points do
        local entry_a = critical_points[math.wrap(i+0, n_critical_points)]
        local entry_b = critical_points[math.wrap(i+1, n_critical_points)]

        local angle_a, angle_b = entry_a.angle, entry_b.angle

        local bisector_angle
        if i == n_critical_points then
            bisector_angle = math.mix(angle_a, angle_b + 2 * math.pi, 0.5)
        else
            bisector_angle = math.mix(angle_a, angle_b, 0.5)
        end

        local dx, dy = math.cos(bisector_angle), math.sin(bisector_angle)

        -- get closest segment
        local min_distance, min_entry = math.huge
        for entry in values(critical_points) do
            local cx, cy = _ray_segment_intersection(px, py, dx, dy, table.unpack(entry.segment))
            if cx ~= nil and cy ~= nil then
                local distance = math.distance(px, py, cx, cy)
                if distance <= min_distance then
                    min_distance = distance
                    min_entry = entry
                end
            end
        end

        -- for this segment, cast ray to find intersection points, these are start and end of subsegment
        if min_entry ~= nil and min_entry.is_mirror then
            local segment = min_entry.segment

            local ray_angle_a = angle_a
            local ray_angle_b = angle_b

            local cx1, cy1 = _ray_segment_intersection(
                px, py, math.cos(ray_angle_a), math.sin(ray_angle_a), table.unpack(segment)
            )

            if cx1 == nil or cy1 == nil then
                goto continue
            end

            local cx2, cy2 = _ray_segment_intersection(
                px, py, math.cos(ray_angle_b), math.sin(ray_angle_b), table.unpack(segment)
            )

            if cx2 == nil or cy2 == nil then
                goto continue
            end

            local intervals = subsegments_to_intervals[segment]
            if intervals == nil then
                intervals = {}
                subsegments_to_intervals[segment] = intervals
            end

            -- convert to normalized parameter for later merging
            local segment_length = math.distance(table.unpack(segment))
            if segment_length > 0 and cx1 ~= cx2 or cy1 ~= cy2 then
                local t1 = math.distance(segment[1], segment[2], cx1, cy1) / segment_length
                local t2 = math.distance(segment[1], segment[2], cx2, cy2) / segment_length
                table.insert(intervals, {
                    math.min(t1, t2), math.max(t1, t2)
                })
            end
        end

        ::continue::
    end

    local result = {}
    for segment, intervals in pairs(subsegments_to_intervals) do
        -- merge overlaps
        if #intervals > 1 then
            table.sort(intervals, function(a, b)
                return a[1] < b[1]
            end)

            ::retry::
            for i = 1, #intervals - 1 do
                local a1, a2 = table.unpack(intervals[i+0])
                local b1, b2 = table.unpack(intervals[i+1])

                if a2 >= b1 then
                    local merged = { a1, math.max(a2, b2) }
                    intervals[i] = merged
                    table.remove(intervals, i + 1)
                    goto retry
                end
            end
        end

        -- convert to line segments
        local start_x, start_y = segment[1], segment[2]
        local dx, dy = segment[3] - segment[1], segment[4] - segment[2]
        for ts in values(intervals) do
            local x1, y1 = start_x + dx * ts[1], start_y + dy * ts[1]
            local x2, y2 = start_x + dx * ts[2], start_y + dy * ts[2]
            table.insert(result, { x1, y1, x2, y2 })
        end
    end

    return result
end

-- flip across line defined by line segment
local function _reflect(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local ux, uy = math.normalize(dx, dy)
    local normal_x, normal_y = math.turn_left(ux, uy)

    local to_point_x, to_point_y = px - x1, py - y1

    local projection = math.dot(to_point_x, to_point_y, normal_x, normal_y)

    local reflected_x = px - 2 * projection * normal_x
    local reflected_y = py - 2 * projection * normal_y

    local flip_x = math.abs(math.dot(ux, uy, 1, 0)) < math.abs(math.dot(ux, uy, 0, 1))
    local flip_y = not flip_x

    local distance = math.abs(projection)

    return reflected_x, reflected_y, flip_x, flip_y, distance
end

--- @brief
function ow.Mirror:update(delta)
    local camera_x, camera_y, camera_w, camera_h = self._scene:get_camera():get_world_bounds():unpack()

    -- find segments near player
    local px, py = self._scene:get_player():get_physics_body():get_position()

    local x = px - self._offset_x
    local y = py - self._offset_y
    local r = rt.settings.overworld.mirror.segment_detection_radius_factor * rt.settings.player.radius

    self._px, self._py = px, py

    local mirror_segments = {}
    local occluding_segments = {}

    local shapes = self._world:getShapesInArea(x - r, y - r, x + r, y + r)
    for shape in values(shapes) do
        local data = shape:getUserData()
        if data.is_mirror == true then
            table.insert(mirror_segments, data.segment)
        else
            table.insert(occluding_segments, data.segment)
        end
    end

    self._visible = _get_visible_subsegments(
        mirror_segments,
        px - self._offset_x,
        py - self._offset_y,
        occluding_segments
    )

    self._mirror_images = {}
    for segment in values(self._visible) do
        local rx, ry, flip_x, flip_y, distance = _reflect(px - self._offset_x, py - self._offset_y, table.unpack(segment))
        table.insert(self._mirror_images, {
            segment = segment,
            x = rx,
            y = ry,
            flip_x = flip_x,
            flip_y = flip_y,
            distance = distance
        })
    end

    table.sort(self._mirror_images, function(a, b)
        return a.distance < b.distance
    end)
end

--- @brief
function ow.Mirror:destroy()
    self._world:destroy()
end

--- @brief
function ow.Mirror:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end

--- @brief
function ow.Mirror:get_offset()
    return self._offset_x, self._offset_y
end