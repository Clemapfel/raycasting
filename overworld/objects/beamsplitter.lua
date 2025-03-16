--- @class ow.BeamSplitter
ow.BeamSplitter = meta.class("BeamSplitter", rt.Drawable)

--- @brief
function ow.BeamSplitter:instantiate(object, stage, scene)
    self._world = stage:get_physics_world()
    self._body = object:create_physics_body(self._world)
    self._body:set_is_rotation_fixed(true)
    self._body:set_user_data(self)
    
    assert(object.type == ow.ObjectType.RECTANGLE, "In ow.BeamSpliter: object is not a rectangle")
    self._x = object.x
    self._y = object.y
    self._width = object.width
    self._height = object.height

    self._body:set_collision_group(ow.RayMaterial.BEAM_SPLITTER)
    self._raycast = ow.Raycast(self._world)
end

--- @brief
function ow.BeamSplitter:draw()
    love.graphics.push()
    love.graphics.translate(self._body:get_predicted_position())
    love.graphics.rotate(self._body._native:getAngle())
    love.graphics.rectangle("line", self._x, self._y, self._width, self._height)
    love.graphics.pop()
end

function _line_intersection(x1, y1, x2, y2, x3, y3, x4, y4)
    local denominator = (x1 - x2) * (y3 - y4) - (y1 - y2) * (x3 - x4)
    if denominator == 0 then return nil end
    local intersect_x = ((x1 * y2 - y1 * x2) * (x3 - x4) - (x1 - x2) * (x3 * y4 - y3 * x4)) / denominator
    local intersect_y = ((x1 * y2 - y1 * x2) * (y3 - y4) - (y1 - y2) * (x3 * y4 - y3 * x4)) / denominator
    return intersect_x, intersect_y
end

function _is_on_segment(px, py, x1, y1, x2, y2)
    local cross_product = (px - x1) * (y2 - y1) - (py - y1) * (x2 - x1)

    if math.abs(cross_product) > 1e-10 then
        return false
    end

    local dot_product = (px - x1) * (x2 - x1) + (py - y1) * (y2 - y1)
    if dot_product < 0 then
        return false
    end

    local squared_length_ba = (x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1)
    if dot_product > squared_length_ba then
        return false
    end

    return true
end

function _rotate_point(px, py, cx, cy, angle)
    local s = math.sin(angle)
    local c = math.cos(angle)

    -- Translate point back to origin
    px = px - cx
    py = py - cy

    -- Rotate point
    local xnew = px * c - py * s
    local ynew = px * s + py * c

    -- Translate point back
    px = xnew + cx
    py = ynew + cy

    return px, py
end

function ow.BeamSplitter:split_ray(contact_x, contact_y, dx, dy, normal_x, normal_y)
    local x, y, w, h = self._x, self._y, self._width, self._height
    local x_offset, y_offset = self._body:get_position()

    local rotation = self._body:get_rotation()

    -- Calculate the center of the rectangle
    local center_x, center_y = x, y
    x = x + x_offset
    y = y + y_offset

    -- Rotate the corners of the rectangle
    local top_left_x, top_left_y = _rotate_point(x, y, center_x, center_y, rotation)
    local top_right_x, top_right_y = _rotate_point(x + w, y, center_x, center_y, rotation)
    local bottom_right_x, bottom_right_y = _rotate_point(x + w, y + h, center_x, center_y, rotation)
    local bottom_left_x, bottom_left_y = _rotate_point(x, y + h, center_x, center_y, rotation)

    -- laser
    local cx1, cy1, cx2, cy2 = contact_x, contact_y, contact_x + dx, contact_y + dy

    -- top
    local tx1, ty1, tx2, ty2 = top_left_x, top_left_y, top_right_x, top_right_y
    local top_x, top_y = _line_intersection(cx1, cy1, cx2, cy2, tx1, ty1, tx2, ty2)

    -- right
    local rx1, ry1, rx2, ry2 = top_right_x, top_right_y, bottom_right_x, bottom_right_y
    local right_x, right_y = _line_intersection(cx1, cy1, cx2, cy2, rx1, ry1, rx2, ry2)

    -- bottom
    local bx1, by1, bx2, by2 = bottom_right_x, bottom_right_y, bottom_left_x, bottom_left_y
    local bottom_x, bottom_y = _line_intersection(cx1, cy1, cx2, cy2, bx1, by1, bx2, by2)

    -- left
    local lx1, ly1, lx2, ly2 = bottom_left_x, bottom_left_y, top_left_x, top_left_y
    local left_x, left_y = _line_intersection(cx1, cy1, cx2, cy2, lx1, ly1, lx2, ly2)

    local eps = 1
    local intersection_x, intersection_y
    if top_x ~= nil and _is_on_segment(top_x, top_y, tx1, ty1, tx2, ty2) then
        if math.abs(top_x - contact_x) > eps or math.abs(top_y - contact_y) > eps then
            intersection_x, intersection_y = top_x, top_y
        end
    end

    if right_x ~= nil and _is_on_segment(right_x, right_y, rx1, ry1, rx2, ry2) then
        if math.abs(right_x - contact_x) > eps or math.abs(right_y - contact_y) > eps then
            intersection_x, intersection_y = right_x, right_y
        end
    end

    if bottom_x ~= nil and _is_on_segment(bottom_x, bottom_y, bx1, by1, bx2, by2) then
        if math.abs(bottom_x - contact_x) > eps or math.abs(bottom_y - contact_y) > eps then
            intersection_x, intersection_y = bottom_x, bottom_y
        end
    end

    if left_x ~= nil and _is_on_segment(left_x, left_y, lx1, ly1, lx2, ly2) then
        if math.abs(left_x - contact_x) > eps or math.abs(left_y - contact_y) > eps then
            intersection_x, intersection_y = left_x, left_y
        end
    end

    return intersection_x, intersection_y, dx, dy
end