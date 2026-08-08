--- @class ow.VisiblityQuery
ow.VisibilityQuery = meta.class("VisibilityQuery")

--- @enum ow.ContourType
ow.ContourType = {
    REFLECTIVE = true,
    NON_REFLECTIVE = false
}
ow.ContourType = meta.enum("ContourType", ow.ContourType)

--- @brief
function ow.VisibilityQuery:initialize(non_reflective_contours, reflective_contours)
    if reflective_contours == nil then reflective_contours = {} end
    if non_reflective_contours == nil then non_reflective_contours = {} end
    meta.assert(non_reflective_contours, mt.Table, reflective_contours, mt.Table)

    self._world = love.physics.newWorld(0, 0, false)
    self._body = love.physics.newBody(self._world, 0, 0, b2.BodyType.STATIC)
    self._shapes = {}

    local metatable = {
        __index = function(self, key)
            rt.error("In ow.VisibilityQuery: trying to access property `", key, "` of a segment, but it does not exist")
        end
    }

    -- collect segments from contours
    local raw_segments = {}
    for contours_and_type in range(
        { reflective_contours, ow.ContourType.REFLECTIVE },
        { non_reflective_contours, ow.ContourType.NON_REFLECTIVE }
    ) do
        local contours, type = table.unpack(contours_and_type)
        for _, contour in ipairs(contours) do
            for i = 1, #contour - 2, 2 do
                table.insert(raw_segments, {
                    x1 = contour[i+0],
                    y1 = contour[i+1],
                    x2 = contour[i+2],
                    y2 = contour[i+3],
                    contour = contour,
                    type = type,
                    splits = {} -- list of t values where this segment must be cut
                })
            end
        end
    end

    -- find all pairwise intersection ts

    local function _segment_intersection(x1, y1, x2, y2, x3, y3, x4, y4)
        n = n or 0  -- number of coordinate-space units for the epsilon margin

        local d1x, d1y = x2 - x1, y2 - y1
        local d2x, d2y = x4 - x3, y4 - y3

        local denom = d1x * d2y - d1y * d2x
        if math.abs(denom) < 1e-12 then
            return nil
        end

        local dx, dy = x3 - x1, y3 - y1
        local t = (dx * d2y - dy * d2x) / denom
        local u = (dx * d1y - dy * d1x) / denom

        local margin = 1 -- px
        local t_eps = margin / math.magnitude(d1x, d1y)
        local u_eps = margin / math.magnitude(d2x, d2y)

        if t_eps > 1 then t_eps = 0 end
        if u_eps > 1 then u_eps = 0 end

        if t > t_eps and t < 1 - t_eps and u > u_eps and u < 1 - u_eps then
            return t, u, x1 + t * d1x, y1 + t * d1y
        end

        return nil
    end

    for a_i = 1, #raw_segments do
        for b_i = 1, #raw_segments do
            if a_i ~= b_i then
                local a = raw_segments[a_i]
                local b = raw_segments[b_i]
                local t, u = _segment_intersection(a.x1, a.y1, a.x2, a.y2, b.x1, b.y1, b.x2, b.y2)
                if t ~= nil then
                    table.insert(a.splits, t)
                    table.insert(b.splits, u)
                end
            end
        end
    end

    -- 3) split each segment at its recorded t values, producing final sub-segments
    local final_segments = {} -- { x1, y1, x2, y2, contour, type }
    for _, seg in ipairs(raw_segments) do
        if #seg.splits == 0 then
            table.insert(final_segments, {
                x1 = seg.x1, y1 = seg.y1,
                x2 = seg.x2, y2 = seg.y2,
                contour = seg.contour, type = seg.type
            })
        else
            table.sort(seg.splits)

            local dx, dy = seg.x2 - seg.x1, seg.y2 - seg.y1
            local prev_x, prev_y = seg.x1, seg.y1
            local prev_t = 0

            for _, t in ipairs(seg.splits) do
                -- avoid degenerate zero-length segments from duplicate t values
                if t - prev_t > 1e-6 then
                    local px, py = seg.x1 + t * dx, seg.y1 + t * dy
                    table.insert(final_segments, {
                        x1 = prev_x, y1 = prev_y,
                        x2 = px, y2 = py,
                        contour = seg.contour, type = seg.type
                    })
                    prev_x, prev_y = px, py
                    prev_t = t
                end
            end

            -- final tail segment from last split point to the original endpoint
            if 1 - prev_t > 1e-6 then
                table.insert(final_segments, {
                    x1 = prev_x, y1 = prev_y,
                    x2 = seg.x2, y2 = seg.y2,
                    contour = seg.contour, type = seg.type
                })
            end
        end
    end

    -- 4) build shapes from the final, split segment list
    local userdatas = {}
    for _, seg in ipairs(final_segments) do
        local shape = love.physics.newEdgeShape(self._body, seg.x1, seg.y1, seg.x2, seg.y2)
        local userdata = setmetatable({
            shape = shape,
            segment = { seg.x1, seg.y1, seg.x2, seg.y2 },
            contour = seg.contour,
            type = seg.type
        }, metatable)

        shape:setUserData(userdata)

        table.insert(self._shapes, shape)
        table.insert(userdatas, userdata)
    end

    return userdatas
