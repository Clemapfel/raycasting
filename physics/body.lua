--- @class b2.Body
--- @signal collision_start (b2.Body, b2.Body, normal_x, normal_y, x1, y1, x2, y2) -> nil
--- @signal collision_end (b2.Body, b2.Body, normal_x, normal_y, x1, y1, x2, y2) -> nil
--- @signal activate (b2.Body) -> nil
b2.Body = meta.class("PhysicsBody")
meta.add_signals(b2.Body,
    "collision_start",
    "collision_end",
    "activate"
)

--- @class b2.BodyType
b2.BodyType = meta.enum("PhysicsBodyType", {
    STATIC = "static",
    KINEMATIC = "kinematic",
    DYNAMIC = "dynamic"
})

--- @class b2.CollisionGroup
b2.CollisionGroup = meta.enum("PhysicsCollisionGroup", {
    NONE = 0x0000,
    ALL = 0xFFFF,
    DEFAULT = 1,
    GROUP_01 = bit.lshift(1, 0),
    GROUP_02 = bit.lshift(1, 1),
    GROUP_03 = bit.lshift(1, 2),
    GROUP_04 = bit.lshift(1, 3),
    GROUP_05 = bit.lshift(1, 4),
    GROUP_06 = bit.lshift(1, 5),
    GROUP_07 = bit.lshift(1, 6),
    GROUP_08 = bit.lshift(1, 7),
    GROUP_09 = bit.lshift(1, 8),
    GROUP_10 = bit.lshift(1, 9),
    GROUP_11 = bit.lshift(1, 10),
    GROUP_12 = bit.lshift(1, 11),
    GROUP_13 = bit.lshift(1, 12),
    GROUP_14 = bit.lshift(1, 13),
    GROUP_15 = bit.lshift(1, 14),
    GROUP_16 = bit.lshift(1, 15),
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
        _world = world,
        _native = love.physics.newBody(world._native, x, y, type),
        _shapes = {},
        _tags = {}, -- Set<String>
        _is_sensor = false,
        _user_data = nil,

        _collision_group = b2.CollisionGroup.DEFAULT,
        _collides_with = b2.CollisionGroup.ALL
    })

    -- data needed for predicted position
    self._current_timestamp = love.timer.getTime()
    self._last_timestamp = love.timer.getTime()
    self._last_velocity_x, self._last_velocity_y = self._native:getLinearVelocity()
    self._last_x, self._last_y = self._native:getPosition()
    self._current_x, self._current_y = self._native:getPosition()

    local shapes
    if meta.typeof(shape) == "Table" then
        shapes = shape
    else
        shapes = { shape, ... }
    end

    for non_native in values(shapes) do
        local native = non_native:_add_to_body(self._native)
        native:setUserData(non_native)
        self:_update_filter_data(native)
    end

    self._native:setUserData(self)
end

--- @brief
function b2.Body:get_position()
    return self._native:getPosition()
end

--- @brief
function b2.Body:set_position(x, y)
    self._world:_notify_position_changed(self, x, y)
end

--- @brief
function b2.Body:get_rotation()
    return self._native:getAngle()
end

--- @brief [internal]
function b2.Body:_post_update_notify(step)
    self._last_timestamp = self._current_timestamp
    self._last_x, self._last_y = self._current_x, self._current_y

    self._current_timestamp = self._last_timestamp + step
    self._current_x, self._current_y = self._native:getPosition()

    if self._current_timestamp - self._last_timestamp == 0 then
        debugger.break_here()
    end

    self._last_velocity_x, self._last_velocity_y = self._native:getLinearVelocity()
end

--- @brief get framerate-independent position
function b2.Body:get_predicted_position()
    local dt = self._current_timestamp - self._last_timestamp
    if dt == 0 then
        return self._native:getPosition()
    end

    local dx = self._current_x - self._last_x
    local dy = self._current_y - self._last_y

    local x, y = self._current_x, self._current_y
    local delta = love.timer.getTime() - self._current_timestamp

    local vx = dx * dt
    local vy = dy * dt

    -- safeguard when teleporting
    if vx < 0 then
        vx = math.max(vx, self._last_velocity_x)
    else
        vx = math.min(vx, self._last_velocity_x)
    end

    if vy < 0 then
        vy = math.max(vy, self._last_velocity_y)
    else
        vy = math.min(vy, self._last_velocity_y)
    end

    return x + vx * delta, y + vy * delta
