--- @class b2.Body
--- @signal collision (b2.Body, b2.Body, x, y, normal_x, normal_y) -> nil
b2.Body = meta.class("PhysicsBody")
meta.add_signals(b2.Body, "collision_start", "collision_end")

--- @class b2.BodyType
b2.BodyType = meta.enum("PhysicsBodyType", {
    STATIC = "static",
    KINEMATIC = "kinematic",
    DYNAMIC = "dynamic"
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

    meta.install(self, {
        _native = love.physics.newBody(world._native, x, y, type),
        _shapes = {},
        _tags = {}, -- Set<String>
        _is_sensor = false
    })

    local shapes
    if meta.typeof(shape) == "Table" then
        shapes = shape
    else
        shapes = { shape, ... }
    end

    for non_native in values(shapes) do
        local native = non_native:_add_to_body(self._native)
        native:setUserData(non_native)
    end
    --self._native:setMass(1)
    self._native:setUserData(self)
end

--- @brief
function b2.Body:get_position()
    return self._native:getPosition()
end

--- @brief
function b2.Body:set_position(x, y)
    self._native:setPosition(x, y)
end

--- @brief
function b2.Body:get_rotation()
    return self._native:getAngle()
end

--- @brief
function b2.Body:set_rotation(angle)
    self._native:setAngle(angle)
end

--- @brief
function b2.Body:get_linear_velocity()
    return self._native:getLinearVelocity()
end
b2.Body.get_velocity = b2.Body.get_linear_velocity

--- @brief
function b2.Body:set_linear_velocity(dx, dy)
    self._native:setLinearVelocity(dx, dy)
end
b2.Body.set_velocity = b2.Body.set_linear_velocity

--- @brief
function b2.Body:set_angular_velocity(value)
    self._native:setAngularVelocity(value)
end

--- @brief
function b2.Body:get_angular_velocity(value)
   return self._native:getAngularVelocity()
end

--- @brief
function b2.Body:set_mass(mass)
    self._native:setMass(mass)
end

--- @brief
function b2.Body:get_mass()
    return self._native:getMass()
end

--- @brief
function b2.Body:draw()
    love.graphics.push()
    love.graphics.translate(self._native:getPosition())
    love.graphics.rotate(self._native:getAngle())

    for shape in values(self._native:getShapes()) do
        shape:getUserData():draw()
    end

    love.graphics.pop()
end

--- @brief
function b2.Body:set_is_solid(b)
    self._is_solid = b
end

--- @brief
function b2.Body:get_is_solid()
    return self._is_solide
end

--- @brief
function b2.Body:set_is_enabled(b)
    self._native:setActive(b)
end

--- @brief
function b2.Body:get_is_enabled()
    return self._native:getActive()
end

--- @brief
function b2.Body:set_is_sensor(b)
    self._is_sensor = b
    for shape in values(self._native:getShapes()) do
        shape:setSensor(b)
    end
end

--- @brief
function b2.Body:get_is_sensor()
    return self._is_sensor
end

--- @brief
function b2.Body:add_tag(tag)
    self._tags[tag] = true
end

--- @brief
function b2.Body:remove_tag(tag)
    self._tags[tag] = false
end

--- @brief
function b2.Body:has_tag(tag)
    return self._tags[tag]
end
