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
        _is_disabled = false
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
        ),

        _distance_joint = love.physics.newRopeJoint(
            self._body_a:get_native(),
            self._body_b:get_native(),
            x1, y1,
            x2, y2,
            self._target_distance,
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
    --self._distance_joint:setMaxLength(self._upper_limit)
end

--- @brief

--- @brief
function b2.Spring:get_force()
    return self._prismatic_joint:getJointSpeed()
end
