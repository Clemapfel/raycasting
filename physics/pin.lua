--- @class b2.Pin
b2.Pin = meta.class("Pin")

--- @brief
function b2.Pin:instantiate(body_a, body_b, x, y)
    self._native = love.physics.newWeldJoint(
        body_a:get_native(),
        body_b:get_native(),
        x, y,
        false
    )
end