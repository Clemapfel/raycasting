--- @class b2.Spring
b2.Spring = meta.class("Spring")

--- @brief
function b2.Spring:instantiate(body_a, body_b, x1, y1, x2, y2)
    meta.install(self, {
        _prismatic_joint = love.physics.newPrismaticJoint(
            body_a:get_native(),
            body_b:get_native(),
            x1, y1,
            x2 - x1, y2 - y1,
            false
        ),

        _distance_joint = love.physics.newDistanceJoint(
            body_a:get_native(),
            body_b:get_native(),
            x1, y1,
            x2, y2,
            false
        )
    })

    self._a_native = body_a:get_native()
    self._b_native = body_b:get_native()
    self._ax, self._ay = body_a:get_native():getLocalPoint(x1, y1)
    self._bx, self._by = body_b:get_native():getLocalPoint(x2, y2)

    self._prismatic_joint:setLimitsEnabled(true)
    local distance = math.distance(x1, y1, x2, y2)
    self._prismatic_joint:setLimits(distance, distance)

    self._distance_joint:setStiffness(1000)
end

--- @brief
function b2.Spring:get_distance()
    return math.abs(self._prismatic_joint:getJointTranslation())
end