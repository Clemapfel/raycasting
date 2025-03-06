--- @class b2.Body
b2.Body = meta.class("PhysicsBody")

--- @class b2.BodyType
b2.BodyType = meta.enum("PhysicsBodyType", {
    STATIC = "STATIC",
    KINEMATIC = "KINEMATIC",
    DYNAMIC = "DYNAMIC"
})

--- @brief
--- @param world b2.World
--- @param x Number
--- @param y Number
--- @param shape b2.Shape
--- @param ... b2.Shapes
function b2.Body:instantiate(world, type, x, y, shape, ...)
    meta.assert_enum_value(type, b2.BodyType)
    meta.assert(x, "Number", y, "Number")

    local shapes
    if meta.isa(shape, b2.Shape) then
        shapes = {shape, ...}
    else
        meta.assert_typeof(shape, "Table", 5)
        shapes = shape
    end

    local natives = {}
    local n_natives = 0
    for i, current_shape in ipairs(shapes) do
        assert(meta.isa(current_shape, b2.Shape), "In b2.Body: argument #" .. 3 + i .. ": expected `b2.Shape`, got `" .. meta.typeof(current_shape) .. "`")
        table.insert(natives, current_shape._native)
    end

    local group
    if n_natives > 1 then
        group = slick.newShapeGroup(
            table.unpack(natives)
        )
    else
        group = natives[1]
    end

    meta.install(self, {
        _transform = slick.newTransform(x, y),
        _shapes = shapes,
        _type = type,
        _world = world,
        _entity = world._native:add(self, x, y, group),
        _velocity_x = 0,
        _velocity_y = 0,
        _acceleration_x = 0,
        _acceleration_y = 0,

        _angular_velocity = 0,
        _angular_acceleration = 0,
        _mass = 0
    })

    self._world:_notify_body_added(self)

    if self._type == b2.BodyType.DYNAMIC then
        self._world:_notify_push_needed(self)
    end
end

--- @brief
function b2.Body:get_position()
    return self._transform.x, self._transform.y
end

--- @brief
function b2.Body:set_position(x, y)
    if x == self._transform.x or y == self._transform.y then return end
    self._transform:setTransform(x, y)
    self._world:_notify_transform_changed(self)
    self._world:_notify_push_needed(self)
end

--- @brief
function b2.Body:get_rotation()
    return self._transform.rotation
end

--- @brief
function b2.Body:set_rotation(angle)
    meta.assert(angle, "Number")
    self._transform:setTransform(nil, nil, angle)
    self._world:_notify_transform_changed(self)
end

--- @brief
function b2.Body:get_scale()
    return self._transform.scaleX, self._transform.scaleY
end

--- @brief
function b2.Body:set_scale(scale_x, scale_y)
    if scale_y == nil then scale_y = scale_x end
    meta.assert(scale_x, "Number", scale_y, "Number")
    self._transform:setTransform(nil, nil, nil, scale_x, scale_y)
    self._world:_notify_transform_changed(self)
end

--- @brief
function b2.Body:set_transform(x, y, angle, scale_x, scale_y, origin_x, origin_y)
    self._transform:setTransform(x, y, angle, scale_x, scale_y, origin_x, origin_y) -- nils handled in slick
    self._world:_notify_transform_changed(self)

    if (x ~= nil and x ~= self._transform.x) or (y ~= nil and y ~= self._transform.y) then
        self._world:_notify_push_needed(self)
    end
end

--- @brief
function b2.Body:get_linear_velocity()
    return self._velocity_x, self._velocity_y
end
b2.Body.get_velocity = b2.Body.get_linear_velocity

--- @brief
function b2.Body:set_linear_velocity(dx, dy)
    meta.assert(dx, "Number", dy, "Number")
    self._velocity_x, self._velocity_y = dx, dy
end
b2.Body.set_velocity = b2.Body.set_linear_velocity

--- @brief
function b2.Body:set_linear_acceleration(ax, ay)
    self._acceleration_x, self._acceleration_y = ax, ay
end

--- @brief
function b2.Body:get_linear_acceleration()
    return self._acceleration_x, self._acceleration_y
end

--- @brief
function b2.Body:set_angular_velocity(value)
    self._angular_velocity = value
end

--- @brief
function b2.Body:get_angular_velocity(value)
    return self._angular_velocity
end

--- @brief
function b2.Body:set_angular_acceleration(value)
    self._angular_acceleration = value
end

--- @brief
function b2.Body:get_angular_acceleration()
    return self._angular_acceleration
end

--- @brief
function b2.Body:set_mass(mass)
    self._mass = mass
end

--- @brief
function b2.Body:get_mass()
    return self._mass
end

--- @brief
function b2.Body:draw()
    for shape in values(self._shapes) do
        shape:draw(self._transform)
    end
end

--- @brief
function b2.Body:set_origin(x, y)
    self._transform:setTransform(nil, nil, nil, nil, nil, x, y)
    self._world:_notify_transform_changed(self)
end
