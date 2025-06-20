--- @class rt.AABB
rt.AABB = meta.class("AABB")

--- @return rt.AABB
function rt.AABB:instantiate(x, y, width, height)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if width == nil then width = 1 end
    if height == nil then height = 1 end
    meta.install(self, {
        x = x,
        y = y,
        width = width,
        height = height
    })
end

--- @brief
function rt.AABB:reformat(x, y, width, height)
    self.x, self.y, self.width, self.height = x, y, width, height
end

--- @brief
function rt.AABB:unpack()
    return self.x, self.y, self.width, self.height
end

--- @brief
function rt.AABB:clone()
    return rt.AABB(self.x, self.y, self.width, self.height)
end

local function _contains(px, py, x, y, w, h)
    return px >= x and px <= x + w and py >= y and py <= y + h
end

--- @brief
function rt.AABB:contains(x, y)
    return _contains(x, y, self.x, self.y, self.width, self.height)
end

local function _intersects(x1, y1, x2, y2, x3, y3, x4, y4)
    local function orientation(px, py, qx, qy, rx, ry)
        local val = (qy - py) * (rx - qx) - (qx - px) * (ry - qy)
        if val == 0 then return 0 end -- collinear
        return (val > 0) and 1 or 2 -- clockwise or counterclockwise
    end

    local function on_segment(px, py, qx, qy, rx, ry)
        return rx >= math.min(px, qx) and rx <= math.max(px, qx) and
            ry >= math.min(py, qy) and ry <= math.max(py, qy)
    end

    local o1 = orientation(x1, y1, x2, y2, x3, y3)
    local o2 = orientation(x1, y1, x2, y2, x4, y4)
    local o3 = orientation(x3, y3, x4, y4, x1, y1)
    local o4 = orientation(x3, y3, x4, y4, x2, y2)

    if o1 ~= o2 and o3 ~= o4 then
        return true
    end

    if o1 == 0 and on_segment(x1, y1, x2, y2, x3, y3) then return true end
    if o2 == 0 and on_segment(x1, y1, x2, y2, x4, y4) then return true end
    if o3 == 0 and on_segment(x3, y3, x4, y4, x1, y1) then return true end
    if o4 == 0 and on_segment(x3, y3, x4, y4, x2, y2) then return true end

    return false
end

--- @brief
function rt.AABB:intersects(x1, y1, x2, y2)
    local x, y, w, h = self.x, self.y, self.width, self.height
    if  _contains(x1, y1, x, y, w, h) or
        _contains(x2, y2, x, y, w, h) or
        _intersects(x1, y1, x2, y2, x + 0, y + 0, x + w, y + 0) or
        _intersects(x1, y1, x2, y2, x + w, y + 0, x + w, y + h) or
        _intersects(x1, y1, x2, y2, x + w, y + h, x + 0, y + h) or
        _intersects(x1, y1, x2, y2, x + 0, y + h, x + 0, y + 0)
    then
        return true
    end

    return false
end
