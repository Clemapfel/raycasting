local _create_native = ffi.metatype("b2Circle", {})

--- @class b2.Circle
b2.Circle = meta.class("PhysicsCircle")

--- @brief
function b2.Circle:instantiate(radius, x, y)
    local scale = B2_PIXEL_TO_METER
    if x == nil then x = 0 end
    if y == nil then y = 0 end

    meta.assert(
        radius, "Number",
        x, "Number",
        y, "Number"
    )

    self._native = _create_native(
        b2.Vec2(x * scale, y * scale),
        radius * scale
    )
end

--- @brief [internal]
function b2.Circle._create_from_native(native)
    local instance = setmetatable({}, meta.get_instance_metatable(b2.Circle))
    instance._native = native
    return instance
end

--- @brief
function b2.Circle:get_radius()
    return self._native.radius * B2_METER_TO_PIXEL
end

--- @brief
function b2.Circle:get_center()
    local scale = B2_METER_TO_PIXEL
    return self._native.center.x * scale, self._native.center.y * scale
end