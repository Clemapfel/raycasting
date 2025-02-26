--- @class b2.BodyType
b2.BodyType = meta.enum("PhysicsBodyType", {
    STATIC = box2d.b2_staticBody,
    KINEMATIC = box2d.b2_kinematicBody,
    DYNAMIC = box2d.b2_dynamicBody
})

--- @class b2.Body
b2.Body = meta.class("PhysicsBody")

--- @brief
function b2.Body:instantiate(world, type, position_x, position_y, automatic_mass)
    meta.assert_typeof(world, "PhysicsWorld", 1)
    meta.assert_enum_value(type, b2.BodyType)
    meta.assert_typeof(position_x, "Number", 3)
    meta.assert_typeof(position_x, "Number", 4)

    local def = box2d.b2DefaultBodyDef()
    def.type = type
    def.position = b2.Vec2(position_x * B2_PIXEL_TO_METER, position_y * B2_PIXEL_TO_METER)
    if automatic_mass ~= nil then
        meta.assert_typeof(automatic_mass, "Boolean", 5)
        def.automaticMass = automatic_mass
    end

    def.allowFastRotation = true

    self._native = ffi.gc(box2d.b2CreateBody(world._native, def), box2d.b2DestroyBody)
end

--- @brief
function b2.Body._create_from_native(native)
    local instance = setmetatable({}, meta.get_instance_metatable(b2.Body))
    instance._native = native
    return instance
end

--- @brief
function b2.Body:destroy()
    box2d.b2DestroyBody(self._native)
end

--- @brief
function b2.Body:get_n_shapes()
    return box2d.b2Body_GetShapeCount(self._native)
end

--- @brief
--- @return Table<b2.Shape>
function b2.Body:get_shapes()
    local n = box2d.b2Body_GetShapeCount(self._native)
    local shapes = ffi.new("b2ShapeId[" .. n .. "]")
    local _ = box2d.b2Body_GetShapes(self._native, shapes, n)
    local out = {}
    for i = 1, n do
        table.insert(out, b2.Shape._create_from_native(shapes[i-1]))
    end
    return out
end

--- @brief
function b2.Body:get_type()
    return box2d.b2Body_GetType(self._native)
end

--- @brief
function b2.Body:set_type(type)
    box2d.b2Body_SetType(self._native, type)
end

--- @brief
function b2.Body:get_world_point(local_x, local_y)
    local scale_down = B2_PIXEL_TO_METER
    local out = box2d.b2Body_GetWorldPoint(self._native, b2.Vec2(local_x * scale_down, local_y * scale_down))
    local scale_up = B2_METER_TO_PIXEL
    return out.x * scale_up, out.y * scale_up
end

--- @brief
function b2.Body:get_world_points(local_x, local_y, ...)
    local scale_down = B2_PIXEL_TO_METER
    local scale_up = B2_METER_TO_PIXEL
    local points = {local_x, local_y, ...}
    local out = {}
    for i = 1, #points, 2 do
        local vec2 = box2d.b2Body_GetWorldPoint(self._native, b2.Vec2(points[i] * scale_down, points[i+1] * scale_down))
        table.insert(out, vec2.x * scale_up)
        table.insert(out, vec2.y * scale_up)
    end
    return table.unpack(out)
end

--- @brief
function b2.Body:get_local_point(local_x, local_y)
    local scale = B2_METER_TO_PIXEL
    local out = box2d.b2Body_GetLocalPoint(self._native, b2.Vec2(local_x, local_y))
    return out.x * scale, out.y * scale
end

--- @brief
function b2.Body:get_local_points(local_x, local_y, ...)
    local scale_down = B2_PIXEL_TO_METER
    local scale_up = B2_METER_TO_PIXEL
    local points = {local_x, local_y, ...}
    local out = {}
    for i = 1, #points, 2 do
        local vec2 = box2d.b2Body_GetLocalPoint(self._native, b2.Vec2(points[i] * scale_down, points[i+1] * scale_down))
        table.insert(out, vec2.x * scale_up)
        table.insert(out, vec2.y * scale_up)
    end
    return table.unpack(out)
end

