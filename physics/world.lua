--- @class b2.World
b2.World = meta.class("PhysicsWorld")

b2.CollisionResponseType = meta.enum("PhysicsCollisionResponseType", {
    GHOST = "cross",
    SLIDE = "slide",
    TOUCH = "touch"
})

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

    local _old = self._native.responses["slide"]
    self._native.responses["slide"] = function(...)
        local touch_x, touch_y, new_goal_x, new_goal_y = _old(...)
        return touch_x, touch_y, new_goal_x, new_goal_y, "slide", nil
    end
end

--- @brief
function b2.World:set_gravity(x, y)
    self._gravity_x, self._gravity_y = x, y
end

--- @brief
function b2.World:get_gravity()
    return self._gravity_x, self._gravity_y
end

local _default_filter_query_function = function(self, other)
    if self._is_enabled == false or other._is_enabled == false then
        return false
    end

    if self._is_solid == true and other._is_solid == true then
        return "slide"
    end

    if self._is_sensor == true or other._is_sensor == true then
        return "cross"
    end

    return false
end
local body_type_static, body_type_dynamic

--- @brief [internal]
function b2.World:_handle_collision_responses(responses, n_responses)
    for i = 1, n_responses do
        local response = responses[i]
        local a, b = response.item, response.other
        if a ~= nil and b ~= nil then
            if a._is_sensor == true then
                a:signal_emit("collision", b, response.touch.x, response.touch.y, response.normal.x, response.normal.y)
            end

            if b._is_sensor == true then
                b:signal_emit("collision", a, response.touch.x, response.touch.y, response.normal.x, response.normal.y)
            end
        end
    end
end

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
        if body._is_enabled ~= false then
            --[[
            if body._type == body_type_dynamic then
                body._velocity_x = body._velocity_x + (body._acceleration_x + self._gravity_x * body._mass) * delta
                body._velocity_y = body._velocity_y + (body._acceleration_y + self._gravity_y * body._mass) * delta
                body._angular_velocity = body._angular_velocity + body._angular_acceleration * delta
            end
            ]]--

            if body._type ~= body_type_static then -- kinematic or dynamic
                local x, y = body._transform.x, body._transform.y
                local vx, vy = body._velocity_x, body._velocity_y
                if math.abs(vx) > 0 or math.abs(vy) > 0 then
                    local x, y, responses, n_responses, query = self._native:move(
                        body,
                        x + vx * delta,
                        y + vy * delta,
                        _default_filter_query_function
                    )

                    self:_handle_collision_responses(responses, n_responses)

                    body._transform.x = x
                    body._transform.y = y
                end

                local v = body._angular_velocity
                local current = body._transform.rotation
                if math.abs(v) > 0 then
                    body._transform:setTransform(body._transform.x, body._transform.y, current + v * delta)
                    local responses, n_responses = self._native:rotate(
                        body,
                        body._transform.rotation,
                        function() return true end,
                        function() return false end
                    )

                    self:_handle_collision_responses(responses, n_responses)
                end
            end
        end
    end
end

--- @brief
function b2.World:draw()
    for body in values(self._bodies) do
        body:draw()
    end
end

--- @brief [internal]
function b2.World:_notify_push_needed(body)
    table.insert(self._needs_push, body)
end

--- @brief [internal]
function b2.World:_notify_transform_changed(body)
    self._native:update(body, body._transform)
    body._transform.x, body._transform.y = self._native:push(
        body,
        _default_filter_query_function,
        body._transform.x,
        body._transform.y
    )
end

--- @brief [internal]
function b2.World:_notify_body_added(body)
    table.insert(self._bodies, body)
end
