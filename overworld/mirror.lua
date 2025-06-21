require "common.contour"
local slick = require "dependencies.slick.slick"

rt.settings.overworld.mirror = {
    distance_threshold = math.huge
}

-- @class ow.Mirror
ow.Mirror = meta.class("Mirror")

local _shader

--- @brief
function ow.Mirror:instantiate(scene)
    meta.install(self, {
        _scene = scene,
        _edges = {},
        _world = nil
    })

    if _shader == nil then _shader = rt.Shader("overworld/mirror.glsl") end
    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "p" then
            _shader:recompile()
        end
    end)
end

--- @brief
function ow.Mirror:draw()
    if self._visible ~= nil then
        love.graphics.setLineWidth(2)
        love.graphics.setColor(1, 1, 1, 1)
        for segment in values(self._visible) do
            --love.graphics.line(segment)
        end
    end

    local stencil_value = 253
    love.graphics.setStencilState("replace", "always", stencil_value)
    love.graphics.setColorMask(false)

    -- only draw where slippery is
    ow.Hitbox:draw_mask(false)

    love.graphics.setStencilState("replace", "always", 0)
    love.graphics.setColorMask(false)

    -- exclude sticky
    ow.Hitbox:draw_mask(true)

    love.graphics.setStencilState("keep", "equal", stencil_value)
    love.graphics.setColorMask(true)

    -- draw canvases
    local canvas, scale_x, scale_y = self._scene:get_player_canvas()
    local canvas_w, canvas_h = canvas:get_size()

    local camera = self._scene:get_camera()

    local player = self._scene:get_player()
    local player_position = { self._scene:get_camera():world_xy_to_screen_xy(player:get_position()) }
    local player_color = { rt.lcha_to_rgba(0.8, 1, player:get_hue(), 1) }

    _shader:bind()
    _shader:send("player_color", player_color)
    _shader:send("player_position", player_position)
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    _shader:send("camera_offset", { camera:get_offset() })
    _shader:send("camera_scale", camera:get_final_scale())

    for image in values(self._mirror_images) do
        local flip_x, flip_y
        if image.flip_x == true then flip_x = -1 else flip_x = 1 end
        if image.flip_y == true then flip_y = -1 else flip_y = 1 end

        local lx1, ly1 = camera:world_xy_to_screen_xy(image.segment[1], image.segment[2])
        local lx2, ly2 = camera:world_xy_to_screen_xy(image.segment[3], image.segment[4])

        _shader:send("axis_of_reflection", { lx1, ly1, lx2, ly2 })
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            canvas:get_native(),
            image.x, image.y, image.angle,
            flip_x / scale_x,
            flip_y / scale_y,
            0.5 * canvas_w, 0.5 * canvas_h
        )
    end
    _shader:unbind()

    love.graphics.setStencilMode(nil)
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
    local mirror_segments, occluding_segments = {}, {}

    for segments_tris in range(
        { mirror_segments, ow.Hitbox:get_slippery_tris() },
        { occluding_segments, ow.Hitbox:get_sticky_tris() }
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

local eps = 1

-- Returns all visible subsegments of non-occluding segments, even if partially occluded by occluding segments.
function _get_visible_subsegments(segments, px, py, occluding_segments)
    local visible_segments = {}

    -- Helper: intersection between two segments, returns (bool, ix, iy, t1, t2)
    local function segments_intersect_with_point(seg1, seg2)
        local x1, y1, x2, y2 = seg1[1], seg1[2], seg1[3], seg1[4]
        local x3, y3, x4, y4 = seg2[1], seg2[2], seg2[3], seg2[4]
        local denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        if math.abs(denom) < 1e-8 then return false end
        local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
        if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
            local ix = x1 + t * (x2 - x1)
            local iy = y1 + t * (y2 - y1)
            return true, ix, iy, t, u
        end
        return false
    end

    -- Helper: distance
    local function distance(x1, y1, x2, y2)
        return math.sqrt((x2 - x1)^2 + (y2 - y1)^2)
    end

    -- Helper: point at t on segment
    local function point_at_parameter(seg, t)
        local x1, y1, x2, y2 = seg[1], seg[2], seg[3], seg[4]
        return x1 + t * (x2 - x1), y1 + t * (y2 - y1)
    end

    -- For each segment, split it at all intersections with other segments and occluders
    for i, seg in ipairs(segments) do
        local split_points = { {t=0}, {t=1} }

        -- Intersections with other segments (not itself)
        for j, other in ipairs(segments) do
            if i ~= j then
                local ok, _, _, t, _ = segments_intersect_with_point(seg, other)
                if ok and t > 1e-8 and t < 1-1e-8 then
                    table.insert(split_points, {t=t})
                end
            end
        end
        -- Intersections with occluding segments
        if occluding_segments then
            for _, occ in ipairs(occluding_segments) do
                local ok, _, _, t, _ = segments_intersect_with_point(seg, occ)
                if ok and t > 1e-8 and t < 1-1e-8 then
                    table.insert(split_points, {t=t})
                end
            end
        end

        -- Sort split points by t
        table.sort(split_points, function(a, b) return a.t < b.t end)

        -- For each subsegment, check if visible (not occluded)
        for k = 1, #split_points-1 do
            local t1 = split_points[k].t
            local t2 = split_points[k+1].t
            if t2 - t1 > 1e-8 then
                local x1, y1 = point_at_parameter(seg, t1)
                local x2, y2 = point_at_parameter(seg, t2)
                -- Test midpoint for visibility
                local mx, my = (x1 + x2)/2, (y1 + y2)/2
                local ray = {px, py, mx, my}
                local dist_to_mid = distance(px, py, mx, my)
                local blocked = false
                -- Check occlusion by any segment (except itself)
                for j, other in ipairs(segments) do
                    if i ~= j then
                        local ok, ix, iy = segments_intersect_with_point(ray, other)
                        if ok and distance(px, py, ix, iy) < dist_to_mid - 1e-6 then
                            blocked = true
                            break
                        end
                    end
                end
                -- Check occlusion by occluding segments
                if not blocked and occluding_segments then
                    for _, occ in ipairs(occluding_segments) do
                        local ok, ix, iy = segments_intersect_with_point(ray, occ)
                        if ok and distance(px, py, ix, iy) < dist_to_mid - 1e-6 then
                            blocked = true
                            break
                        end
                    end
                end
                if not blocked then
                    table.insert(visible_segments, {x1, y1, x2, y2})
                end
            end
        end
    end

    return visible_segments
end

local function _reflect(px, py, angle, x1, y1, x2, y2)
    -- Direction vector of the segment
    local dx, dy = x2 - x1, y2 - y1
    local seg_len2 = dx * dx + dy * dy

    local t = ((px - x1) * dx + (py - y1) * dy) / seg_len2
    if t < 0 or t > 1 then return nil end -- reject early

    local closestX = x1 + t * dx
    local closestY = y1 + t * dy

    local distance = math.distance(closestX, closestY, px, py)
    if distance > rt.settings.overworld.mirror.distance_threshold then return nil end

    -- Normal vector (perpendicular to the segment)
    local seg_len = math.sqrt(seg_len2)
    local ndx, ndy = dx / seg_len, dy / seg_len
    local nx, ny = -ndy, ndx -- normal (right-hand, y-down)

    -- Vector from closest point to original point
    local vx, vy = px - closestX, py - closestY
    local dist = vx * nx + vy * ny

    -- Reflected position: move twice the distance along the normal
    local rx = px - 2 * dist * nx
    local ry = py - 2 * dist * ny

    -- Segment angle
    local line_angle = math.atan2(dy, dx)

    -- Reflect the angle: theta' = 2*line_angle - theta
    local reflected_angle = 2 * line_angle - angle

    -- For Love2D, flip_x should always be true for a mirror reflection
    -- flip_y is false unless you want to mirror vertically as well
    local flip_x = false
    local flip_y = true

    return rx, ry, reflected_angle, flip_x, flip_y, distance
end


--- @brief
function ow.Mirror:update(delta)
    local x, y, w, h = self._scene:get_camera():get_world_bounds()

    local mirror_segments = {}
    local occluding_segments = {}

    self._world:update(delta)
    self._world:queryShapesInArea(x, y, x + w, y + h, function(shape)
        local data = shape:getUserData()
        if data.is_mirror == true then
            table.insert(mirror_segments, data.segment)
        else
            table.insert(occluding_segments, data.segment)
        end

        return true
    end)

    local px, py = self._scene:get_player():get_physics_body():get_position()
    self._visible = _get_visible_subsegments(mirror_segments, px, py, occluding_segments)

    self._mirror_images = {}
    for segment in values(self._visible) do
        local x1, y1, x2, y2 = table.unpack(segment)

        local rx, ry, angle, flip_x, flip_y, distance = _reflect(px, py, 0, x1, y1, x2, y2)
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