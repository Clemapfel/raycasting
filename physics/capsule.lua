local _create_native = ffi.metatype("b2Capsule", {})

--- @class b2.Capsule
b2.Capsule = meta.class("PhysicsCapsule")

--- @brief
function b2.Capsule:instantiate(a_x, a_y, b_x, b_y, radius)
    meta.assert(
        a_x, "Number",
        a_y, "Number",
        b_x, "Number",
        b_y, "Number",
        radius, "Number"
    )

    local scale = B2_PIXEL_TO_METER
    self._native = _create_native(
        b2.Vec2(a_x * scale, a_y * scale),
        b2.Vec2(b_x * scale, b_y * scale),
        radius * scale
    )
end

--- @brief [internal]
function b2.Capsule._create_from_native(native)
    local instance = setmetatable({}, meta.get_instance_metatable(b2.Capsule))
    instance._native = native
    return instance
end

--- @brief
function b2.Capsule:get_centers()
    local scale = B2_METER_TO_PIXEL
    return
        self._native.center1.x * scale,
        self._native.center1.y * scale,
        self._native.center2.x * scale,
        self._native.center2.y * scale
end

--- @brief
function b2.Capsule:get_radius()
    return self._native.radius
end