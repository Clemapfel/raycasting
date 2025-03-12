--- @class b2.World
b2.World = meta.class("PhysicsWorld")

--- @brief
function b2.World:instantiate(width, height, ...)
    meta.assert(width, "Number", height, "Number")
    self._native = love.physics.newWorld(0, 0)
end

--- @brief
function b2.World:set_gravity(x, y)
    self._native:setGravity(x, y)
end

--- @brief
function b2.World:get_gravity()
    return self._native:getGravity()
end

local _elapsed = 0
local _step = 1 / 120

--- @brief
function b2.World:update(delta)
    _elapsed = _elapsed + delta
    while _elapsed > _step do
        self._native:update(_step)
        _elapsed = _elapsed - _step
    end
end

--- @brief
function b2.World:draw()
    for body in values(self._native:getBodies()) do
        body:getUserData():draw()
    end
end

--- @brief
function b2.World:cast_ray(origin_x, origin_y, direction_x, direction_y)
    local min_fraction = math.huge
    local x_out, y_out, normal_x_out, normal_y_out

    local scale = 10e9
    local shape, x, y, nx, ny, fraction = self._native:rayCastClosest(
        origin_x, origin_y,
        origin_x + direction_x * scale,
        origin_y + direction_y * scale
    )

    return x, y, nx, ny
end