end

--- @brief
function ow.VisibilityQuery:get_segments()
    local result = {}
    for _, shape in ipairs(self._shapes) do
        table.insert(result, shape:getUserData())
    end

    return result
end

--- @brief
function ow.VisibilityQuery:get_segments_in_area(aabb)
    meta.assert(aabb, rt.AABB)

    local shapes = self._world:getShapesInArea(
        aabb.x, 
        aabb.y,
        aabb.x + aabb.width,
        aabb.y + aabb.height
    )
    
    local result = {}
    for _, shape in ipairs(shapes) do
        table.insert(result, shape:getUserData())
    end
    
    return result
end

--- @brief
function ow.VisibilityQuery:get_visible_subsegments(x, y, r)
    meta.assert(x, mt.Number, y, mt.Number, r, mt.Number)
    return self:_compute_subsegments(x, y, r)
end

--- @brief
function ow.VisibilityQuery:draw()
    rt.Palette.GREEN:bind()

    if self._subsegments ~= nil then
        for _, entry in ipairs(self._subsegments) do
            love.graphics.line(entry.segment)
        end

        love.graphics.circle("fill", table.unpack(self._cursor))

        love.graphics.setLineWidth(0.5)
        local x, y = rt.SceneManager:get_current_scene():get_camera():screen_xy_to_world_xy(love.mouse.getPosition())
        for i = 1, #self._todo, 2 do
            love.graphics.line(x, y, self._todo[i], self._todo[i+1])
        end
    end
end

