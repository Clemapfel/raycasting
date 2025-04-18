--- @class b2.World
b2.World = meta.class("PhysicsWorld")
meta.add_signals(b2.World, "step")

local _begin_contact_callback = function(shape_a, shape_b, contact)
    local body_a = shape_a:getBody():getUserData()
    local body_b = shape_b:getBody():getUserData()
    local normal_x, normal_y = contact:getNormal()
    local x1, y1, x2, y2 = contact:getPositions() -- may be nil

    --if shape_a:isSensor() then
        body_a:signal_emit("collision_start", body_b, normal_x, normal_y, x1, y1, x2, y2, contact)
    --end

    --if shape_b:isSensor() then
        body_b:signal_emit("collision_start", body_a, normal_x, normal_y, x1, y1, x2, y2, contact)
    --end
end

local _end_contact_callback = function(shape_a, shape_b, contact)
    local body_a = shape_a:getBody():getUserData()
    local body_b = shape_b:getBody():getUserData()
    local normal_x, normal_y = contact:getNormal()

    --if shape_a:isSensor() then
        body_a:signal_emit("collision_end", body_b, normal_x, normal_y, contact)
    --end

    --if shape_b:isSensor() then
        body_b:signal_emit("collision_end", body_a, normal_x, normal_y, contact)
    --end
end


--- @brief
function b2.World:instantiate(width, height, ...)
    meta.assert(width, "Number", height, "Number")
    meta.install(self, {
        _native = love.physics.newWorld(0, 0),
        _body_to_move_queue = {},
        _body_to_rotate_queue = {},
        _body_to_activate_queue = {},
        _timestamp = love.timer.getTime()
    })

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
function b2.World:set_gravity(x, y)
    self._native:setGravity(x, y)
end

--- @brief
function b2.World:get_gravity()
    return self._native:getGravity()
end

local _elapsed = 0
local _step = 1 / 120
local _max_n_steps_per_frame = 3

--- @brief
function b2.World:update(delta)
    _elapsed = _elapsed + delta

    local total_step = 0
    local n_steps = 0
    while _elapsed > _step and n_steps < _max_n_steps_per_frame do
        -- update
        self._native:update(_step, 5, 2)
        self._timestamp = love.timer.getTime()

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

        self:signal_emit("step", _step)

        _elapsed = _elapsed - _step
        n_steps = n_steps + 1
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