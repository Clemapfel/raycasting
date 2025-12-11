--- @class b2.Spring
b2.Spring = meta.class("Spring")

--- @brief
function b2.Spring:instantiate(body_a, body_b, x1, y1, x2, y2, target_distance)
    local ax, ay = body_a:get_position()
    local bx, by = body_b:get_position()
    meta.install(self, {
        _body_a = body_a,
        _body_b = body_b,
        _x1 = x1 - ax,
        _y1 = y1 - ay,
        _x2 = x2 - bx,
        _y2 = y2 - by,

        _lower_limit = 0,
        _upper_limit = 0,
        _target_distance = target_distance or math.distance(x1, y1, x2, y2),
        _is_disabled = false,

        _stiffness = 0,
        _damping = 0
    })

    self:_initialize()
end

--- @brief
function b2.Spring:_initialize()
    local ax, ay = self._body_a:get_position()
    local bx, by = self._body_b:get_position()

    local x1, y1 = self._x1 + ax, self._y1 + ay
    local x2, y2 = self._x2 + bx, self._y2 + by
    local distance = math.distance(x1, y1, x2, y2)

    local axis_x, axis_y = math.normalize(x2 - x1, y2 - y1)

    meta.install(self, {
        _prismatic_joint = love.physics.newPrismaticJoint(
            self._body_a:get_native(),
            self._body_b:get_native(),
            x1, y1,
            axis_x, axis_y,
            false
        )
    })

    self._prismatic_joint:setLimitsEnabled(true)
    self._prismatic_joint:setMotorEnabled(false)
    self._prismatic_joint:setLimits(-self._lower_limit, self._upper_limit)
    self._max_distance = distance
end

--- @brief
function b2.Spring:get_distance()
    if self._is_disabled then return 0 end
    return math.abs(self._prismatic_joint:getJointTranslation())
end

--- @brief
function b2.Spring:set_tolerance(lower, upper)
    if upper == nil then upper = lower end
    self._lower_limit = lower
    self._upper_limit = upper
    self._prismatic_joint:setLimits(self._lower_limit, self._upper_limit)
end

--- @brief
function b2.Spring:get_force()
    return self._prismatic_joint:getJointSpeed()
end

--- @brief
function b2.Spring:set_enabled(b)
    self._prismatic_joint:setLimitsEnabled(b)
    self._is_disabled = not b
end


--- @brief the higher, the more spring resists being stretched or compressed
function b2.Spring:set_stiffness(t)
    self._stiffness = t
end

--- @brief
function b2.Spring:get_stiffness()
    return self._stiffness
end

--- @brief how fast energy dissapates
function b2.Spring:set_damping(t)
    self._damping = t
end

--- @brief
function b2.Spring:get_damping()
    return self._damping
end

--- @brief
function b2.Spring:update(delta)
    if self._is_disabled then return end

    local body_a = self._body_a:get_native()
    local body_b = self._body_b:get_native()
    local ax, ay = self._body_a:get_position()
    local bx, by = self._body_b:get_position()

    -- anchors
    local x1, y1 = self._x1 + ax, self._y1 + ay
    local x2, y2 = self._x2 + bx, self._y2 + by

    local dx, dy = (x2 - x1), (y2 - y1)
    local dist = math.distance(x1, y1, x2, y2)
    if dist <= math.eps then return end -- avoid division by zero

    local nx, ny = math.normalize(dx, dy)

    -- extension relative to target distance, with deadzone from tolerance
    local extension = dist - (self._target_distance or 0)
    local x_error = 0
    if extension > (self._upper_limit or 0) then
        x_error = extension - (self._upper_limit or 0)
    elseif extension < -(self._lower_limit or 0) then
        x_error = extension + (self._lower_limit or 0)
    else
        x_error = 0
    end

    -- relative velocity along the axis
    local v1x, v1y = body_a:getLinearVelocityFromWorldPoint(x1, y1)
    local v2x, v2y = body_b:getLinearVelocityFromWorldPoint(x2, y2)
    local relative_velocity = (v2x - v1x) * nx + (v2y - v1y) * ny

    local k = self._stiffness
    local c = self._damping or 1

    if k == 0 and c == 0 then return end

    -- force scalar along axis: F = -k*x - c*v
    local f = (-k * x_error) + (-c * relative_velocity)

    -- apply equal/opposite forces at anchor points
    local fx, fy = f * nx, f * ny

    body_a:applyForce(fx, fy, x1, y1)
    body_b:applyForce(-fx, -fy, x2, y2)
end