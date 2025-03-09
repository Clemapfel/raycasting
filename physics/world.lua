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

    -- TODO
    local point = require "physics.slick.slick.geometry.point"
    local _cachedSlideCurrentPosition = point.new()
    local _cachedSlideTouchPosition = point.new()
    local _cachedSlideGoalPosition = point.new()
    local _cachedSlideGoalDirection = point.new()
    local _cachedSlideNewGoalPosition = point.new()
    local _cachedSlideDirection = point.new()
    local _cachedSlideNormal = point.new()

    local last_goalDotDirection = 0
    local function slide(world, query, response, x, y, goalX, goalY, filter, result)
        local true_goal_x, true_goal_y = goalX, goalY
        _cachedSlideCurrentPosition:init(x, y)
        _cachedSlideTouchPosition:init(response.touch.x, response.touch.y)
        _cachedSlideGoalPosition:init(goalX, goalY)

        response.normal:left(_cachedSlideGoalDirection)

        _cachedSlideCurrentPosition:direction(_cachedSlideGoalPosition, _cachedSlideNewGoalPosition)
        _cachedSlideNewGoalPosition:normalize(_cachedSlideDirection)

        local goalDotDirection = _cachedSlideNewGoalPosition:dot(_cachedSlideGoalDirection)
        local last = last_goalDotDirection
        last_goalDotDirection = goalDotDirection
        _cachedSlideGoalDirection:multiplyScalar(goalDotDirection, _cachedSlideGoalDirection)
        _cachedSlideTouchPosition:add(_cachedSlideGoalDirection, _cachedSlideNewGoalPosition)

        local newGoalX = _cachedSlideNewGoalPosition.x
        local newGoalY = _cachedSlideNewGoalPosition.y
        local touchX, touchY = response.touch.x, response.touch.y

        result:push(response)
        world:project(response.item, touchX, touchY, newGoalX, newGoalY, filter, query)
        return touchX, touchY, newGoalX, newGoalY, "slide", nil -- here
    end

    self._native.responses["slide"] = slide
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
local _default_filter_query_function = function(item, other)
    local type = item:get_collision_response_type()
    if type == b2.CollisionResponseType.GHOST then return false end
    return type
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
        if body._type == body_type_dynamic then
            body._velocity_x = body._velocity_x + (body._acceleration_x + self._gravity_x * body._mass) * delta
            body._velocity_y = body._velocity_y + (body._acceleration_y + self._gravity_y * body._mass) * delta
            body._angular_velocity = body._angular_velocity + body._angular_acceleration * delta
        end

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

                body._transform.x = x
                body._transform.y = y
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
end

--- @brief [internal]
function b2.World:_notify_body_added(body)
    table.insert(self._bodies, body)
end