--- @brief
function b2.Body:set_centroid(point_x, point_y)
    local scale = B2_PIXEL_TO_METER
    local current = box2d.b2Body_GetTransform(self._native)
    if point_x ~= nil then current.p.x = point_x * scale end
    if point_y ~= nil then current.p.y = point_y * scale end
    box2d.b2Body_SetTransform(self._native, current.p, current.q)
end

--- @brief
function b2.Body:get_centroid(local_offset_x, local_offset_y)
    if local_offset_x == nil then local_offset_x = 0 end
    if local_offset_y == nil then local_offset_y = 0 end
    local scale_down = B2_PIXEL_TO_METER
    local scale_up = B2_METER_TO_PIXEL
    local out = box2d.b2Body_GetWorldPoint(self._native, b2.Vec2(local_offset_x * scale_down, local_offset_y * scale_down))
    return out.x * scale_up, out.y * scale_up
end

--- @brief
function b2.Body:teleport(x, y)
    local scale = B2_PIXEL_TO_METER
    box2d.b2Body_SetTransform(self._native, b2.Vec2(x * scale, y * scale), box2d.b2Body_GetRotation(self._native))
end

--- @brief
function b2.Body:set_angle(angle_rad)
    local transform = box2d.b2Body_GetTransform(self._native)
    transform.q.c = math.cos(angle_rad)
    transform.q.s = math.sin(angle_rad)
    box2d.b2Body_SetTransform(self._native, transform.p, transform.q)
end

--- @brief
function b2.Body:get_angle()
    local transform = box2d.b2Body_GetTransform(self._native)
    return math.atan(transform.q.s, transform.q.c)
end

--- @brief
function b2.Body:set_rotation_fixed(b)
    box2d.b2Body_SetFixedRotation(self._native, b)
end

--- @brief
function b2.Body:get_rotation_fixed()
    return box2d.b2Body_IsFixedRotation(self._native)
end

local max_value = 10e7 -- clamp to avoid float32 overflow

--- @brief
function b2.Body:set_linear_velocity(x, y)
    local scale = B2_PIXEL_TO_METER
    if x == NAN then x = 0 end
    if y == NAN then y = 0 end
    x = x * scale
    y = y * scale
    if x > max_value then x = max_value end
    if y > max_value then y = max_value end
    box2d.b2Body_SetLinearVelocity(self._native, b2.Vec2(x, y))
end

--- @brief
function b2.Body:get_linear_velocity()
    local scale = B2_METER_TO_PIXEL
    local vec2 = box2d.b2Body_GetLinearVelocity(self._native)
    return vec2.x * scale, vec2.y * scale
end

--- @brief
function b2.Body:set_angular_velocity(value)
    if value == NAN then value = 0 end
    if value > max_value then value = max_value end
    box2d.b2Body_SetAngularVelocity(self._native, value)
end

--- @brief
function b2.Body:get_angular_velocity()
    return box2d.b2Body_GetAngularVelocity()
end

--- @brief
function b2.Body:apply_force(force_x, force_y, local_point_x, local_point_y, should_wake_up_body)
    local scale = B2_PIXEL_TO_METER
    if should_wake_up_body == nil then should_wake_up_body = true end
    if local_point_x == nil then local_point_x = 0 end
    if local_point_y == nil then local_point_y = 0 end
    if force_x == NAN then force_x = 0 end
    if force_y == NAN then force_y = 0 end
    force_x = force_x * scale
    force_y = force_y * scale
    if force_x > max_value then force_x = max_value end
    if force_y > max_value then force_y = max_value end
    box2d.b2Body_ApplyForce(self._native,
        b2.Vec2(force_x, force_y),
        b2.Vec2(local_point_x * scale, local_point_y * scale),
        should_wake_up_body
    )
end

--- @brief
function b2.Body:apply_torque(value, should_wake_up_body)
    if should_wake_up_body == nil then should_wake_up_body = true end
    value = value * B2_PIXEL_TO_METER * B2_PIXEL_TO_METER
    if value == NAN then value = 0 end
    if value > max_value then value = max_value end
    box2d.b2Body_ApplyTorque(self._native, value, should_wake_up_body)
end

