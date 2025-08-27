--- @class b2.Body
--- @signal collision_start (b2.Body, b2.Body, normal_x, normal_y, x1?, y1?, x2?, y2?) -> nil
--- @signal collision_end (b2.Body, b2.Body, normal_x, normal_y) -> nil
--- @signal activate (b2.Body) -> nil
b2.Body = meta.class("PhysicsBody")
meta.add_signals(b2.Body,
    "collision_start",
    "collision_end",
    "destroy"
)

--- @class b2.BodyType
b2.BodyType = meta.enum("PhysicsBodyType", {
    STATIC = "static",
    KINEMATIC = "kinematic",
    DYNAMIC = "dynamic"
})

--- @class b2.CollisionGroup
b2.CollisionGroup = meta.enum("PhysicsCollisionGroup", {
    NONE = 0x0,
    ALL = bit.bnot(0x0),
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
        _collides_with = b2.CollisionGroup.ALL,

        _use_manual_velocity = false,
        _manual_velocity_x = 0,
        _manual_velocity_y = 0,

        _use_interpolation = false, -- false = extrapolation, cf. get_predicted_position

        _friction = 0,
        _collision_disabled = false,

        _last_x = x,
        _last_last_x = x,
        _last_y = y,
        _last_last_y = y
    })

    self._native:setSleepingAllowed(true)

    local shapes
    if meta.typeof(shape) == "Table" then
        shapes = shape
    else
        shapes = { shape, ... }
    end

    for non_native in values(shapes) do
        local native = non_native:_add_to_body(self._native)
        if native ~= nil then
            native:setUserData(non_native)
            self:_update_filter_data(native)
        end
    end

    self._native:setUserData(self)
end

--- @brief
function b2.Body:get_position()
    return self._native:getPosition()
end

local _position_callback = function(body, x, y)
    body:setPosition(body, x, y)
end

--- @brief
function b2.Body:set_position(x, y)
    if not pcall(_position_callback, self._native, x, y) then
        self._world:_notify_position_changed(self, x, y)
    end
    self._last_x, self._last_y = x, y
end

local _angle_callback = function(body, angle)
    body:setAngle(body, angle)
end

--- @brief
function b2.Body:set_rotation(angle)
    if not pcall(_angle_callback, self._native, angle) then
        self._world:_notify_rotation_changed(self, angle)
    end
end

--- @brief
function b2.Body:get_rotation()
    return self._native:getAngle()
end

function _hermite(t, a, b, tangent_a, tangent_b)
    local t2 = t * t
    local t3 = t2 * t
    return (2 * t3 - 3 * t2 + 1) * a +
        (t3 - 2 * t2 + t) * tangent_a +
        (-2 * t3 + 3 * t2) * b +
        (t3 - t2) * tangent_b
end

function math.slerp2(x0, y0, x1, y1, t)

    x0, y0 = math.normalize(x0, y0)
    x1, y1 = math.normalize(x1, y1)

    -- Compute the dot product
    local dot = x0 * x1 + y0 * y1

    -- Clamp the dot product to avoid numerical errors
    dot = math.max(-1, math.min(1, dot))

    -- Compute the angle between the vectors
    local theta = math.acos(dot)

    -- If the angle is very small, linearly interpolate
    if math.abs(theta) < 1e-5 then
        return x0 * (1 - t) + x1 * t, y0 * (1 - t) + y1 * t
    end

    -- Compute the SLERP
    local sin_theta = math.sin(theta)
    local a = math.sin((1 - t) * theta) / sin_theta
    local b = math.sin(t * theta) / sin_theta

    return a * x0 + b * x1, a * y0 + b * y1
end

function b2.Body:get_predicted_position()
    if true then
        -- linear interpolation
        local x, y = self._native:getPosition()
        local vx, vy = self._native:getLinearVelocity()
        local last_last_x, last_last_y = self._last_x, self._last_y
        local last_x, last_y = self._last_last_x, self._last_last_y
        local current_x, current_y = self._native:getPosition()
        return math.mix2(last_x, last_y, current_x, current_y, self._world._elapsed / self._world:get_timestep())
    else
        -- hermite interpolation
        local current_x, current_y = self._native:getPosition()
        local last_x, last_y = self._last_x, self._last_y
        local timestep = self._world:get_timestep()

        local last_vx, last_vy = self._last_vx, self._last_vy
        local current_vx, current_vy = (current_x - self._last_x), (current_y - self._last_y)
        local tangent_ax, tangent_ay = last_vx, last_vy
        local tangent_bx, tangent_by = current_vx, current_vy

        local t = math.clamp(self._world._elapsed / timestep, 0, 1)
        local interpolated_x = _hermite(t, last_x, current_x, tangent_ax, tangent_bx)
        local interpolated_y = _hermite(t, last_y, current_y, tangent_ay, tangent_by)

        return interpolated_x, interpolated_y
    end
end


--- @brief
function b2.Body:set_use_interpolation(b)
    self._use_interpolation = b
    self._world:_notify_is_interpolating(self, b)
end

--- @brief
function b2.Body:get_center_of_mass()
    if self._native:isDestroyed() then return 0, 0 end

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
function b2.Body:get_linear_velocity()
    if self._native:isDestroyed() then return 0 end
    return self._native:getLinearVelocity()
end
b2.Body.get_velocity = b2.Body.get_linear_velocity

