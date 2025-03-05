--- @class b2.World
b2.World = meta.class("PhysicsWorld")

--- @brief
function b2.World:instantiate(width, height, ...)
    meta.assert(width, "Number", height, "Number")
    meta.install(self, {
        _native = slick.newWorld(width, height, ...),
        _bodies = {},
        _needs_push = {},
        _gravity_x = 0,
        _gravity_y = 0
    })
end

--- @brief
function b2.World:set_gravity(x, y)
    self._gravity_x, self._gravity_y = x, y
end

--- @brief
function b2.World:get_gravity()
    return self._gravity_x, self._gravity_y
end

local body_type_static, body_type_dynamic

--- @brief
function b2.World:update(delta)
    if body_type_static == nil then body_type_static = b2.BodyType.STATIC end
    if body_type_dynamic == nil then body_type_dynamic = b2.BodyType.DYNAMIC end

    -- initial push when bodies spawn or change position
    for body in values(self._needs_push) do
        body._transform.x, body._transform.y = self._native:push(body, b2._default_filter, body:get_position())
    end
    self._needs_push = {}

    -- velocity simulation
    for body in values(self._bodies) do
        if body._type == body_type_dynamic then
            body._velocity_x = body._velocity_x + (body._acceleration_x + self._gravity_x * body._mass) * delta
            body._velocity_y = body._velocity_y + (body._acceleration_y + self._gravity_y * body._mass) * delta
            body._angular_velocity = body._angular_velocity + body._angular_acceleration * delta
        end

        if body._type ~= body_type_static then -- kinematic or dynamic
            local x, y = body._transform.x, body._transform.y
            local vx, vy = body._velocity_x, body._velocity_y
            if math.abs(vx) > 0 or math.abs(vy) > 0 then
                body._transform.x, body._transform.y = self._native:move(
                    body,
                    x + vx * delta,
                    y + vy * delta
                )
            end

            local v = body._angular_velocity
            local current = body._transform.rotation
            if math.abs(v) > 0 then
                body._transform:setTransform(nil, nil, current + v * delta)
                self._native:update(
                    body,
                    body._transform
                )
            end
        end
    end
end

--- @brief [internal]
function b2.World:_notify_push_needed(body)
    table.insert(self._needs_push, body)
end

--- @brief [internal]
function b2.World:_notify_transform_changed(body)
    self._native:update(body, body._transform)
end

--- @brief [internal]
function b2.World:_notify_body_added(body)
    table.insert(self._bodies, body)
end