--- @brief
function b2.Body:apply_linear_impulse(impulse_x, impulse_y, should_wake_up_body)
    if should_wake_up_body == nil then should_wake_up_body = true end
    local scale = B2_PIXEL_TO_METER
    impulse_x = impulse_x * scale
    impulse_y = impulse_y * scale
    if impulse_x == NAN then impulse_x = 0 end
    if impulse_y == NAN then impulse_y = 0 end

    box2d.b2Body_ApplyLinearImpulseToCenter(self._native,
        b2.Vec2(impulse_x, impulse_y),
        should_wake_up_body
    )
end

--- @brief
function b2.Body:apply_angular_impulse(value, should_wake_up_body)
    if should_wake_up_body == nil then should_wake_up_body = true end
    local scale = B2_PIXEL_TO_METER * B2_PIXEL_TO_METER
    if value == NAN then value = 0 end
    if value > max_value then value = max_value end
    box2d.b2Body_ApplyTorque(self._native, value, should_wake_up_body)
end

--- @brief
function b2.Body:get_mass()
    return box2d.b2Body_GetMass(self._native)
end

--- @brief
function b2.Body:override_mass_data(mass, center_x, center_y, rotational_inertia)
    local scale = B2_PIXEL_TO_METER
    if mass == NAN then mass = 0 end
    if mass > max_value then mass = max_value end
    box2d.b2Body_SetMassData(self._native, ffi.typeof("b2MassData")(
        mass,
        b2.Vec2(center_x * scale, center_y * scale),
        rotational_inertia
    ))
    box2d.b2Body_SetAutomaticMass(self._native, false);
end

--- @brief
function b2.Body:set_mass(mass)
    local current = box2d.b2Body_GetMassData(self._native)
    current.mass = mass
    if mass > max_value then mass = max_value end
    box2d.b2Body_SetMassData(self._native, current)
    box2d.b2Body_SetAutomaticMass(self._native, false)
end

--- @brief
function b2.Body:set_linear_damping(value)
    if value < 0 then value = 0 end
    if value > max_value then value = max_value end
    box2d.b2Body_SetLinearDamping(self._native, value)
end

--- @brief
function b2.Body:get_linear_damping()
    return box2d.b2Body_GetLinearDamping(self._native)
end

--- @brief
function b2.Body:set_angular_damping(value)
    box2d.b2Body_SetAngularDamping(self._native, value)
end

--- @brief
function b2.Body:get_angular_damping()
    return box2d.b2Body_GetAngularDamping(self._native)
end

--- @brief
function b2.Body:set_gravity_scale(x)
    box2d.b2Body_SetGravityScale(self._native, x)
end

--- @brief
function b2.Body:get_gravity_scale()
    return box2d.b2Body_GetGravityScale(self._native)
end

--- @brief
function b2.Body:set_is_bullet(b)
    box2d.b2Body_SetBullet(self._native, b)
end

--- @brief
function b2.Body:get_is_bullet()
    return box2d.b2Body_IsBullet()
end

--- @brief
function b2.Body:set_collision_group(group)
    local n = box2d.b2Body_GetShapeCount(self._native)
    local shapes = ffi.new("b2ShapeId*[" .. n .. "]")
    local _ = box2d.b2Body_GetShapes(self._native, shapes, n)

    local filter = box2d.b2DefaultFilter()
    if group == b2.CollisionGroup.ALL then
        filter.categoryBits = 0xFFFF
        filter.maskBits = 0xFFFF
        filter.groupIndex = 0
    elseif group == b2.CollisionGroup.NONE then
        filter.categoryBits = 0x0000
        filter.maskBits = 0x0000
        filter.groupIndex = 0
    else
        filter.categoryBits = group
        filter.maskBits = group
        filter.groupindex = 0
    end

    for i = 1, n do
        local shape = shapes[i -1]
        box2d.b2Shape_SetFilter(shape, filter)
    end
end

--- @brief
function b2.Body:draw()
    local centroid_x, centroid_y = self:get_centroid()
    local angle = self:get_angle()

    love.graphics.push()
    love.graphics.translate(centroid_x, centroid_y)
    love.graphics.rotate(angle)
    for shape in values(self:get_shapes()) do
        shape:draw()
    end
    love.graphics.pop()
end