--- @brief
function ow.VisibilityQuery:_compute_subsegments(x, y, r)
    x, y = rt.SceneManager:get_current_scene():get_camera():screen_xy_to_world_xy(love.mouse.getPosition())
    self._cursor = { x, y, 10 }
    local edges = {}
    for i, shape in ipairs(self._world:getShapesInArea(
        x - r, y - r,
        x + r, y + r
    )) do
        table.insert(edges, shape:getUserData())
    end

    self._todo = {}
    if #edges == 0 then return {} end
    local angles = table.new(#edges, 0)
    local angle_set = {}
    for _, data in ipairs(edges) do
        local ax, ay, bx, by = table.unpack(data.segment)
        local a_angle = math.normalize_angle(math.angle(math.subtract(ax, ay, x, y)))
        local b_angle = math.normalize_angle(math.angle(math.subtract(bx, by, x, y)))
        angle_set[a_angle] = true
        angle_set[b_angle] = true
        table.insert(self._todo, ax)
        table.insert(self._todo, ay)
        table.insert(self._todo, bx)
        table.insert(self._todo, by)
    end

    for angle in keys(angle_set) do
        table.insert(angles, angle)
    end

    table.sort(angles)

    local function ray_segment_distance(x, y, dir_x, dir_y, ax, ay, bx, by)
        local dx = bx - ax
        local dy = by - ay
        local det = dir_x * dy - dir_y * dx
        if math.abs(det) < math.eps then
            return nil
        end

        local oax = ax - x
        local oay = ay - y
        local distance = (oax * dy - oay * dx) / det

        if distance >= 0 then
            local hit_x = x + dir_x * distance
            local hit_y = y + dir_y * distance

            local u = (dir_y * oax - dir_x * oay) / det
            if u < 0 or u > 1 then return nil end

            return distance, hit_x, hit_y
        end
        return nil
    end

    local subsegments = {}
    local current_edge = nil
    local current_start_x, current_start_y = nil, nil
    local current_end_x, current_end_y = nil, nil

    local function push_current()
        if current_start_x ~= nil then
            table.insert(subsegments, {
                edge = current_edge,
                segment = { current_start_x, current_start_y, current_end_x, current_end_y }
            })
        end
    end

    local function visit(angle)
        local dir_x, dir_y = math.cos(angle), math.sin(angle)
        local min_distance = math.huge
        local min_edge = nil
        local min_point_x, min_point_y = nil, nil
        for _, edge in ipairs(edges) do
            local distance, hit_x, hit_y = ray_segment_distance(
                x, y, dir_x, dir_y,
                table.unpack(edge.segment)
            )

            if distance ~= nil and distance < min_distance then
                min_distance = distance
                min_edge = edge
                min_point_x, min_point_y = hit_x, hit_y
            end
        end

        if min_edge ~= nil then
            if min_edge ~= current_edge then
                push_current()
                current_edge = min_edge
                current_start_x, current_start_y = min_point_x, min_point_y
                current_end_x, current_end_y = min_point_x, min_point_y
            else
                current_end_x, current_end_y = min_point_x, min_point_y
            end
        end
    end

    local eps = math.degrees_to_radians(2 / 360)
    for angle_i = 1, #angles do
        local angle = angles[angle_i]
        visit(angle - eps)
        visit(angle)
        visit(angle + eps)
    end
    push_current()

    -- merge subsegment going across sweep start / end
    if #subsegments > 1 and subsegments[1].edge == subsegments[#subsegments].edge then
        local first = table.remove(subsegments, 1)
        local last = subsegments[#subsegments]
        last.segment[3] = first.segment[3]
        last.segment[4] = first.segment[4]
    end

    self._subsegments = subsegments
    return subsegments
end

--[[
local function _get_subsegments(segments, px, py, occluding_segments)
    local epsilon = math.eps
    local two_pi = 2 * math.pi

    if segments == nil or #segments == 0 then return {} end
    occluding_segments = occluding_segments or {}

    local all_segments = {}
    local is_mirror = {}

    for i = 1, #segments do
        local segment = segments[i]
        local dx = segment[3] - segment[1]
        local dy = segment[4] - segment[2]
        if dx * dx + dy * dy > epsilon * epsilon then
            table.insert(all_segments, segment)
            is_mirror[segment] = true
        end
    end

    for i = 1, #occluding_segments do
        local segment = occluding_segments[i]
        local dx = segment[3] - segment[1]
        local dy = segment[4] - segment[2]
        if dx * dx + dy * dy > epsilon * epsilon then
            table.insert(all_segments, segment)
            if is_mirror[segment] == nil then is_mirror[segment] = false end
        end
    end

    if #all_segments == 0 then return {} end

    local visible_segments = {}
    local handled_colinear = {}

    for i = 1, #segments do
        local segment = segments[i]
        local segment_x1, segment_y1, segment_x2, segment_y2 = segment[1], segment[2], segment[3], segment[4]
        local dx = segment_x2 - segment_x1
        local dy = segment_y2 - segment_y1

        if dx * dx + dy * dy > epsilon * epsilon then
            local angle_1 = math.atan2(segment_y1 - py, segment_x1 - px)
            local angle_2 = math.atan2(segment_y2 - py, segment_x2 - px)

            local angle_diff = angle_1 - angle_2
            angle_diff = (angle_diff + math.pi) % two_pi
            if angle_diff <= 0 then angle_diff = angle_diff + two_pi end
            angle_diff = angle_diff - math.pi

            if math.abs(angle_diff) <= 1e-7 then
                handled_colinear[segment] = true

                local direction_x = math.cos(angle_1)
                local direction_y = math.sin(angle_1)
                local ray_squared = direction_x * direction_x + direction_y * direction_y

                local t1 = ((segment_x1 - px) * direction_x + (segment_y1 - py) * direction_y) / ray_squared
                local t2 = ((segment_x2 - px) * direction_x + (segment_y2 - py) * direction_y) / ray_squared
                local interval_min = math.max(0, math.min(t1, t2))
                local interval_max = math.max(t1, t2)

                if interval_max >= 0 then
                    local blockers = {}

                    for j = 1, #all_segments do
                        local other_segment = all_segments[j]
                        if other_segment ~= segment then
                            local other_x1, other_y1, other_x2, other_y2 = other_segment[1], other_segment[2], other_segment[3], other_segment[4]
                            local other_dx = other_x2 - other_x1
                            local other_dy = other_y2 - other_y1

                            if other_dx * other_dx + other_dy * other_dy > epsilon * epsilon then
                                local vector_1_x, vector_1_y = other_x1 - px, other_y1 - py
                                local vector_2_x, vector_2_y = other_x2 - px, other_y2 - py

                                local cross_1 = vector_1_x * direction_y - vector_1_y * direction_x
                                local cross_2 = vector_2_x * direction_y - vector_2_y * direction_x
                                local cross_dir = other_dx * direction_y - other_dy * direction_x

                                if (math.abs(cross_1) < 1e-7 and math.abs(cross_2) < 1e-7) or math.abs(cross_dir) < 1e-7 then
                                    local blocker_t1 = ((other_x1 - px) * direction_x + (other_y1 - py) * direction_y) / ray_squared
                                    local blocker_t2 = ((other_x2 - px) * direction_x + (other_y2 - py) * direction_y) / ray_squared
                                    local blocker_min = math.min(blocker_t1, blocker_t2)
                                    local blocker_max = math.max(blocker_t1, blocker_t2)

                                    if blocker_max >= interval_min - epsilon then
                                        table.insert(blockers, {blocker_min, blocker_max})
                                    end
                                end
                            end
                        end
                    end

                    table.sort(blockers, function(a, b) return a[1] < b[1] end)

                    local residuals = {{interval_min, interval_max}}
                    for _, blocker in ipairs(blockers) do
                        local blocker_min, blocker_max = blocker[1], blocker[2]
                        local new_residuals = {}

                        for _, residual in ipairs(residuals) do
                            local residual_min, residual_max = residual[1], residual[2]

                            if blocker_max <= residual_min or blocker_min >= residual_max then
                                table.insert(new_residuals, {residual_min, residual_max})
                            else
                                if blocker_min > residual_min then
                                    table.insert(new_residuals, {residual_min, math.min(blocker_min, residual_max)})
                                end
                                if blocker_max < residual_max then
                                    table.insert(new_residuals, {math.max(blocker_max, residual_min), residual_max})
                                end
                            end
                        end
                        residuals = new_residuals
                        if #residuals == 0 then break end
                    end

                    local segment_vector_x, segment_vector_y = dx, dy
                    local segment_squared = segment_vector_x * segment_vector_x + segment_vector_y * segment_vector_y

                    for _, residual in ipairs(residuals) do
                        local t0, t1 = residual[1], residual[2]
                        if t1 - t0 > epsilon then
                            local point_a_x = px + t0 * direction_x
                            local point_a_y = py + t0 * direction_y
                            local point_b_x = px + t1 * direction_x
                            local point_b_y = py + t1 * direction_y

                            local u_a = ((point_a_x - segment_x1) * segment_vector_x + (point_a_y - segment_y1) * segment_vector_y) / segment_squared
                            u_a = math.max(0, math.min(1, u_a))
                            local clamped_a_x = segment_x1 + u_a * segment_vector_x
                            local clamped_a_y = segment_y1 + u_a * segment_vector_y

                            local u_b = ((point_b_x - segment_x1) * segment_vector_x + (point_b_y - segment_y1) * segment_vector_y) / segment_squared
                            u_b = math.max(0, math.min(1, u_b))
                            local clamped_b_x = segment_x1 + u_b * segment_vector_x
                            local clamped_b_y = segment_y1 + u_b * segment_vector_y

                            local clamp_dx = clamped_b_x - clamped_a_x
                            local clamp_dy = clamped_b_y - clamped_a_y
                            if clamp_dx * clamp_dx + clamp_dy * clamp_dy > epsilon * epsilon then
                                table.insert(visible_segments, {clamped_a_x, clamped_a_y, clamped_b_x, clamped_b_y})
                            end
                        end
                    end
                end
            end
        end
    end

    local sweep_mirrors = {}
    for i = 1, #segments do
        local segment = segments[i]
        if not handled_colinear[segment] then
            table.insert(sweep_mirrors, segment)
        end
    end

    if #sweep_mirrors == 0 then return visible_segments end

    local angle_list = {}
    local angle_set = {}

    for i = 1, #sweep_mirrors do
        local segment = sweep_mirrors[i]
        local angle_1 = math.atan2(segment[2] - py, segment[1] - px)
        local angle_2 = math.atan2(segment[4] - py, segment[3] - px)

        angle_1 = (angle_1 + math.pi) % two_pi
        if angle_1 <= 0 then angle_1 = angle_1 + two_pi end
        angle_1 = angle_1 - math.pi

        angle_2 = (angle_2 + math.pi) % two_pi
        if angle_2 <= 0 then angle_2 = angle_2 + two_pi end
        angle_2 = angle_2 - math.pi

        if not angle_set[angle_1] then
            angle_set[angle_1] = true
            table.insert(angle_list, angle_1)
        end
        if not angle_set[angle_2] then
            angle_set[angle_2] = true
            table.insert(angle_list, angle_2)
        end
    end

    for i = 1, #occluding_segments do
        local segment = occluding_segments[i]
        local dx = segment[3] - segment[1]
        local dy = segment[4] - segment[2]
        if dx * dx + dy * dy > epsilon * epsilon then
            local angle_1 = math.atan2(segment[2] - py, segment[1] - px)
            local angle_2 = math.atan2(segment[4] - py, segment[3] - px)

            angle_1 = (angle_1 + math.pi) % two_pi
            if angle_1 <= 0 then angle_1 = angle_1 + two_pi end
            angle_1 = angle_1 - math.pi

            angle_2 = (angle_2 + math.pi) % two_pi
            if angle_2 <= 0 then angle_2 = angle_2 + two_pi end
            angle_2 = angle_2 - math.pi

            if not angle_set[angle_1] then
                angle_set[angle_1] = true
                table.insert(angle_list, angle_1)
            end
            if not angle_set[angle_2] then
                angle_set[angle_2] = true
                table.insert(angle_list, angle_2)
            end
        end
    end

    table.sort(angle_list)

    if #angle_list < 2 then
        if #angle_list == 0 then
            angle_list = {-math.pi, 0}
        else
            local new_angle = angle_list[1] + 0.5
            new_angle = (new_angle + math.pi) % two_pi
            if new_angle <= 0 then new_angle = new_angle + two_pi end
            new_angle = new_angle - math.pi
            table.insert(angle_list, new_angle)
            table.sort(angle_list)
        end
    end

    local angle_count = #angle_list
    local cell_winners = {}

    for i = 1, angle_count do
        local angle_left = angle_list[i]
        local angle_right = (i < angle_count) and angle_list[i + 1] or (angle_list[1] + two_pi)
        local angle_mid_raw = angle_left + 0.5 * (angle_right - angle_left)
        local angle_mid = (angle_mid_raw + math.pi) % two_pi
        if angle_mid <= 0 then angle_mid = angle_mid + two_pi end
        angle_mid = angle_mid - math.pi

        local direction_x = math.cos(angle_mid)
        local direction_y = math.sin(angle_mid)
        local best_t = math.huge
        local best_segment = nil
        local best_is_mirror = false

        for j = 1, #all_segments do
            local segment = all_segments[j]
            local segment_ax, segment_ay, segment_bx, segment_by = segment[1], segment[2], segment[3], segment[4]
            local segment_x = segment_bx - segment_ax
            local segment_y = segment_by - segment_ay
            local origin_to_a_x = segment_ax - px
            local origin_to_a_y = segment_ay - py

            local denominator = direction_x * segment_y - direction_y * segment_x

            if math.abs(denominator) >= epsilon then
                local t = (origin_to_a_x * segment_y - origin_to_a_y * segment_x) / denominator
                local u = (origin_to_a_x * direction_y - origin_to_a_y * direction_x) / denominator

                if t >= -epsilon and u >= -epsilon and u <= 1 + epsilon and t < best_t - 1e-10 then
                    best_t = t
                    best_segment = segment
                    best_is_mirror = is_mirror[segment] == true
                end
            end
        end

        if best_segment ~= nil and best_is_mirror and not handled_colinear[best_segment] then
            cell_winners[i] = best_segment
        end
    end

    for i = 1, #sweep_mirrors do
        local segment = sweep_mirrors[i]
        local runs = {}
        local run_start = nil

        for j = 1, angle_count do
            if cell_winners[j] == segment then
                if run_start == nil then run_start = j end
            else
                if run_start ~= nil then
                    table.insert(runs, {run_start, j - 1})
                    run_start = nil
                end
            end
        end

        if run_start ~= nil then
            table.insert(runs, {run_start, angle_count})
        end

        if #runs >= 2 and cell_winners[1] == segment and cell_winners[angle_count] == segment then
            runs[1][1] = runs[#runs][1]
            table.remove(runs, #runs)
        end

        if #runs > 0 then
            local segment_x1, segment_y1, segment_x2, segment_y2 = segment[1], segment[2], segment[3], segment[4]

            for _, run in ipairs(runs) do
                local cell_start, cell_end = run[1], run[2]
                local angle_left = angle_list[cell_start]
                local angle_right = (cell_end < angle_count) and angle_list[cell_end + 1] or (angle_list[1] + two_pi)

                local angle_left_normalized = (angle_left + math.pi) % two_pi
                if angle_left_normalized <= 0 then angle_left_normalized = angle_left_normalized + two_pi end
                angle_left_normalized = angle_left_normalized - math.pi

                local angle_right_normalized = (angle_right + math.pi) % two_pi
                if angle_right_normalized <= 0 then angle_right_normalized = angle_right_normalized + two_pi end
                angle_right_normalized = angle_right_normalized - math.pi

                local direction_x_left = math.cos(angle_left_normalized)
                local direction_y_left = math.sin(angle_left_normalized)
                local segment_x = segment_x2 - segment_x1
                local segment_y = segment_y2 - segment_y1
                local origin_to_a_x = segment_x1 - px
                local origin_to_a_y = segment_y1 - py
                local denominator = direction_x_left * segment_y - direction_y_left * segment_x

                local subsegment_x0, subsegment_y0

                if math.abs(denominator) >= epsilon then
                    local t = (origin_to_a_x * segment_y - origin_to_a_y * segment_x) / denominator
                    local u = (origin_to_a_x * direction_y_left - origin_to_a_y * direction_x_left) / denominator

                    if t >= -epsilon and u >= -epsilon and u <= 1 + epsilon then
                        subsegment_x0 = px + t * direction_x_left
                        subsegment_y0 = py + t * direction_y_left
                    end
                end

                if not subsegment_x0 then
                    local angle_to_1 = math.atan2(segment_y1 - py, segment_x1 - px)
                    local diff_1 = angle_to_1 - angle_left_normalized
                    diff_1 = (diff_1 + math.pi) % two_pi
                    if diff_1 <= 0 then diff_1 = diff_1 + two_pi end
                    diff_1 = diff_1 - math.pi

                    if math.abs(diff_1) <= 1e-7 then
                        subsegment_x0, subsegment_y0 = segment_x1, segment_y1
                    else
                        subsegment_x0, subsegment_y0 = segment_x2, segment_y2
                    end
                end

                local direction_x_right = math.cos(angle_right_normalized)
                local direction_y_right = math.sin(angle_right_normalized)
                local denominator_right = direction_x_right * segment_y - direction_y_right * segment_x

                local subsegment_x1, subsegment_y1

                if math.abs(denominator_right) >= epsilon then
                    local t = (origin_to_a_x * segment_y - origin_to_a_y * segment_x) / denominator_right
                    local u = (origin_to_a_x * direction_y_right - origin_to_a_y * direction_x_right) / denominator_right

                    if t >= -epsilon and u >= -epsilon and u <= 1 + epsilon then
                        subsegment_x1 = px + t * direction_x_right
                        subsegment_y1 = py + t * direction_y_right
                    end
                end

                if not subsegment_x1 then
                    local angle_to_2 = math.atan2(segment_y2 - py, segment_x2 - px)
                    local diff_2 = angle_to_2 - angle_right_normalized
                    diff_2 = (diff_2 + math.pi) % two_pi
                    if diff_2 <= 0 then diff_2 = diff_2 + two_pi end
                    diff_2 = diff_2 - math.pi

                    if math.abs(diff_2) <= 1e-6 then
                        subsegment_x1, subsegment_y1 = segment_x2, segment_y2
                    else
                        subsegment_x1, subsegment_y1 = segment_x1, segment_y1
                    end
                end

                local dx_sub = subsegment_x1 - subsegment_x0
                local dy_sub = subsegment_y1 - subsegment_y0
                if dx_sub * dx_sub + dy_sub * dy_sub > epsilon * epsilon then
                    table.insert(visible_segments, {subsegment_x0, subsegment_y0, subsegment_x1, subsegment_y1})
                end
            end
        end
    end

    table.sort(visible_segments, function(a, b)
        local a_center_x = 0.5 * (a[1] + a[3])
        local a_center_y = 0.5 * (a[2] + a[4])
        local b_center_x = 0.5 * (b[1] + b[3])
        local b_center_y = 0.5 * (b[2] + b[4])
        local distance_a = (a_center_x - px) * (a_center_x - px) + (a_center_y - py) * (a_center_y - py)
        local distance_b = (b_center_x - px) * (b_center_x - px) + (b_center_y - py) * (b_center_y - py)
        return distance_a < distance_b
    end)

    return visible_segments
end

]]