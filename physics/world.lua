--- @class b2.World
b2.World = meta.class("PhysicsWorld")
meta.add_signals(b2.World, "step")

--- @brief
function b2.World:instantiate()
    meta.install(self, {
        _native = love.physics.newWorld(0, 0),
        _body_to_move_queue = {},
        _body_to_rotate_queue = {},
        _body_to_activate_queue = {},
        _timestamp = love.timer.getTime(),
        _interpolating_bodies = meta.make_weak({}), -- Set
        _time_dilation = 1,
        _elapsed = 0,
        _use_fixed_timestep = true,
        _current_timestamp = love.timer.getTime(),
        _last_timestamp = love.timer.getTime(),

        _body_to_collision_sign = {}
    })

    local _add_collision_start = function(a, b, nx, ny, x1, y1, x2, y2, contact)
        if a:get_collision_disabled() == true or b:get_collision_disabled() == true then return end

        local current = self._body_to_collision_sign[a]
        if current == nil then
            current = {}
            self._body_to_collision_sign[a] = current
        end

        local entry = current[b]
        if entry == nil then
            entry = {
                sign = 0
            }
            current[b] = entry
        end

        entry.sign = entry.sign + 1
        entry.nx = nx
        entry.ny = ny
        entry.x1 = x1
        entry.y1 = y1
        entry.x2 = x2
        entry.y2 = y2
        entry.contact = contact
    end

    local _add_collision_end = function(a, b, nx, ny, x1, y1, x2, y2, contact)
        if a:get_collision_disabled() == true or b:get_collision_disabled() == true then return end

        local current = self._body_to_collision_sign[a]
        if current == nil then
            current = {}
            self._body_to_collision_sign[a] = current
        end

        local entry = current[b]
        if entry == nil then
            entry = {
                sign = 0
            }
            current[b] = entry
        end

        entry.sign = entry.sign - 1
        entry.nx = nx
        entry.ny = ny
        entry.x1 = x1
        entry.y1 = y1
        entry.x2 = x2
        entry.y2 = y2
        entry.contact = contact
    end

    local _begin_contact_callback = function(shape_a, shape_b, contact)
        local body_a = shape_a:getBody():getUserData()
        local body_b = shape_b:getBody():getUserData()
        local normal_x, normal_y = contact:getNormal()
        local x1, y1, x2, y2 = contact:getPositions() -- may be nil

        _add_collision_start(body_a, body_b, normal_x, normal_y, x1, y1, x2, y2, contact)
        _add_collision_start(body_b, body_a, normal_x, normal_y, x1, y1, x2, y2, contact)
    end

    local _end_contact_callback = function(shape_a, shape_b, contact)
        local body_a = shape_a:getBody():getUserData()
        local body_b = shape_b:getBody():getUserData()
        local normal_x, normal_y = contact:getNormal()
        local x1, y1, x2, y2 = contact:getPositions()

        _add_collision_end(body_a, body_b, normal_x, normal_y, x1, y1, x2, y2, contact)
        _add_collision_end(body_b, body_a, normal_x, normal_y, x1, y1, x2, y2, contact)
    end

    self._start_collision_resolution = function(self)
        self._body_to_collision_sign = {}
    end

    self._end_collision_resolution = function(self)
        -- consolidate collisions and ensure proper ordering within the same frame
        for a, outer in pairs(self._body_to_collision_sign) do
            for b, entry in pairs(outer) do
                if entry.sign >= 1 or entry.sign == 0 then
                    a:signal_emit("collision_start", b, entry.nx, entry.ny, entry.x1, entry.y1, entry.x2, entry.y2, entry.contact)
                end
            end

            for b, entry in pairs(outer) do
                if entry.sign <= -1 or entry.sign == 0 then
                    a:signal_emit("collision_end", b, entry.nx, entry.ny, entry.x1, entry.y1, entry.x2, entry.y2, entry.contact)
                end
            end
        end
    end

    self._native:setCallbacks(
        _begin_contact_callback,
        _end_contact_callback,
        nil,
        nil
    )
end

