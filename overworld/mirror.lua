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
    if rt.GameState:get_are_reflections_enabled() == false then return end

    if self._mirror_images == nil
        or #self._mirror_images == 0
        or self._scene:get_player():get_is_ghost()
    then return end

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

local function _get_visible_subsegments(segments, px, py, occluding_segments)
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
    local flip_y = false --not flip_x

    local distance = math.abs(projection)

    return reflected_x, reflected_y, flip_x, flip_y, distance
end

--- @brief
function ow.Mirror:update(delta)
    if rt.GameState:get_are_reflections_enabled() == false then return end

    local camera = self._scene:get_camera()
    local bounds = camera:get_world_bounds()
    local padding = rt.settings.overworld.stage.visible_area_padding * camera:get_final_scale()
    bounds.x = bounds.x - padding
    bounds.y = bounds.y - padding
    bounds.width = bounds.width + 2 * padding
    bounds.height = bounds.height + 2 * padding

    local camera_x, camera_y, camera_w, camera_h = bounds:unpack()

    -- find segments near player
    local px, py = self._scene:get_player():get_physics_body():get_position()

    local x = px - self._offset_x
    local y = py - self._offset_y
    local r = rt.settings.overworld.mirror.segment_detection_radius_factor * rt.settings.player.radius
    if self._scene:get_player():get_is_bubble() == true then
        --r = r * rt.settings.player.bubble_radius_factor
    end

    self._px, self._py = px, py

    local mirror_segments = {}
    local occluding_segments = {}

    local shapes = self._world:getShapesInArea(camera_x, camera_y, camera_x + camera_w, camera_y + camera_h)---x - r, y - r, x + r, y + r)
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