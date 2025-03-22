--- @class b2.World
b2.World = meta.class("PhysicsWorld")
meta.add_signals(b2.World, "step")

local _begin_contact_callback = function(shape_a, shape_b, contact)
    local body_a = shape_a:getBody():getUserData()
    local body_b = shape_b:getBody():getUserData()

    local x1, y1, x2, y2 = contact:getPositions()
    local normal_x, normal_y = contact:getNormal()

    if body_a:get_is_sensor() then
        body_a:signal_emit("collision_start", body_b, normal_x, normal_y, x1, y1, x2, y2)
    end

    if body_b:get_is_sensor() then
        body_b:signal_emit("collision_start", body_a, normal_x, normal_y, x1, y1, x2, y2)
    end
end

local _end_contact_callback = function(shape_a, shape_b, contact)
    local body_a = shape_a:getBody():getUserData()
    local body_b = shape_b:getBody():getUserData()

    local x1, y1, x2, y2 = contact:getPositions()
    local normal_x, normal_y = contact:getNormal()

    if body_a:get_is_sensor() then
        body_a:signal_emit("collision_end", body_b, normal_x, normal_y, x1, y1, x2, y2)
    end

    if body_b:get_is_sensor() then
        body_b:signal_emit("collision_end", body_a, normal_x, normal_y, x1, y1, x2, y2)
    end
end


--- @brief
function b2.World:instantiate(width, height, ...)
    meta.assert(width, "Number", height, "Number")
    meta.install(self, {
        _native = love.physics.newWorld(0, 0),
        _transform_queue = {}, -- used by bodies to delay transformation after collision callbacks
        _body_to_transform_queue_entry = {}
    })

    self._native:setCallbacks(
        _begin_contact_callback,
        _end_contact_callback,
        nil,
        nil
    )
end

function b2.World:_update_transform_entry(body, x, y, rotation)
    local entry = self._body_to_transform_queue_entry[body]
    if entry == nil then
        entry = {
            body = body,
            x = nil,
            y = nil,
            rotation = nil
        }

        self._body_to_transform_queue_entry[body] = entry
        table.insert(self._transform_queue, entry)
    end

    if x ~= nil then entry.x = x end
    if y ~= nil then entry.y = y end
    if rotation ~= nil then entry.rotation = rotation end
end

--- @brief
function b2.World:_notify_position_changed(body, x, y)
    if self._native:isLocked() == true then
        self:_update_transform_entry(body, x, y, nil)
    else
        body._native:setPosition(x, y)
    end
end

--- @brief
function b2.World:_notify_rotation_changed(body, rotation)
    if self._native:isLocked() == true then
        self:_update_transform_entry(body, nil, nil, rotation)
    else
        body._native:setAngle(rotation)
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
local _max_n_steps_per_frame = 2 / 30 * (1 / _step) -- max 2 steps at 30fps

--- @brief
function b2.World:update(delta)
    _elapsed = _elapsed + delta

    local total_step = 0
    local n_steps = 0
    while _elapsed > _step and n_steps < _max_n_steps_per_frame do
        -- work through queued body updates from when world was locked
        for entry in values(self._transform_queue) do
            if entry.x ~= nil and entry.y ~= nil then
                entry.body._native:setPosition(entry.x, entry.y)
            end

            if entry.rotation ~= nil then
                entry.body._native:setAngle(entry.rotation)
            end
        end
        self._transform_queue = {}
        self._body_to_transform_queue_entry = {}

        -- update
        self._native:update(_step)

        -- notify bodies for frame interpolation
        for native in values(self._native:getBodies()) do
            if native:getType() ~= "static" then
                native:getUserData():_post_update_notify(_step)
            end
        end

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
function b2.World:query_ray(origin_x, origin_y, direction_x, direction_y, ...)
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

    local shape, x, y, nx, ny, fraction = self._native:rayCastClosest(
        origin_x, origin_y,
        origin_x + direction_x,
        origin_y + direction_y,
        group
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
function b2.World:query_ray_any(origin_x, origin_y, direction_x, direction_y, ...)
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

    local shape, x, y, nx, ny, fraction = self._native:rayCastAny(
        origin_x, origin_y,
        origin_x + direction_x,
        origin_y + direction_y,
        group
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
function b2.World:get_native()
    return self._native
end