require "overworld.visibility_query"

rt.settings.overworld.blood_splatter = {
    line_width = 3.5,
    subdivision_length = rt.settings.player.radius / 2,
    hue_difference_threshold = 1 / 8
}

--- @class ow.BloodSpatter
ow.BloodSpatter = meta.class("BloodSpatter")

--- @brief
function ow.BloodSpatter:instantiate(scene)
    meta.assert(scene, ow.OverworldScene)
    meta.install(self, {
        _scene = scene,
        _query = ow.VisibilityQuery(),
        _visible_divisions = {},
        
        _offset_x = 0,
        _offset_y = 0,
        _impulse = rt.ImpulseSubscriber()
    })
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

    local a = 1.0
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
function ow.BloodSpatter:update(_)
    local player = self._scene:get_player()
    if not (player:get_is_disabled() or player:get_is_ghost()) then
        local x, y = player:get_position()
        local radius = player:get_radius()
        local r, g, b, a = player:get_color():unpack()
        self:_add(x, y, radius, r, g, b, a)
    end
end

--- @brief
function ow.BloodSpatter:_add(x, y, radius, color_r, color_g, color_b, opacity, allow_override)
    if opacity == nil then opacity = 1 end
    if allow_override == nil then allow_override = true end

    local search_r = math.max(400, 4 * rt.settings.player.radius * rt.settings.player.bottom_wall_ray_length_factor)

    x = x - self._offset_x
    y = y - self._offset_y

    local was_added = false
    for data in values(self._query:get_visible_subsegments(
        x, y,
        rt.AABB(x - search_r, y - search_r, 2 * search_r),
        false -- no visibility polygon
    )) do
        -- check for line-circle overlap
        local x1, y1, x2, y2 = table.unpack(data.subsegment)
        local ix1, iy1, ix2, iy2 = _clip_segment_in_circle(
            x1, y1, x2, y2,
            x, y,
            radius * rt.settings.player.bottom_wall_ray_length_factor -- player radius, not search radius
        )

        if ix1 ~= nil then
            local sx1, sy1, sx2, sy2 = table.unpack(data.edge.segment)
            local dx, dy = sx2 - sx1, sy2 - sy1
            local length = math.magnitude(dx, dy)
            if length > math.eps then
                -- project clipped points onto the original segment to get fraction
                local t1 = math.dot(ix1 - sx1, iy1 - sy1, dx, dy) / (length * length)
                local t2 = math.dot(ix2 - sx1, iy2 - sy1, dx, dy) / (length * length)

                local left_fraction = math.min(t1, t2)
                local right_fraction = math.max(t1, t2)
                left_fraction = math.clamp(left_fraction, 0, 1)
                right_fraction = math.clamp(right_fraction , 0, 1)

                -- color all subdivisions in this interval
                local color = rt.RGBA(color_r, color_g, color_b, opacity)
                local hue = select(1, rt.rgba_to_hsva(color_r, color_g, color_b, opacity))

                for division in values(data.edge.subdivisions) do
                    if division.left_fraction <= right_fraction and division.right_fraction >= left_fraction then
                        if allow_override or not division.is_active then
                            division.color = color
                            division.hue = hue
                            division.is_active = true
                            was_added = true
                        end
                    end
                end
            end -- length > math.eps
        end -- x1 ~= nil
    end -- for shape in values

    return was_added
end

--- @brief
function ow.BloodSpatter:notify_camera_changed(camera)
    local bounds = camera:get_world_bounds()
    local padding = rt.settings.overworld.stage.visible_area_padding * camera:get_final_scale()
    bounds.x = bounds.x - padding - self._offset_x
    bounds.y = bounds.y - padding - self._offset_y
    bounds.width = bounds.width + 2 * padding
    bounds.height = bounds.height + 2 * padding

    self._visible_divisions = {}
    for data in values(self._query:get_segments_in_area(bounds)) do
        for division in values(data.subdivisions) do
            if division.is_active then
                table.insert(self._visible_divisions, division)
            end
        end
    end
end

local _t = 0.1 -- experimentally determined to compensate best

