require "common.contour"
local slick = require "dependencies.slick.slick"

rt.settings.overworld.mirror = {
    distance_threshold = math.huge,
    player_attenuation_radius = 0.25, -- fraction of screen size
}

--- @class ow.Mirror
ow.Mirror = meta.class("Mirror")

local _shader = rt.Shader("overworld/mirror.glsl")

--- @brief
function ow.Mirror:instantiate(
    scene,
    get_mirror_tris_callback,
    draw_mirror_mask_callback,
    get_occluding_tris_callback, -- optional
    draw_occluding_mask_callback -- optional
)
    meta.assert(
        scene, "OverworldScene",
        get_mirror_tris_callback, "Function",
        draw_mirror_mask_callback, "Function"
    )

    if get_occluding_tris_callback ~= nil then
        meta.assert_typeof(get_occluding_tris_callback, "Function", 4)
    end

    if draw_occluding_mask_callback ~= nil then
        meta.assert_typeof(draw_occluding_mask_callback, "Function", 5)
    end

    meta.install(self, {
        _scene = scene,
        _get_mirror_tris_callback = get_mirror_tris_callback,
        _draw_mirror_mask_callback = draw_mirror_mask_callback,
        _get_occluding_tris_callback = get_occluding_tris_callback,
        _draw_occluding_mask_callback = draw_occluding_mask_callback,
        _edges = {},
        _world = nil,
        _offset_x = 0,
        _offset_y = 0
    })
end

