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

    -- 1. Protect against NaN (Not-a-Number) values.
    -- In Lua, checking if a variable does not equal itself is the fastest way to check for NaN.
    if x1 ~= x1 or x2 ~= x2 or y1 ~= y1 or y2 ~= y2 or
        x ~= x or y ~= y or w ~= w or h ~= h then
        return false
    end

    local maxX = x + w
    local maxY = y + h

    -- 2. Infinity Clamping: To prevent intermediate math operations from evaluating
    -- to NaN (inf - inf) or overflowing a 64-bit float, we clamp massive coordinates
    -- to a safe upper bound (1e140). This preserves the mathematical slope/topology
    -- of infinite lines while guaranteeing stable SAT arithmetic.
    local huge = 3.4028234663852886e+38
    if x1 > huge then x1 = huge elseif x1 < -huge then x1 = -huge end
    if x2 > huge then x2 = huge elseif x2 < -huge then x2 = -huge end
    if y1 > huge then y1 = huge elseif y1 < -huge then y1 = -huge end
    if y2 > huge then y2 = huge elseif y2 < -huge then y2 = -huge end

    if x > huge then x = huge elseif x < -huge then x = -huge end
    if maxX > huge then maxX = huge elseif maxX < -huge then maxX = -huge end
    if y > huge then y = huge elseif y < -huge then y = -huge end
    if maxY > huge then maxY = huge elseif maxY < -huge then maxY = -huge end

    -- Recompute safe dimensions in case the AABB itself was initialized with math.huge
    w = maxX - x
    h = maxY - y

    -- 3. Early Out: X-Axis Bounding Box overlap test
    -- Standard ternary logic (`cond and A or B`) avoids the overhead of math.min/math.max function calls.
    local lMinX = x1 < x2 and x1 or x2
    local lMaxX = x1 > x2 and x1 or x2
    if lMaxX < x or lMinX > maxX then return false end

    -- 4. Early Out: Y-Axis Bounding Box overlap test
    local lMinY = y1 < y2 and y1 or y2
    local lMaxY = y1 > y2 and y1 or y2
    if lMaxY < y or lMinY > maxY then return false end

    -- 5. Exact Separation Test (SAT) on the Line's Normal
    -- Since we've already proven the line's bounding box overlaps the AABB's bounding box,
    -- we only need to test if the AABB intersects the infinite line extending from the segment.
    local vx = x2 - x1
    local vy = y2 - y1

    -- We multiply standard center-distance variables by 2 to completely avoid floating division.
    local tx = x1 + x2 - x - maxX
    local ty = y1 + y2 - y - maxY

    local cross = tx * vy - ty * vx
    if cross < 0 then cross = -cross end

    local abs_vx = vx < 0 and -vx or vx
    local abs_vy = vy < 0 and -vy or vy

    -- Check if the projected distance of the AABB exceeds the projected distance of the line center
    return cross <= (w * abs_vy + h * abs_vx)
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