--- @brief
function b2.Body:set_linear_velocity(dx, dy)
    if self._native:isDestroyed() then return end
    if dy == nil then dy = dx end
    self._native:setLinearVelocity(dx, dy)

    if self._manual_velocity then
        self._manual_velocity_x = dx
        self._manual_velocity_y = dy
    end
end
b2.Body.set_velocity = b2.Body.set_linear_velocity

--- @brief
function b2.Body:set_angular_velocity(value)
    if self._native:isDestroyed() then return end
    self._native:setAngularVelocity(value)
end

--- @brief
function b2.Body:get_angular_velocity(value)
    if self._native:isDestroyed() then return 0 end
    return self._native:getAngularVelocity()
end

--- @brief
function b2.Body:set_use_manual_velocity(b)
    self._use_manual_velocity = b
end

--- @brief
function b2.Body:apply_force(dx, dy)
    if self._native:isDestroyed() then return end
    self._native:applyForce(dx, dy)
end

--- @brief
function b2.Body:apply_linear_impulse(dx, dy)
    if self._native:isDestroyed() then return end
    self._native:applyLinearImpulse(dx, dy)
end

--- @brief
function b2.Body:set_mass(mass)
    if self._native:isDestroyed() then return end
    self._native:setMass(mass)
end

--- @brief
function b2.Body:set_friction(friction)
    if self._native:isDestroyed() then return end
    for shape in values(self._native:getShapes()) do
        shape:setFriction(friction)
    end
end

--- @brief
function b2.Body:set_restitution(value)
    if self._native:isDestroyed() then return end
    for shape in values(self._native:getShapes()) do
        shape:setRestitution(value)
    end
end

--- @brief
function b2.Body:get_mass()
    if self._native:isDestroyed() then return 0 end
    return self._native:getMass()
end

--- @brief
function b2.Body:draw(mask_only)
    if self._native:isDestroyed() then return end
    if mask_only == nil then mask_only = false end

    love.graphics.push()
    love.graphics.translate(self:get_position())
    love.graphics.rotate(self._native:getAngle())

    local r, g, b, a = love.graphics.getColor()
    if mask_only then
        love.graphics.setColor(1, 1, 1, 1)
    end

    for shape in values(self._native:getShapes()) do
        local userdata = shape:getUserData()
        if userdata ~= nil then
            userdata:draw(mask_only)
        end
    end

    love.graphics.setColor(r, g, b, a)
    love.graphics.pop()
end

local _enabled_callback = function(body, b)
    body:setActive(b)
end

--- @brief
function b2.Body:set_is_enabled(b)
    local success = pcall(_enabled_callback, self._native, b)

    if not success then
        self._world:_notify_active_changed(self, b)
    end
end

--- @brief
function b2.Body:get_is_enabled()
    return self._native:isActive()
end

--- @brief
function b2.Body:set_is_sensor(b)
    if self._is_sensor ~= b then
        self._is_sensor = b
        for shape in values(self._native:getShapes()) do
            shape:setSensor(b)
        end
    end
end

--- @brief
function b2.Body:get_is_sensor()
    return self._is_sensor
end

--- @brief
function b2.Body:add_tag(tag, ...)
    self._tags[tag] = true

    for i = 1, select("#", ...) do
        self._tags[select(i, ...)] = true
    end
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
function b2.Body:get_tags()
    local out = {}
    for tag in keys(self._tags) do
        table.insert(out, tag)
    end
    return out
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

--- qbrief
function b2.Body:get_collides_with()
    return self._collides_with
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
    self:signal_emit("destroy")
    self:signal_disconnect_all()

    if not self._native:isDestroyed() then
        self._native:destroy()
    end
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

--- @brief
function b2.Body:set_type(type)
    self._native:setType(type)
end

--- @brief
function b2.Body:set_use_continuous_collision(b)
    self._native:setBullet(b)
end

--- @brief
function b2.Body:get_friction()
    return self._friction
end

--- @brief
function b2.Body:set_friction(f)
    self._friction = f
end

--- @brief
function b2.Body:test_point(x, y)
    local tx, ty = self._native:getPosition()
    local tr = self._native:getAngle()
    for shape in values(self._native:getShapes()) do
        if shape:testPoint(tx, ty, tr, x, y) == true then
            return true
        end
    end

    return false
end

--- @brief
function b2.Body:compute_aabb()
    local x, y = self._native:getPosition()
    local r = self._native:getAngle()

    local min_x, min_y, max_x, max_y = math.huge, math.huge, -math.huge, -math.huge
    for shape in values(self._native:getShapes()) do
        local tx, ty, bx, by = shape:computeAABB(x, y, r)
        min_x = math.min(min_x, tx)
        min_y = math.min(min_y, ty)
        max_x = math.max(max_x, bx)
        max_y = math.max(max_y, by)
    end

    return rt.AABB(min_x, min_y, max_x - min_x, max_y - min_y)
end

--- @brief
function b2.Body:set_collision_disabled(b)
    self._collision_disabled = b
end

--- @brief
function b2.Body:get_collision_disabled()
    return self._collision_disabled
end

--- @brief
function b2.Body:set_damping(t)
    if self._native:isDestroyed() then return end
    local damping = 1 / math.max(t, math.eps)
    self._native:setLinearDamping(damping)
    self._native:setAngularDamping(damping)
end