--- @brief
function ow.Mirror:draw()
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

        love.graphics.push("all")
        love.graphics.reset()
        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.line(lx1, ly1, lx2, ly2)
        love.graphics.pop()
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
function ow.Mirror:create_contour()
    local mirror_segments, occluding_segments = {}, {}

    local occluding_tris
    if self._get_occluding_tris_callback ~= nil then
        occluding_tris = self._get_occluding_tris_callback()
    else
        occluding_tris = {}
    end

    for segments_tris in range(
        { mirror_segments, self._get_mirror_tris_callback() },
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

function _get_visible_subsegments(segments, px, py, occluding_segments)
    local visible_segments = {}

    local abs, min, max = math.abs, math.min, math.max
    local segment_eps = 1e-8
    local distance_eps = 1e-6

    local n_mirror_segments = #segments
    local n_occluding_segments = occluding_segments and #occluding_segments or 0

    -- precompute bounding boxes for intersection culling
    local mirror_aabbs = {}
    for i = 1, n_mirror_segments do
        local segment = segments[i]
        local x1, y1, x2, y2 = segment[1], segment[2], segment[3], segment[4]
        mirror_aabbs[i] = { min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2) }
    end

    local occluding_aabbs
    if occluding_segments then
        occluding_aabbs = {}
        for k = 1, n_occluding_segments do
            local segment = occluding_segments[k]
            local x1, y1, x2, y2 = segment[1], segment[2], segment[3], segment[4]
            occluding_aabbs[k] = { min(x1, x2), min(y1, y2), max(x1, x2), max(y1, y2) }
        end
    end

    local function aabb_intersects(ax1, ay1, ax2, ay2, bx1, by1, bx2, by2)
        return ax1 <= bx2 and ax2 >= bx1 and ay1 <= by2 and ay2 >= by1
    end

    -- check if segments intersect, return point and parametric coordinates
    local function segment_intersection(x1, y1, x2, y2, x3, y3, x4, y4)
        local denom = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
        if abs(denom) < segment_eps then return false end

        local t = ((x1 - x3) * (y3 - y4) - (y1 - y3) * (x3 - x4)) / denom
        local u = -((x1 - x2) * (y1 - y3) - (y1 - y2) * (x1 - x3)) / denom
        if t >= 0 and t <= 1 and u >= 0 and u <= 1 then
            local ix = x1 + t * (x2 - x1)
            local iy = y1 + t * (y2 - y1)
            return true, ix, iy, t, u
        end

        return false
    end

    -- find all intersection points to split segments
    local segment_split_ts = {}
    for i = 1, n_mirror_segments do
        segment_split_ts[i] = { 0.0, 1.0 }
    end

    -- mirror segment intersections
    for i = 1, n_mirror_segments do
        local segment_a = segments[i]
        local x1, y1, x2, y2 = segment_a[1], segment_a[2], segment_a[3], segment_a[4]
        local aabb_a = mirror_aabbs[i]
        for j = i + 1, n_mirror_segments do
            local aabb_b = mirror_aabbs[j]
            if aabb_intersects(aabb_a[1], aabb_a[2], aabb_a[3], aabb_a[4], aabb_b[1], aabb_b[2], aabb_b[3], aabb_b[4]) then
                local segment_b = segments[j]
                local ok, _, _, t1, t2 = segment_intersection(x1, y1, x2, y2, segment_b[1], segment_b[2], segment_b[3], segment_b[4])
                if ok then
                    if t1 > segment_eps and t1 < 1 - segment_eps then
                        segment_split_ts[i][#segment_split_ts[i] + 1] = t1
                    end
                    if t2 > segment_eps and t2 < 1 - segment_eps then
                        segment_split_ts[j][#segment_split_ts[j] + 1] = t2
                    end
                end
            end
        end
    end

    -- occluding segment intersections
    if occluding_segments and n_occluding_segments > 0 then
        for i = 1, n_mirror_segments do
            local segment_a = segments[i]
            local x1, y1, x2, y2 = segment_a[1], segment_a[2], segment_a[3], segment_a[4]
            local aabb_a = mirror_aabbs[i]
            local ts = segment_split_ts[i]
            for k = 1, n_occluding_segments do
                local aabb_b = occluding_aabbs[k]
                if aabb_intersects(aabb_a[1], aabb_a[2], aabb_a[3], aabb_a[4], aabb_b[1], aabb_b[2], aabb_b[3], aabb_b[4]) then
                    local segment_b = occluding_segments[k]
                    local ok, _, _, t1, _ = segment_intersection(x1, y1, x2, y2, segment_b[1], segment_b[2], segment_b[3], segment_b[4])
                    if ok and t1 > segment_eps and t1 < 1 - segment_eps then
                        ts[#ts + 1] = t1
                    end
                end
            end
        end
    end

    -- Precompute potential blockers using fan-shaped bounding box from player to segment
    local mirror_blocks = {}
    local occluding_blocks = {}
    for i = 1, n_mirror_segments do
        local segment = segments[i]
        local x1, y1, x2, y2 = segment[1], segment[2], segment[3], segment[4]
        local fan_min_x = min(px, min(x1, x2))
        local fan_max_x = max(px, max(x1, x2))
        local fan_min_y = min(py, min(y1, y2))
        local fan_max_y = max(py, max(y1, y2))

        local blockers = {}
        for j = 1, n_mirror_segments do
            if j ~= i then
                local mirror_aabb = mirror_aabbs[j]
                if aabb_intersects(
                    fan_min_x, fan_min_y, fan_max_x, fan_max_y,
                    mirror_aabb[1], mirror_aabb[2], mirror_aabb[3], mirror_aabb[4]
                ) then
                    blockers[#blockers + 1] = j
                end
            end
        end
        mirror_blocks[i] = blockers

        if n_occluding_segments > 0 then
            local occluding = {}
            for k = 1, n_occluding_segments do
                local occluding_aabb = occluding_aabbs[k]
                if aabb_intersects(
                    fan_min_x, fan_min_y, fan_max_x, fan_max_y,
                    occluding_aabb[1], occluding_aabb[2], occluding_aabb[3], occluding_aabb[4]
                ) then
                    occluding[#occluding + 1] = k
                end
            end
            occluding_blocks[i] = occluding
        end
    end

    local function point_at_parameter(seg, t)
        local x1, y1, x2, y2 = seg[1], seg[2], seg[3], seg[4]
        return x1 + t * (x2 - x1), y1 + t * (y2 - y1)
    end

    -- test visibility of each subsegment
    for i = 1, n_mirror_segments do
        local segment = segments[i]
        local t_list = segment_split_ts[i]
        table.sort(t_list, function(a, b) return a < b end)

        local blocker_candidates = mirror_blocks[i]
        local occluding_candidates = occluding_blocks and occluding_blocks[i] or nil

        for k = 1, #t_list - 1 do
            local t1 = t_list[k]
            local t2 = t_list[k + 1]
            if t2 - t1 > segment_eps then
                local x1, y1 = point_at_parameter(segment, t1)
                local x2, y2 = point_at_parameter(segment, t2)

                local mid_x, mid_y = (x1 + x2) * 0.5, (y1 + y2) * 0.5
                local distance_to_mid = math.distance(px, py, mid_x, mid_y)
                local blocked = false

                local ray_min_x = min(px, mid_x)
                local ray_max_x = max(px, mid_x)
                local ray_min_y = min(py, mid_y)
                local ray_max_y = max(py, mid_y)

                -- check mirror segment occlusion
                for idx = 1, #blocker_candidates do
                    local blocker = blocker_candidates[idx]
                    local blocker_aabb = mirror_aabbs[blocker]
                    if aabb_intersects(
                        ray_min_x, ray_min_y, ray_max_x, ray_max_y,
                        blocker_aabb[1], blocker_aabb[2], blocker_aabb[3], blocker_aabb[4]
                    ) then
                        local s2 = segments[blocker]
                        local intersects, ix, iy, _, _ = segment_intersection(px, py, mid_x, mid_y, s2[1], s2[2], s2[3], s2[4])
                        if intersects then
                            local distance = math.distance(px, py, ix, iy)
                            if distance < distance_to_mid - distance_eps then
                                blocked = true
                                break
                            end
                        end
                    end
                end

                -- check occluding segment occlusion
                if not blocked and occluding_candidates then
                    for candidate_i = 1, #occluding_candidates do
                        local occluder = occluding_candidates[candidate_i]
                        local occluder_aabb = occluding_aabbs[occluder]
                        if aabb_intersects(
                            ray_min_x, ray_min_y, ray_max_x, ray_max_y,
                            occluder_aabb[1], occluder_aabb[2], occluder_aabb[3], occluder_aabb[4]
                        ) then
                            local segment_b = occluding_segments[occluder]
                            local intersects, ix, iy, _, _ = segment_intersection(px, py, mid_x, mid_y, segment_b[1], segment_b[2], segment_b[3], segment_b[4])
                            if intersects then
                                local distance = math.distance(px, py, ix, iy)
                                if distance < distance_to_mid - distance_eps then
                                    blocked = true
                                    break
                                end
                            end
                        end
                    end
                end

                if not blocked then
                    visible_segments[#visible_segments + 1] = { x1, y1, x2, y2 }
                end
            end
        end
    end

    return visible_segments
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

    local w, h = 2 * camera_w * fraction, 2 * camera_h * fraction
    local x = px - w / 2
    local y = py - h / 2

    x = x - self._offset_x
    y = y - self._offset_y

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