--- @class b2.World
b2.World = meta.class("PhysicsWorld")

--- @brief
function b2.World:instantiate(width, height)
    meta.assert(width, "Number", height, "Number")
    meta.install(self, {
        _native = slick.newWorld(width, height),
        _bodies = {},
        _needs_push = {}
    })
end

--- @brief
function b2.World:update(delta)
    -- initial push when bodies spawn or change position
    for body in values(self._needs_push) do
        body._transform.x, body._transform.y = self._native:push(body, b2._default_filter, body:get_position())
    end
    self._needs_push = {}

    -- velocity simulation
    for body in values(self._bodies) do
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
