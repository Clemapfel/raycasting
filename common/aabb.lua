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

--- @brief
function rt.AABB:intersects(x1, y1, x2, y2)
    local x, y, w, h = self:unpack()
    local right = x + w
    local bottom = y + h

    -- Fast case 1: Check if either endpoint is inside AABB
    if (x1 >= x and x1 <= right and y1 >= y and y1 <= bottom) or
        (x2 >= x and x2 <= right and y2 >= y and y2 <= bottom) then
        return true
    end

    -- Fast case 2: Check if segment is entirely outside AABB bounds
    if (x1 < x and x2 < x) or
        (x1 > right and x2 > right) or
        (y1 < y and y2 < y) or
        (y1 > bottom and y2 > bottom) then
        return false
    end

    -- Parameterized line segment: P(t) = (x1, y1) + t * (dx, dy) where t ∈ [0,1]
    local dx = x2 - x1
    local dy = y2 - y1

    local tmin = 0.0
    local tmax = 1.0

    -- Check X slabs
    if dx ~= 0 then
        local tx1 = (x - x1) / dx
        local tx2 = (right - x1) / dx

        -- Handle infinity: if result is -inf or +inf, it means the slab extends infinitely
        -- -inf means entry is at negative infinity (always entered)
        -- +inf means exit is at positive infinity (never exited in that direction)
        if dx > 0 then
            -- Moving right: tx1 is entry, tx2 is exit
            if tx1 ~= -math.huge then
                tmin = math.max(tmin, tx1)
            end
            if tx2 ~= math.huge then
                tmax = math.min(tmax, tx2)
            end
        else
            -- Moving left: tx2 is entry, tx1 is exit
            if tx2 ~= -math.huge then
                tmin = math.max(tmin, tx2)
            end
            if tx1 ~= math.huge then
                tmax = math.min(tmax, tx1)
            end
        end

        if tmin > tmax then
            return false
        end
    else
        -- dx == 0: segment is vertical, check if X is within bounds
        if x1 < x or x1 > right then
            return false
        end
    end

    -- Check Y slabs
    if dy ~= 0 then
        local ty1 = (y - y1) / dy
        local ty2 = (bottom - y1) / dy

        if dy > 0 then
            -- Moving down: ty1 is entry, ty2 is exit
            if ty1 ~= -math.huge then
                tmin = math.max(tmin, ty1)
            end
            if ty2 ~= math.huge then
                tmax = math.min(tmax, ty2)
            end
        else
            -- Moving up: ty2 is entry, ty1 is exit
            if ty2 ~= -math.huge then
                tmin = math.max(tmin, ty2)
            end
            if ty1 ~= math.huge then
                tmax = math.min(tmax, ty1)
            end
        end

        if tmin > tmax then
            return false
        end
    else
        -- dy == 0: segment is horizontal, check if Y is within bounds
        if y1 < y or y1 > bottom then
            return false
        end
    end

    return true
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