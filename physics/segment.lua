local _create_native = ffi.metatype("b2Segment", {})

--- @class b2.Segment
b2.Segment = meta.class("PhysicsSegment")

--- @brief
function b2.Segment:instantiate(a_x, a_y, b_x, b_y)
    meta.assert(
        a_x, "Number",
        a_y, "Number",
        b_x, "Number",
        b_y, "Number"
    )

    local scale = B2_PIXEL_TO_METER
    self._native = _create_native(
        b2.Vec2(a_x * scale, a_y * scale),
        b2.Vec2(b_x * scale, b_y * scale)
    )
end

--- @brief [internal]
function b2.Segment._create_from_native(native)
    local instance = setmetatable({}, meta.get_instance_metatable(b2.Segment))
end

--- @brief
function b2.Segment:get_points()
    local scale = B2_METER_TO_PIXEL
    return self._native.center1.x * scale, self._native.center1.y * scale,
        self._native.center2.x * scale, self._native.center2.y * scale
end