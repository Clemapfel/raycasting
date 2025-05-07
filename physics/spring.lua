--- @class b2.Spring
b2.Spring = meta.class("Spring")

--- @brief
function b2.Spring:instantiate(body_a, body_b, x1, y1, x2, y2)
    local ax, ay = body_a:get_position()
    local bx, by = body_b:get_position()
    meta.install(self, {
        _body_a = body_a,
        _body_b = body_b,
        _x1 = x1 - ax,
        _y1 = y1 - ay,
        _x2 = x2 - bx,
        _y2 = y2 - by,

        _is_disabled = false
    })

    self:_initialize()
end

local eps = 10e-4

--- @brief
function b2.Spring:_initialize()
    local ax, ay = self._body_a:get_position()
    local bx, by = self._body_b:get_position()

    local x1, y1 = self._x1 + ax, self._y1 + ay
    local x2, y2 = self._x2 + bx, self._y2 + by
    local distance = math.distance(x1, y1, x2, y2)

    meta.install(self, {
        _prismatic_joint = love.physics.newPrismaticJoint(
            self._body_a:get_native(),
            self._body_b:get_native(),
            x1, y1,
            x2 - x1, y2 - y1,
            false
        ),

        _distance_joint = love.physics.newRopeJoint(
            self._body_a:get_native(),
            self._body_b:get_native(),
            x1, y1,
            x2, y2,
            distance,
            false
        )

    })

    self._prismatic_joint:setLimitsEnabled(true)
    self._max_distance = distance
    self._prismatic_joint:setLimits(distance - eps, distance)
    self._prismatic_joint:setMotorEnabled(true)
end

--- @brief
function b2.Spring:get_distance()
    if self._is_disabled then return 0 end
    return math.abs(self._prismatic_joint:getJointTranslation())
end

--- @brief
function b2.Spring:get_max_distance()
    return self._max_distance
end

--- @brief
function b2.Spring:set_max_distance(distance)
    self._max_distance = distance
    self._prismatic_joint:setLimits(distance - eps, distance)
    self._distance_joint:setMaxLength(distance)
end

--- @brief
function b2.Spring:get_force()
    return self._prismatic_joint:getJointSpeed()
end
