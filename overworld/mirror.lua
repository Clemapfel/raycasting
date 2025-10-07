require "common.contour"
local slick = require "dependencies.slick.slick"

rt.settings.overworld.mirror = {
    distance_threshold = math.huge,
    player_attenuation_radius = 0.25, -- fraction of screen size
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
    for image in values(self._mirror_images) do love.graphics.line(image.segment) end
    --for segment in values(self._dbg) do love.graphics.line(segment) end
    love.graphics.circle("fill", self._px, self._py, 5)

    local stencil_value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)

    -- only draw where slippery is
    self._draw_mirror_mask_callback()

    if self._draw_occluding_mask_callback ~= nil then
        love.graphics.setStencilState("replace", "always", 0)
        love.graphics.setColorMask(false)

        -- exclude occluding
        self._draw_occluding_mask_callback()
    end

    love.graphics.pop()

    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

    -- draw canvases
    local canvas, scale_x, scale_y = self._scene:get_player_canvas()
    local canvas_w, canvas_h = canvas:get_size()

    local camera = self._scene:get_camera()
    local player = self._scene:get_player()

    local player_x, player_y = player:get_position()
    local player_position = { camera:world_xy_to_screen_xy(player_x, player_y) }
    local player_color = { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1) }

    local camera_x, camera_y = camera:get_offset()

    _shader:bind()
    _shader:send("player_color", player_color)
    _shader:send("player_position", player_position)
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("camera_offset", { camera_x, camera_y })
    _shader:send("camera_scale", camera:get_final_scale())

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

        love.graphics.circle("fill", image.x + self._offset_x, image.y + self._offset_y, 5)
    end
    _shader:unbind()

    rt.graphics.set_stencil_mode(nil)
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


--- Calculates all visible subsegments from a given point.
--- It determines which parts of the 'segments' are visible from (px, py),
--- considering that 'occluding_segments' can block the line of sight.
--- The y-axis is assumed to extend downwards.
---
--- @param segments Table<Tuple<Number, Number, Number, Number>> A list of segments to check for visibility.
--- @param px Number The x-coordinate of the viewpoint.
--- @param py Number The y-coordinate of the viewpoint.
--- @param occluding_segments Table<Tuple<Number, Number, Number, Number>> A list of segments that can block the view.
--- @return Table<Tuple<Number, Number, Number, Number>> A list of all visible subsegments.
function _get_visible_subsegments(segments, px, py, occluding_segments)
    -- If there are no occluders, all segments are fully visible.
    if not occluding_segments or #occluding_segments == 0 then
        return segments
    end

    local all_visible_subsegments = {}

    -- Iterate over each segment we want to find the visible parts of.
    for _, segment in ipairs(segments) do
        local x1, y1, x2, y2 = segment[1], segment[2], segment[3], segment[4]
        local target_dx, target_dy = x2 - x1, y2 - y1

        -- A segment is represented parametrically as S(t) = P1 + t * (P2 - P1) for t in [0, 1].
        -- We start by assuming the entire segment is visible, which corresponds to the interval [0, 1].
        -- This list can be fragmented into multiple smaller intervals by occluders.
        local visible_t_intervals = {{0, 1}}

        -- Now, for each occluder, we will "subtract" its shadow from our visible intervals.
        for _, occluder in ipairs(occluding_segments) do
            local ox1, oy1, ox2, oy2 = occluder[1], occluder[2], occluder[3], occluder[4]

            -- Find where the lines of sight from the viewpoint to the occluder's endpoints
            -- intersect the infinite line defined by the target segment.
            local ray1_dx, ray1_dy = ox1 - px, oy1 - py
            local t1, u1 = _get_line_intersection_params(x1, y1, target_dx, target_dy, px, py, ray1_dx, ray1_dy)

            local ray2_dx, ray2_dy = ox2 - px, oy2 - py
            local t2, u2 = _get_line_intersection_params(x1, y1, target_dx, target_dy, px, py, ray2_dx, ray2_dy)

            -- An intersection is valid only if it occurs 'in front' of the viewpoint (u > 0).
            -- An occlusion is only valid if the occluder is closer to the viewpoint than the target segment (u < 1).
            if t1 and t2 and (u1 and u1 > 1e-9 and u1 < 1) or (u2 and u2 > 1e-9 and u2 < 1) then
                local shadow_start_t = math.min(t1, t2)
                local shadow_end_t = math.max(t1, t2)

                -- If the shadow is completely outside the [0,1] range of the segment, ignore it.
                if shadow_end_t < 0 or shadow_start_t > 1 then
                    -- continue (to the next occluder)
                else
                    local next_visible_intervals = {}
                    -- Subtract the shadow interval from all current visible intervals.
                    for _, interval in ipairs(visible_t_intervals) do
                        local vis_start, vis_end = interval[1], interval[2]

                        -- Case 1: The part of the interval *before* the shadow.
                        local before_interval_end = math.min(vis_end, shadow_start_t)
                        if before_interval_end > vis_start + 1e-9 then
                            table.insert(next_visible_intervals, {vis_start, before_interval_end})
                        end

                        -- Case 2: The part of the interval *after* the shadow.
                        local after_interval_start = math.max(vis_start, shadow_end_t)
                        if after_interval_start < vis_end - 1e-9 then
                            table.insert(next_visible_intervals, {after_interval_start, vis_end})
                        end
                    end
                    visible_t_intervals = next_visible_intervals
                end
            end
        end

        -- Convert the final visible t-intervals back into world coordinate subsegments.
        for _, interval in ipairs(visible_t_intervals) do
            local t_start, t_end = interval[1], interval[2]

            -- Clamp the final intervals to the original segment's bounds [0, 1].
            t_start = math.max(0, t_start)
            t_end = math.min(1, t_end)

            -- If the resulting interval is valid, calculate the subsegment's endpoints.
            if t_start < t_end - 1e-9 then
                local sx = x1 + t_start * target_dx
                local sy = y1 + t_start * target_dy
                local ex = x1 + t_end * target_dx
                local ey = y1 + t_end * target_dy
                table.insert(all_visible_subsegments, {sx, sy, ex, ey})
            end
        end
    end

    return all_visible_subsegments
