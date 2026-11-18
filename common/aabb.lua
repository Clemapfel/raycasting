--- @class rt.AABB
rt.AABB = meta.class("AABB")

--- @return rt.AABB
function rt.AABB:instantiate(other_or_x, y, width, height)
    if meta.isa(other_or_x, rt.AABB) then
        local other = other_or_x
        meta.assert(other, rt.AABB, y, mt.Nil, width, mt.Nil, height, mt.Nil)
        self:reformat(other:unpack())
    else
        local x = other_or_x
        if x == nil then x = 0 end
        if y == nil then y = 0 end
        if width == nil then width = 1 end
        if height == nil then height = width end

        meta.assert(x, mt.Number, y, mt.Number, width, mt.Number, height, mt.Number)

        self.x = x
        self.y = y
        self.width = width
        self.height = height
    end
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

--- @brief
function rt.AABB:contains(px, py)
    meta.assert(px, mt.Number, py, mt.Number)
    local x, y, w, h = self.x, self.y, self.width, self.height
    return px >= x and px <= x + w and py >= y and py <= y + h
end

--- @brief check if aabb overlaps another aabb
function rt.AABB:overlaps(x_or_aabb, y, width, height)
    local x
    if not meta.is_number(x_or_aabb) then
        x, y, width, height = x_or_aabb:unpack()
    else
        x = x_or_aabb
    end

    if self.x > x + width
        or x > self.x + self.width
        or self.y > y + height
        or y > self.y + self.height
    then
        return false
    end

    return true
end

--- @brief
function rt.AABB:equals(x_or_aabb, y, width, height)
    local x
    if not meta.is_number(x_or_aabb) then
        x, y, width, height = x_or_aabb:unpack()
    else
        x = x_or_aabb
    end

    return math.equals(self.x, x)
        and math.equals(self.y, y)
        and math.equals(self.width, width)
        and math.equals(self.height, height)
end