--- @brief
function ow.BloodSpatter:draw()
    if self._visible_divisions == nil then return end
    
    local line_width = rt.settings.overworld.blood_splatter.line_width
    love.graphics.setLineWidth(line_width)
    love.graphics.setLineStyle("rough")
    love.graphics.setLineJoin("bevel")
    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)

    local brightness_offset = math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._impulse:get_pulse())
    for division in values(self._visible_divisions) do
        local r, g, b, a = division.color:unpack()
        love.graphics.setColor(
            (r - _t) * brightness_offset,
            (g - _t) * brightness_offset,
            (b - _t) * brightness_offset,
            a
        )
        love.graphics.line(division.segment)
    end

    love.graphics.pop()
end

--- @brief
function ow.BloodSpatter:draw_bloom()
    if self._visible_divisions == nil then return end

    local brightness_offset = math.mix(1, rt.settings.impulse_manager.max_brightness_factor, self._impulse:get_pulse())
    local line_width = rt.settings.overworld.blood_splatter.line_width
    love.graphics.setLineWidth(line_width)
    love.graphics.setLineStyle("rough")
    love.graphics.setLineJoin("bevel")
    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)

    for division in values(self._visible_divisions) do
        local r, g, b, a = division.color:unpack()
        love.graphics.setColor(
            r * brightness_offset,
            r * brightness_offset,
            r * brightness_offset,
            a
        )

        love.graphics.line(division.segment)
    end

    love.graphics.pop()
end

--- @brief
function ow.BloodSpatter:initialize(contours)
    meta.assert(contours, mt.Table)

    local max_length = rt.settings.overworld.blood_splatter.subdivision_length
    local datas = self._query:initialize(contours, nil) -- no reflective contours

    for data in values(datas) do
        -- Extract the segment coordinates directly from the userdata
        local x1, y1, x2, y2 = table.unpack(data.segment)

        local dx, dy = x2 - x1, y2 - y1
        local length = math.magnitude(dx, dy)
        local subdivisions = {}

        if length > max_length then
            local num_segments = math.ceil(length / max_length)
            local segment_length = length / num_segments

            for j = 0, num_segments - 1 do
                local left_fraction = j / num_segments
                local right_fraction = (j + 1) / num_segments

                local sx1 = x1 + left_fraction * dx
                local sy1 = y1 + left_fraction * dy
                local sx2 = x1 + right_fraction * dx
                local sy2 = y1 + right_fraction * dy

                local division = {
                    segment = { sx1, sy1, sx2, sy2 },
                    left_fraction = left_fraction,
                    right_fraction = right_fraction,
                    is_active = false,
                    hue = nil,
                    color = nil
                }

                table.insert(subdivisions, division)
            end
        else
            table.insert(subdivisions, {
                segment = { x1, y1, x2, y2 },
                left_fraction = 0,
                right_fraction = 1,
                is_active = false,
                hue = nil,
                color = nil
            })
        end

        data.subdivisions = subdivisions
    end
end

--- @brief
function ow.BloodSpatter:collect_segment_lights(bounds, callback)
    local hue_threshold = rt.settings.overworld.blood_splatter.hue_difference_threshold
    local x, y, w, h = bounds:unpack()

    local padding = rt.settings.overworld.light_map.light_range ^ 2
    x = x - padding - self._offset_x
    y = y - padding - self._offset_y
    w = w + 2 * padding
    h = h + 2 * padding

    for data in values(self._query:get_segments_in_area(rt.AABB(x, y, w, h))) do
        local x1, y1, x2, y2 = nil, nil, nil, nil
        local current_hue = nil
        local current_color = nil
        local segment_active = false

        local start_segment = function(division)
            x1, y1, x2, y2 = table.unpack(division.segment)
            current_hue = division.hue
            current_color = division.color
            segment_active = true
        end

        local end_segment = function()
            callback(
                x1 + self._offset_x,
                y1 + self._offset_y,
                x2 + self._offset_x,
                y2 + self._offset_y,
                current_color:unpack()
            )

            x1, y1, x2, y2 = nil, nil, nil, nil
            current_hue = nil
            current_color = nil
            segment_active = false
        end

        for division in values(data.subdivisions) do
            if division.is_active then
                if current_hue == nil then
                    start_segment(division)
                elseif math.abs(current_hue - division.hue) <= hue_threshold then
                    x2, y2 = division.segment[3], division.segment[4]
                else
                    end_segment()
                    start_segment(division)
                end
            elseif segment_active then
                end_segment()
            end
        end

        if segment_active then
            end_segment()
        end
    end
end

--- @brief
function ow.BloodSpatter:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end

--- @brief
function ow.BloodSpatter:get_offset()
    return self._offset_x, self._offset_y
end
