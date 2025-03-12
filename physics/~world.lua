--- @class b3.World
b3.World = meta.class("PhysicsWorld")

--- @brief
function b3.World:instantiate(width, height, ...)
    meta.assert(width, "Number", height, "Number")
    meta.install(self, {
        _native = slick.newWorld(width, height, ...),
        _bodies = {},
        _needs_push = {},
        _gravity_x = 0,
        _gravity_y = 0,
        _active_sensors = {}
    })

    local _old = self._native.responses["slide"]
    self._native.responses["slide"] = function(...)
        local touch_x, touch_y, new_goal_x, new_goal_y = _old(...)
        return touch_x, touch_y, new_goal_x, new_goal_y, "bounce", nil
    end
end

--- @brief
function b3.World:set_gravity(x, y)
    self._gravity_x, self._gravity_y = x, y
end

--- @brief
function b3.World:get_gravity()
    return self._gravity_x, self._gravity_y
end

local body_type_static, body_type_dynamic

local _default_move_filter = function(self, other)
    if self._is_enabled == false or other._is_enabled == false then
        return false
    end

    if self._is_solid == true and other._is_solid == true then
        return true
    end

    if self._is_sensor == true or other._is_sensor == true then
        return "cross"
    end

    return false
end

local _default_push_filter = function(self, other)
    return self._type ~= b3.BodyType.STATIC
end

--- @brief [internal]
function b3.World:_handle_collision_responses(responses, n_responses)
    for i = 1, n_responses do
        local response = responses[i]
        local a, b = response.item, response.other
        if a ~= nil and b ~= nil then
            if a._is_sensor == true then
                if a._colliding_with[b] == nil then
                    a:signal_emit("collision_start", b, response.touch.x, response.touch.y, response.normal.x, response.normal.y)
                end
                a._colliding_with[b] = true
                self._active_sensors[a] = true
            end

            if b._is_sensor == true then
                if b._colliding_with[a] == nil then
                    b:signal_emit("collision_start", a, response.touch.x, response.touch.y, response.normal.x, response.normal.y)
                end
                b._colliding_with[a] = true
                self._active_sensors[b] = true
            end
        end
    end
end

--- @brief
function b3.World:update(delta)
    if body_type_static == nil then body_type_static = b3.BodyType.STATIC end
    if body_type_dynamic == nil then body_type_dynamic = b3.BodyType.DYNAMIC end

    -- velocity simulation
    for body in values(self._bodies) do
        if body._is_enabled ~= false then
            if body._type == body_type_dynamic then
                body._velocity_x = body._velocity_x + (body._acceleration_x + self._gravity_x * body._mass) * delta
                body._velocity_y = body._velocity_y + (body._acceleration_y + self._gravity_y * body._mass) * delta
                body._angular_velocity = body._angular_velocity + body._angular_acceleration * delta
            end

            local transform = body:get_transform()

            if body._type ~= body_type_static then -- kinematic or dynamic
                local vx, vy = body._velocity_x, body._velocity_y
                if math.abs(vx) > 0 or math.abs(vy) > 0 then
                    local _, _, responses, n_responses, query = self._native:move(
                        body,
                        transform.x + vx * delta,
                        transform.y + vy * delta,
                        _default_move_filter
                    )

                    self:_handle_collision_responses(responses, n_responses)
                end

                local v = body._angular_velocity
                if math.abs(v) > 0 then
                    local responses, n_responses = self._native:rotate(
                        body,
                        transform.rotation + v * delta,
                        _default_push_filter,
                        _default_push_filter
                    )

                    self:_handle_collision_responses(responses, n_responses)
                end
            end
        end
    end
end

--- @brief
function b3.World:draw()
    for body in values(self._bodies) do
        body:draw()
    end
end

--- @brief
function b3.World:_notify_body_added(body)
    table.insert(self._bodies, body)
end

--- @brief
function b3.World:_notify_push_needed(body)
    local transform = body:get_transform()
    self._native:push(
        body,
        _default_push_filter,
        transform.x,
        transform.y
    )
end

--- @brief
function b3.World:_update_position(body, x, y)
    body:get_transform():setTransform(x, y)
    self._native:move(body, x, y, _default_move_filter) -- trigger collision
end

--- @brief
function b3.World:_update_rotation(body, angle)
    body:get_transform():setTransform(nil, nil, angle)
end

--- @brief
function b3.World:_update_scale(body, scale_x, scale_y)
    body:get_transform():setTransform(nil, nil, nil, scale_x, scale_y)
end

--- @brief
function b3.World:_set_origin(body, x, y)
    body:get_transform():setTransform(nil, nil, nil, nil, nil, x, y)
end

local _default_query_filter = function(item, other)
    return item._is_enabled == true and item:has_tag("player") ~= true
end

--- @brief
function b3.World:cast_ray(origin_x, origin_y, direction_x, direction_y, filter)
    local responses, n_responses = self._native:queryRay(
        origin_x, origin_y,
        direction_x, direction_y,
        _default_query_filter
    )

    local points = {}
    for i = 1, n_responses do
        local response = responses[i]
        local response_vector_x = response.touch.x - origin_x
        local response_vector_y = response.touch.y - origin_y

        -- filter buggy hits, cf: https://github.com/erinmaus/slick/issues/67
        local dot_product = response_vector_x * direction_x + response_vector_y * direction_y
        if dot_product >= 0 then
            return response.touch.x, response.touch.y, response.normal.y, -response.normal.x
        end
    end

    return nil
end