--- @brief
function b2.World:_notify_position_changed(body, x, y)
    if self._native:isLocked() == true then
        table.insert(self._body_to_move_queue, {
            body = body:get_native(),
            position_x = x,
            position_y = y,
        })
    else
        body._native:setPosition(x, y)
    end
end

--- @brief
function b2.World:_notify_rotation_changed(body, rotation)
    if self._native:isLocked() == true then
        table.insert(self._body_to_rotate_queue, {
            body = body:get_native(),
            angle = rotation
        })
    else
        body._native:setAngle(rotation)
    end
end

--- @brief
function b2.World:_notify_active_changed(body, b)
    if self._native:isLocked() == true then
        table.insert(self._body_to_activate_queue, {
            body = body:get_native(),
            is_active = b
        })
    else
        body._native:setActive(b)
    end
end

--- @brief
function b2.World:_notify_is_interpolating(body, b)
    if b then
        self._interpolating_bodies[body] = true
    else
        self._interpolating_bodies[body] = nil
    end
end

--- @brief
function b2.World:set_gravity(x, y)
    self._native:setGravity(x, y)
end

--- @brief
function b2.World:get_gravity()
    return self._native:getGravity()
end

local _step = 1 / 120
local _max_n_steps_per_frame = math.huge
local _n_velocity_iterations = 4

--- @brief
function b2.World:update(delta)
    if self._use_fixed_timestep then
        self._elapsed = self._elapsed + delta * self._time_dilation
    else
        self._elapsed = delta * self._time_dilation
    end

    local step = self._use_fixed_timestep and _step or delta * self._time_dilation
    local total_step = 0
    local n_steps = 0
    while self._elapsed >= step and n_steps < _max_n_steps_per_frame do

        self:_start_collision_resolution()

        for body in keys(self._interpolating_bodies) do
            local x, y = body._native:getPosition()
            local vx, vy = (x - body._last_x), (y - body._last_y)
            body._last_x, body._last_y = body._native:getPosition()
            body._last_vx, body._last_vy = vx, vy
        end

        -- update
        self._native:update(step, _n_velocity_iterations, 2)

        self:_end_collision_resolution()

        -- work through queued updates
        for entry in values(self._body_to_move_queue) do
            entry.body:setPosition(entry.position_x, entry.position_y)
        end
        self._body_to_move_queue = {}

        for entry in values(self._body_to_rotate_queue) do
            entry.body:setAngle(entry.angle)
        end
        self._body_to_rotate_queue = {}

        for entry in values(self._body_to_activate_queue) do
            entry.body:setActive(entry.is_active)
        end
        self._body_to_activate_queue = {}

        -- world signal
        self:signal_emit("step", step)

        self._elapsed = self._elapsed - step
        n_steps = n_steps + 1

        if n_steps >= _max_n_steps_per_frame then break end
    end
end

--- @brief
function b2.World:draw()
    for body in values(self._native:getBodies()) do
        body:getUserData():draw()
    end
end

--- @brief
--- @param origin_x Number
--- @param origin_y Number
--- @param direction_x Number
--- @param direction_y Number
--- @param ... b2.CollisionGroup
--- @return number, number, number, number, b2.Body x, y, normal_x, normal_y
function b2.World:query_ray(origin_x, origin_y, direction_x, direction_y, mask)
    local min_fraction = math.huge
    local x_out, y_out, normal_x_out, normal_y_out

    local shape, x, y, nx, ny, fraction = self._native:rayCastClosest(
        origin_x, origin_y,
        origin_x + direction_x,
        origin_y + direction_y,
        mask
    )

    if shape ~= nil then shape = shape:getBody():getUserData() end
    return x, y, nx, ny, shape
end

