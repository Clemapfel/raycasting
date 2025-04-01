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
        )
    })

    self._prismatic_joint:setLimitsEnabled(true)
    local distance = math.distance(x1, y1, x2, y2)
    self._prismatic_joint:setLimits(distance, distance)
end

--- @brief
function b2.Spring:get_distance()
    return self._prismatic_joint:getJointTranslation()
end