end

--- @brief
function b2.Body:get_center_of_mass()
    local mean_x, mean_y, n = 0, 0, 0
    local tx, ty = self._native:getPosition()
    local angle = self._native:getAngle()
    for shape in values(self._native:getShapes()) do
        local x, y, _, _ = shape:getMassData()
        mean_x = mean_x + x
        mean_y = mean_y + y
        n = n + 1
    end
    return mean_x / n + tx, mean_y / n + ty
end

--- @brief
function b2.Body:set_rotation(angle)
    self._world:_notify_rotation_changed(self, angle)
end

--- @brief
function b2.Body:get_linear_velocity()
    return self._native:getLinearVelocity()
end
b2.Body.get_velocity = b2.Body.get_linear_velocity

--- @brief
function b2.Body:set_linear_velocity(dx, dy)
    if dy == nil then dy = dx end
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
function b2.Body:apply_force(dx, dy)
    self._native:applyForce(dx, dy)
end

--- @brief
function b2.Body:apply_linear_impulse(dx, dy)
    self._native:applyLinearImpulse(dx, dy)
end

--- @brief
function b2.Body:set_mass(mass)
    self._native:setMass(mass)
end

--- @brief
function b2.Body:set_friction(friction)
    for shape in values(self._native:getShapes()) do
        shape:setFriction(friction)
    end
end

--- @brief
function b2.Body:set_restitution(value)
    for shape in values(self._native:getShapes()) do
        shape:setRestitution(value)
    end
end

--- @brief
function b2.Body:get_mass()
    return self._native:getMass()
end

--- @brief
function b2.Body:draw()
    love.graphics.push()
    love.graphics.translate(self:get_position())
    love.graphics.rotate(self._native:getAngle())

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 1, 1, 1)
    for shape in values(self._native:getShapes()) do
        local userdata = shape:getUserData()
        if userdata ~= nil then
            userdata:draw()
        end
    end

    love.graphics.pop()
end

--- @brief
function b2.Body:set_is_enabled(b)
    self._native:setActive(b)
end

--- @brief
function b2.Body:get_is_enabled()
    return self._native:isActive()
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
    self._tags[tag] = nil
end

--- @brief
function b2.Body:has_tag(tag)
    return self._tags[tag] == true
end

--- @brief
function b2.Body:set_is_rotation_fixed(b)
    meta.assert(b, "Boolean")
    self._native:setFixedRotation(b)
end

--- @brief
function b2.Body:get_is_rotation_fixed()
    return self._native:isFixedRotation()
end

--- @brief
function b2.Body:set_user_data(any)
    self._user_data = any
end

--- @brief
function b2.Body:get_user_data()
    return self._user_data
end

--- @brief
function b2.Body:_update_filter_data(shape)
    shape:setFilterData(self._collision_group, self._collides_with, 0)
end

--- @brief
function b2.Body:set_collision_group(...)
    local out = 0x0
    for i = 1, select("#", ...) do
        out = bit.bor(out, select(i, ...))
    end

    self._collision_group = out
    for shape in values(self._native:getShapes()) do
        self:_update_filter_data(shape)
    end
end

--- @brief
function b2.Body:get_collision_group()
    return self._collision_group
end

--- @brief
function b2.Body:set_collides_with(...)
    local n = select("#",  ...)
    local out = 0x0
    for i = 1, select("#", ...) do
        out = bit.bor(out, select(i, ...))
    end

    self._collides_with = out
    for shape in values(self._native:getShapes()) do
        self:_update_filter_data(shape)
    end
end

--- @brief
function b2.Body:set_does_not_collide_with(...)
    local n = select("#", ...)
    local out = self._collides_with
    for i = 1, n do
        out = bit.band(out, bit.bnot(select(i, ...)))
    end

    self._collides_with = out
    for shape in values(self._native:getShapes()) do
        self:_update_filter_data(shape)
    end
end

--- @brief
function b2.Body:destroy()
    self._native:destroy()
end

--- @brief
function b2.Body:get_shapes()
    local out = {}
    for shape in values(self._native:getShapes()) do
        table.insert(out, shape:getUserData())
    end
    return out
end

--- @brief
function b2.Body:get_native()
    return self._native
end

--- @brief
function b2.Body:get_type()
    return self._native:getType()
end