end

local function _reflect(px, py, angle, x1, y1, x2, y2)
    local dx, dy = math.subtract(x2, y2, x1, y1)

    local t = math.dot(px - x1, py - y1, dx, dy) / math.dot(dx, dy, dx, dy)
    if t < 0 or t > 1 then return nil end -- reject early

    local closest_x = x1 + t * dx
    local closest_y = y1 + t * dy

    local distance = math.distance(closest_x, closest_y, px, py)
    if distance > rt.settings.overworld.mirror.distance_threshold then return nil end

    local segment_length = math.magnitude(dx, dy)
    local ndx, ndy = math.normalize(dx, dy)
    local nx, ny = -ndy, ndx -- normal (right-hand, y-down)

    local vx, vy = px - closest_x, py - closest_y
    local distance_squared = math.dot(vx, vy, nx, ny)

    local rx = px - 2 * distance_squared * nx
    local ry = py - 2 * distance_squared * ny

    local line_angle = math.angle(dx, dy)
    local reflected_angle = 2 * line_angle - angle

    return rx, ry, reflected_angle, false, true, distance
end

--- @brief
function ow.Mirror:update(delta)
    local camera_x, camera_y, camera_w, camera_h = self._scene:get_camera():get_world_bounds():unpack()

    -- instead of checking all segments on screen, only check segments near player
    local fraction = rt.settings.overworld.mirror.player_attenuation_radius
    local px, py = self._scene:get_player():get_physics_body():get_position()

    local w, h = camera_w * fraction, camera_h * fraction
    local x = px - w / 2
    local y = py - h / 2

    x = x - self._offset_x
    y = y - self._offset_y

    self._dbg = {}
    self._px, self._py = px, py

    local mirror_segments = {}
    local occluding_segments = {}

    self._world:update(delta)
    self._world:queryShapesInArea(x, y, x + w, y + h, function(shape)
        local data = shape:getUserData()
        table.insert(self._dbg, data.segment)
        if data.is_mirror == true then
            table.insert(mirror_segments, data.segment)
        else
            table.insert(occluding_segments, data.segment)
        end

        return true
    end)

    self._visible = _get_visible_subsegments(
        mirror_segments,
        px - self._offset_x,
        py - self._offset_y,
        occluding_segments
    )

    self._mirror_images = {}
    for segment in values(self._visible) do
        local x1, y1, x2, y2 = table.unpack(segment)
        local rx, ry, angle, flip_x, flip_y, distance = _reflect(px - self._offset_x, py - self._offset_y, 0, x1, y1, x2, y2)
        if rx ~= nil then
            table.insert(self._mirror_images, {
                segment = segment,
                x = rx,
                y = ry,
                angle = angle,
                flip_x = flip_x,
                flip_y = flip_y
            })
        end
    end
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