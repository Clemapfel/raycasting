--- @class rt.AABB
rt.AABB = meta.class("AABB")

--- @return rt.AABB
function rt.AABB:instantiate(x, y, width, height)
    meta.install(self, {
        x = x,
        y = y,
        width = width,
        height = height
    })
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
function rt.AABB:contains(x, y)
    return x >= self.x and x <= self.x + self.width and y >= self.y and y <= self.y + self.height
end