--- @brief
--- @param origin_x Number
--- @param origin_y Number
--- @param direction_x Number
--- @param direction_y Number
--- @param ... b2.CollisionGroup
--- @return number, number, number, number, b2.Body x, y, normal_x, normal_y
function b2.World:query_ray_any(origin_x, origin_y, direction_x, direction_y, mask)
    local min_fraction = math.huge

    if math.magnitude(direction_x, direction_y) < 1 then
        direction_x, direction_y = math.normalize(direction_x, direction_y)
    end

    local shape, x, y, nx, ny, fraction = self._native:rayCastAny(
        origin_x, origin_y,
        origin_x + direction_x,
        origin_y + direction_y,
        mask
    )

    if shape ~= nil then shape = shape:getBody():getUserData() end
    return x, y, nx, ny, shape
end

--- @brief
--- @param origin_x Number
--- @param origin_y Number
--- @param direction_x Number
--- @param direction_y Number
--- @param ... b2.CollisionGroup
--- @return number, number, number, number, b2.Body x, y, normal_x, normal_y
function b2.World:query_segment(origin_x, origin_y, direction_x, direction_y, ...)
    local min_fraction = math.huge
    local x_out, y_out, normal_x_out, normal_y_out

    local group
    local n = select("#", ...)
    if n > 0 then
        group = 0x0
        for i = 1, n do
            group = bit.bor(group, select(i, ...))
        end
    else
        group = b2.CollisionGroup.ALL
    end

    local bodies = {}
    local body_to_fraction = {}

    self._native:rayCast(
        origin_x, origin_y,
        origin_x + direction_x,
        origin_y + direction_y,
        function(shape, x, y, nx, ny, fraction)
            local body = shape:getBody():getUserData()
            table.insert(bodies, body)
            body_to_fraction[body] = fraction
            return 1
        end
    )

    table.sort(bodies, function(a, b)
        return body_to_fraction[a] < body_to_fraction[b]
    end)

    return bodies
end

--- @brief
--- @return Table<Body>
function b2.World:query_aabb(x, y, width, height)
    local shapes = self._native:getShapesInArea(x, y, x + width, y + height)
    local out = {}
    local seen = {}
    for shape in values(shapes) do
        local body = shape:getBody()
        if seen[body] == nil then
            table.insert(out, body:getUserData())
            seen[body] = true
        end
    end
    return out
end

--- @brief
--- @return Boolean true if occluded, false otherwise
function b2.World:circle_cast(radius, from_x, from_y, to_x, to_y, mask)
    local direction_x, direction_y = to_x - from_x, to_y - from_y
    local ndx, ndy = math.normalize(direction_x, direction_y)
    local center_x, center_y = from_x, from_y

    local up_x, up_y = math.turn_left(ndx, ndy)
    local top_x, top_y = center_x + up_x * radius, center_y + up_y * radius

    local down_x, down_y = math.turn_right(ndx, ndy)
    local bottom_x, bottom_y = center_x + down_x * radius, center_y + down_y * radius

    local native = self:get_native()

    local center_shape, center_cx, center_cy, center_nx, center_ny, center_fraction = native:rayCastAny(
        center_x, center_y, center_x + direction_x, center_y + direction_y, mask
    )

    if center_shape ~= nil then return true end

    local top_shape, top_cx, top_cy, top_nx, top_ny, top_fraction = native:rayCastAny(
        top_x, top_y, top_x + direction_x, top_y + direction_y, mask
    )

    if top_shape ~= nil then return true end

    local bottom_shape, bottom_cx, bottom_cy, bottom_nx, bottom_ny, bottom_fraction = native:rayCastAny(
        bottom_x, bottom_y, bottom_x + direction_x, bottom_y + direction_y, mask
    )

    if bottom_shape ~= nil then return true end

    return false
end

--- @brief
function b2.World:get_native()
    return self._native
end

--- @brief
function b2.World:get_timestamp()
    return self._timestamp
end

--- @brief
function b2.World:get_timestep()
    return _step
end

--- @brief
function b2.World:set_time_dilation(x)
    self._time_dilation = x
end

--- @brief
function b2.World:get_time_dilation()
    return self._time_dilation
end

--- @brief
function b2.World:set_use_fixed_timestep(b)
    self._use_fixed_timestep = b
end

--- @brief
function b2.World:get_use_fixed_timestep()
    return self._use_fixed_timestep
end