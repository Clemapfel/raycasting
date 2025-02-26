--- @class b2.World
b2.World = meta.class("PhysicsWorld")

--- @brief
function b2.World:instantiate(gravity_x, gravity_y, n_threads)
    if n_threads == nil or n_threads <= 1 then
        n_threads = 0
    end

    meta.assert(
        gravity_x, "Number",
        gravity_y, "Number",
        n_threads, "Number"
    )

    local scale = B2_PIXEL_TO_METER --B2_PIXEL_TO_METER * B2_PIXEL_TO_METER
    local out
    if n_threads == 0 then
        local def = box2d.b2DefaultWorldDef()
        def.gravity = b2.Vec2(gravity_x * scale, gravity_y * scale)
        def.restitutionThreshold = 0
        meta.install(self,{
            _native = box2d.b2CreateWorld(def),
            _user_context = nil
        })
    else
        local def = box2d.b2DefaultWorldDef()
        def.gravity = b2.Vec2(gravity_x * scale, gravity_y * scale)
        def.restitutionThreshold = 0

        def.workerCount = n_threads
        def.enqueueTask = b2.World._enqueue_task
        def.finishTask = b2.World._finish_task

        local context = ffi.gc(ffi.new("b2UserContext"), b2.World._free_user_context)
        context.n_tasks = 0
        context.scheduler = enkiTS.enkiNewTaskScheduler()
        local config = enkiTS.enkiGetTaskSchedulerConfig(context.scheduler)
        config.numTaskThreadsToCreate = n_threads - 1
        enkiTS.enkiInitTaskSchedulerWithConfig(context.scheduler, config)

        for task_i = 1, b2.World.MAX_N_TASKS do
            context.tasks[task_i - 1] = enkiTS.enkiCreateTaskSet(context.scheduler, box2d.b2InvokeTask)
        end

        def.userTaskContext = context

        meta.install(self, {
            _native = box2d.b2CreateWorld(def),
            _user_context = context
        })
    end

    self._debug_draw = box2d.b2CreateDebugDraw(
        b2.World._draw_polygon,
        b2.World._draw_solid_polygon,
        b2.World._draw_circle,
        b2.World._draw_solid_circle,
        b2.World._draw_solid_capsule,
        b2.World._draw_segment,
        b2.World._draw_transform,
        b2.World._draw_point,
        b2.World._draw_string,
        true,   -- draw_shapes
        true,   -- draw_joints
        false,  -- draw_joints_extra
        false,  -- draw_aabb
        false,  -- draw_mass
        true,   -- draw_contacts,
        true,   -- draw_graph_colors,
        false,  -- draw_contact_normals,
        false,  -- draw_contact_impulses,
        false   -- draw_friction_impulses,
    )

    return out
end

--- @brief [internal]
function b2.World._create_from_native(native)
    local instance = setmetatable({}, meta.get_instance_metatable(b2.World))
    instance._native = native
    instance._user_context = nil
    return instance
end

b2.World.MAX_N_TASKS = 256

--- @brief
b2.World._free_user_context = ffi.cast("void(*)(b2UserContext*)", function(context)
    if context == nil then return end
    for i = 1, b2.World.MAX_N_TASKS do
        enkiTS.enkiDeleteTaskSet(context.scheduler, context.tasks[i - 1])
    end
    enkiTS.enkiDeleteTaskScheduler(context.scheduler)
    -- context itself is garbage collected
end)

do
    local _enqueue_task_warning_printed
    b2.World._enqueue_task = ffi.cast("b2EnqueueTaskCallback*", function(task_callback, n_items, min_range, task_context, user_context_ptr)
        local context = ffi.cast("b2UserContext*", user_context_ptr)
        if context.n_tasks < 64 then
            local task = ffi.cast("void*", context.tasks[context.n_tasks]) -- enkiTaskSet*
            local data = context.task_data[context.n_tasks]
            data.callback = task_callback
            data.context = task_context

            local params = ffi.new("enkiParamsTaskSet")
            params.minRange = min_range
            params.setSize = n_items
            params.pArgs = data
            params.priority = 0

            enkiTS.enkiSetParamsTaskSet(task, params)
            enkiTS.enkiAddTaskSet(context.scheduler, task)
            context.n_tasks = context.n_tasks + 1

            return task
        else
            -- not enough tasks for this step, do work on main instead
            task_callback(0, n_items, 0, task_context)
            if _enqueue_task_warning_printed == false then
                rt.warning("In b2.World:step: multi-threaded stepping exceeded number of available tasks for delta `" .. love.timer.getDelta() .. "`, reverting to serial execution")
                _enqueue_task_warning_printed = true
            end
            return ffi.CNULL
        end
    end)
end

b2.World._finish_task = ffi.cast("b2FinishTaskCallback*", function(task_ptr, user_context)
    if task_ptr == ffi.CNULL then return end
    local context = ffi.cast("b2UserContext*", user_context)
    local task = ffi.cast("void*", task_ptr) -- enkiTaskSet*
    enkiTS.enkiWaitForTaskSet(context.scheduler, task)
end)

--- @brief
--- @return Number, Number
function b2.World:get_gravity()
    local out = box2d.b2World_GetGravity(self._native)
    local scale = B2_METER_TO_PIXEL * B2_METER_TO_PIXEL
    return out.x * scale, out.y * scale
end

--- @brief
function b2.World:set_gravity(gravity_x, gravity_y)
    meta.assert(gravity_x, "Number", gravity_y, "Number")

    local scale = B2_PIXEL_TO_METER * B2_PIXEL_TO_METER
    box2d.b2World_SetGravity(self._native, b2.Vec2(gravity_x * scale, gravity_y * scale))
end

--- @brief
function b2.World:step(delta, n_iterations)
    if n_iterations == nil then n_iterations = 4 end
    meta.assert(delta, "Number", n_iterations, "Number")

    local step = 1 / 60
    while delta > step do
        box2d.b2World_Step(self._native, step, n_iterations)
        delta = delta - step
    end
    box2d.b2World_Step(self._native, delta, n_iterations) -- also use rest delta

    if self._user_context ~= nil then -- enki threading
        self._user_context.n_tasks = 0
    end
end

--- @brief
function b2.World:set_sleeping_enabled(b)
    meta.assert(b, "Boolean")
    box2d.b2World_EnableSleeping(self._native, b)
end

--- @brief
function b2.World:set_continuous_enabled(b)
    meta.assert(b, "Boolean")
    box2d.b2World_EnableContinuous(self._native, b)
end

--- @brief
function b2.World:draw()
    box2d.b2World_Draw(self._native, self._debug_draw)
end

--- @brief
--- @param callback (b2.Shape, point_x, point_y, normal_x, normal_y, fraction) -> fraction
function b2.World:raycast(start_x, start_y, end_x, end_y, callback)
    meta.assert(
        start_x, "Number",
        start_y, "Number",
        end_x, "Number",
        end_y, "Number",
        callback, "Function"
    )

    local scale = B2_PIXEL_TO_METER
    start_x = start_x * scale
    start_y = start_y * scale
    end_x = end_x * scale
    end_y = end_y * scale
    box2d.b2World_CastRayWrapper(
        self._native,
        b2.Vec2(start_x, start_y),
        b2.Vec2(end_x - start_x, end_y - start_y),
        box2d.b2DefaultQueryFilter(),
        function (shape_id, point, normal, fraction)
            return callback(
                b2.Shape._create_from_native(shape_id[0]),
                point.x, point.y,
                normal.x, normal.y,
                fraction
            )
        end
    )
end

--- @brief
--- @return (b2.Shape, Number, Number, Number, Number, Number) shape, point_x, point_y, normal_x, normal_y, fraction
function b2.World:raycast_closest(start_x, start_y, end_x, end_y)
    meta.assert(
        start_x, "Number",
        start_y, "Number",
        end_x, "Number",
        end_y, "Number"
    )

    local scale = B2_PIXEL_TO_METER
    start_x = start_x * scale
    start_y = start_y * scale
    end_x = end_x * scale
    end_y = end_y * scale
    local result = box2d.b2World_CastRayClosest(
        self._native,
        b2.Vec2(start_x, start_y),
        b2.Vec2(end_x - start_x, end_y - start_y),
        box2d.b2DefaultQueryFilter()
    )

    if result.hit then
        local shape = b2.Shape._create_from_native(result.shapeId)
        local point_x, point_y = result.point.x, result.point.y
        local normal_x, normal_y = result.normal.x, result.normal.y
        local fraction = result.fraction

        return shape, point_x, point_y, normal_x, normal_y, fraction
    else
        return nil
    end
end

--- @brief
function b2.World:explode(position_x, position_y, radius, impulse)
    meta.assert(
        position_x, "Number",
        position_y, "Number",
        radius, "Number",
        impulse, "Number"
    )

    local scale = B2_PIXEL_TO_METER
    box2d.b2World_Explode(self._native, b2.Vec2(position_x * scale, position_y * scale), radius * scale, impulse * scale)
end

do -- use upvalues to minimize luajit callback count
    local _overlap_current_callback = nil
    local _overlap_wrapper_callback = ffi.cast("bool(*)(b2ShapeId*)", function(shape_id_ptr)
        return _overlap_current_callback(b2.Shape._create_from_native(shape_id_ptr[0]))
    end)

    --- @brief
    --- @param callback (b2.Shape) -> Boolean
    function b2.World:overlap_aabb(x, y, width, height, callback)
        meta.assert(
            x, "Number",
            y, "Number",
            width, "Number",
            height, "Number",
            callback, "Function"
        )

        local scale = B2_PIXEL_TO_METER
        x = x * scale
        y = y * scale
        width = width * scale
        height = height * scale
        local aabb = b2.AABB(b2.Vec2(x, y), b2.Vec2(x + width, y + height))
        _overlap_current_callback = callback
        box2d.b2World_OverlapAABBWrapper(self._native, aabb, box2d.b2DefaultQueryFilter(), _overlap_wrapper_callback)
        _overlap_current_callback = nil
    end

    --- @brief
    --- @param callback (b2.Shape) -> Boolean
    function b2.World:overlap_circle(x, y, radius, callback)
        meta.assert(
            x, "Number",
            y, "Number",
            radius, "Number",
            callback, "Function"
        )

        local scale = B2_PIXEL_TO_METER
        local circle = b2.Circle._create_native(b2.Vec2(x * scale, y * scale), radius * scale)
        _overlap_current_callback = callback
        box2d.b2World_OverlapCircleWrapper(self._native, circle, b2.IdentityTransform, box2d.b2DefaultQueryFilter(), _overlap_wrapper_callback)
        _overlap_current_callback = nil
    end

    --- @brief
    --- @param callback (b2.Shape) -> Boolean
    function b2.World:overlap_capsule(a_x, a_y, b_x, b_y, radius, callback)
        meta.assert(
            a_x, "Number",
            a_y, "Number",
            b_x, "Number",
            b_y, "Number",
            radius, "Number",
            callback, "Function"
        )

        local scale = B2_PIXEL_TO_METER
        local capsule = b2.Capsule._create_native(
            b2.Vec2(a_x * scale, a_y * scale),
            b2.Vec2(b_x * scale, b_y * scale),
            radius
        )

        _overlap_current_callback = callback
        box2d.b2World_OverlapCapsuleWrapper(self._native, capsule, b2.IdentityTransform, box2d.b2DefaultQueryFilter(), _overlap_wrapper_callback)
        _overlap_current_callback = nil
    end

    --- @brief
    --- @param vertices Table<Number> size 2*n, 6 <= size <= 16
    --- @param callback (b2.Shape) -> Boolean
    function b2.World:overlap_polygon(vertices, callback)
        local n_points = #vertices
        assert(n_points >= 6 and n_points % 2 == 0 and n_points <= 16)

        for i = 1, n_points do
            meta.assert_typeof(vertices[i], "Number", 1)
        end
        meta.assert_typeof(callback, 2)

        local polygon = b2.Polygon._create_native(vertices) -- already scales
        _overlap_current_callback = callback
        box2d.b2World_OverlapPolygonWrapper(self._native, polygon, b2.IdentityTransform, box2d.b2DefaultQueryFilter(), _overlap_wrapper_callback)
    end

    --- @brief
    --- @param x x_offset
    --- @param y y_offset
    --- @param angle rotation
    --- @param shape b2.Shape
    --- @param callback (b2.Shape) -> Boolean
    function b2.World:overlap_shape(shape, x, y, angle, callback)
        meta.assert(
            shape, "Shape",
            x, "Number",
            y, "Number",
            angle, "Number",
            callback, "Function"
        )

        local native = shape._native
        local transform = box2d.b2MakeTransform(x, y, angle)
        local type = box2d.b2Shape_GetType(native)

        _overlap_current_callback = callback

        if type == box2d.b2_circleShape then
            local circle = box2d.b2Shape_GetCircle(native)
            box2d.b2World_OverlapCircleWrapper(self._native, circle, transform, box2d.b2DefaultQueryFilter(), _overlap_wrapper_callback)
        elseif type == box2d.b2_polygonShape then
            local polygon = box2d.b2Shape_GetPolygon(native)
            box2d.b2World_OverlapPolygonWrapper(self._native, polygon, transform, box2d.b2DefaultQueryFilter(), _overlap_wrapper_callback)
        elseif type == box2d.b2_capsuleShape then
            local capsule = box2d.b2Shape_GetCapsule(native)
            box2d.b2World_OverlapCapsuleWrapper(self._native, capsule, transform, box2d.b2DefaultQueryFilter(), _overlap_wrapper_callback)
        elseif type == box2d.b2_segmentShape then
            rt.error("In b2.World:overlap_shape: Shape type `Segment` unsupported for overlap tests, use World:raycast")
        elseif type == box2d.b2_chainSegmentShape then
            rt.error("In b2.World:overlap_shape: Shape type `ChainSegment` unsupported for overlap tests, use World:raycast")
        else
            rt.error("In b2.Shape:draw: unhandlined shape type `" .. type .. "`")
        end

        _overlap_current_callback = nil
    end
end

--- @param begin_callback Function (b2.Shape, b2.Shape) -> nil
--- @param end_callback Function (b2.Shape, b2.Shape) -> nil
--- @param hit_callback Function (b2.Shape, b2.Shape, normal_x, normal_y, point_x, point_y) -> nil
function b2.World:get_contact_events(begin_callback, end_callback, hit_callback)
    if begin_callback ~= nil then
        meta.assert_typeof(begin_callback, "Function", 1)
    end

    if end_callback ~= nil then
        meta.assert_typeof(end_callback, "Function", 2)
    end

    if hit_callback ~= nil then
        meta.assert_typeof(hit_callback, "Function", 3)
    end

    local native = self._native
    local events = box2d.b2World_GetContactEvents(native)

    if begin_callback ~= nil then
        for i = 1, events.beginCount do
            local event = events.beginEvents[i]
            local native_a, native_b = event.shapeIdA, event.shapeIdB
            if box2d.b2Shape_IsValid(native_a) and box2d.b2Shape_IsValid(native_b) then
                local shape_a = b2.Shape._create_from_native(native_a)
                local shape_b = b2.Shape._create_from_native(native_b)
                begin_callback(shape_a, shape_b)
            end
        end
    end

    if end_callback ~= nil then
        for i = 1, events.endCount do
            local event = events.endEvents[i]
            local native_a, native_b = event.shapeIdA, event.shapeIdB
            if box2d.b2Shape_IsValid(native_a) and box2d.b2Shape_IsValid(native_b) then
                local shape_a = b2.Shape._create_from_native(native_a)
                local shape_b = b2.Shape._create_from_native(native_b)
                end_callback(shape_a, shape_b)
            end
        end
    end

    if hit_callback ~= nil then
        for i = 1, events.hitCount do
            local event = events.hitEvents[i]
            local native_a, native_b = event.shapeIdA, event.shapeIdB
            if box2d.b2Shape_IsValid(native_a) and box2d.b2Shape_IsValid(native_b) then
                local normal_x, normal_y = event.normal.x, event.normal.y
                local point_x, point_y = event.point.x, event.point.y
                local shape_a = b2.Shape._create_from_native(event.shapeIdA)
                local shape_b = b2.Shape._create_from_native(event.shapeIdB)
                hit_callback(shape_a, shape_b, normal_x, normal_y, point_x, point_y)
            end
        end
    end
end

--- @brief
function b2.World:draw()
    box2d.b2World_Draw(self._native, self._debug_draw)
end

function b2.World._bind_color(red, green, blue)
    love.graphics.setColor(red, 1 - green, blue, 0.5)
end

do
    local scale = B2_METER_TO_PIXEL

    --- @brief
    --- void b2DrawPolygonFcn(const b2Vec2* vertices, int vertex_count, float red, float green, float blue);
    b2.World._draw_polygon = ffi.cast("b2DrawPolygonFcn*", function(vertices, vertex_count, red, green, blue)
        b2.World._bind_color(red, green, blue)
        local to_draw = {}
        for i = 1, vertex_count do
            local vec = vertices[i - 1]
            table.insert(to_draw, vec.x * scale)
            table.insert(to_draw, vec.y * scale)
        end

        love.graphics.polygon("line", table.unpack(to_draw))
    end)

    --- @brief
    --- void b2DrawSolidPolygonFcn(b2Transform* transform, const b2Vec2* vertices, int vertex_count, float radius, float red, float green, float blue);
    b2.World._draw_solid_polygon = ffi.cast("b2DrawSolidPolygonFcn*", function(transform, vertices, vertex_count, radius, red, green, blue)
        b2.World._bind_color(red, green, blue)
        local translate_x, translate_y = transform.p.x * scale, transform.p.y * scale
        local angle = math.atan2(transform.q.s, transform.q.c)
        love.graphics.push()
        love.graphics.translate(translate_x, translate_y)
        love.graphics.rotate(angle)

        local to_draw = {}
        for i = 1, vertex_count do
            local vec = vertices[i - 1]
            table.insert(to_draw, vec.x * scale)
            table.insert(to_draw, vec.y * scale)
        end

        love.graphics.polygon("fill", table.unpack(to_draw))
        love.graphics.pop()
    end)

    --- @brief
    --- void b2DrawCircleFcn(b2Vec2* center, float radius, float red, float green, float blue);
    b2.World._draw_circle = ffi.cast("b2DrawCircleFcn*", function(center, radius, red, green, blue)
        b2.World._bind_color(red, green, blue)
        love.graphics.circle("line", center.x * scale, center.y * scale, radius * scale)
    end)

    --- @brief
    --- void b2DrawSolidCircleFcn(b2Transform* transform, float radius, float red, float green, float blue);
    b2.World._draw_solid_circle = ffi.cast("b2DrawSolidCircleFcn*", function(transform, radius, red, green, blue)
        b2.World._bind_color(red, green, blue)
        local translate_x, translate_y = transform.p.x * scale, transform.p.y * scale
        local angle = math.atan2(transform.q.s, transform.q.c)
        love.graphics.push()
        love.graphics.translate(translate_x, translate_y)
        love.graphics.rotate(angle)
        love.graphics.circle("fill", 0, 0, radius * scale)
        love.graphics.circle("line", 0, 0, radius * scale)

        love.graphics.pop()
    end)

    --- @brief
    --- void b2DrawSolidCapsuleFcn(b2Vec2* p1, b2Vec2* p2, float radius, float red, float green, float blue);
    b2.World._draw_solid_capsule = ffi.cast("b2DrawSolidCapsuleFcn*", function(p1, p2, radius, red, green, blue)
        local x1, y1, x2, y2 = p1.x * scale, p1.y * scale, p2.x * scale, p2.y * scale

        local dx = x2 - x1
        local dy = y2 - y1
        local length = math.sqrt(dx * dx + dy * dy)
        local angle = math.atan2(dy, dx)
        local radius = radius * scale

        love.graphics.push()
        love.graphics.translate(x1, y1)
        love.graphics.rotate(angle)

        b2.World._bind_color(red, green, blue)

        love.graphics.rectangle("fill", 0, -radius, length, 2 * radius)
        love.graphics.arc("fill", length, 0, radius, -math.pi / 2, math.pi / 2)
        love.graphics.arc("fill", 0, 0, radius, math.pi / 2, 3 * math.pi / 2)

        love.graphics.arc("line", length, 0, radius, -math.pi / 2, math.pi / 2)
        love.graphics.arc("line", 0, 0, radius, math.pi / 2, 3 * math.pi / 2)

        love.graphics.line(0, -radius, length, -radius)
        love.graphics.line(0, radius, length, radius)

        love.graphics.rotate(-angle)
        love.graphics.translate(-x1, -y1)
        love.graphics.pop()
    end)

    --- @brief
    --- void b2DrawSegmentFcn(b2Vec2* p1, b2Vec2* p2, float red, float green, float blue);
    b2.World._draw_segment = ffi.cast("b2DrawSegmentFcn*", function(p1, p2, red, green, blue)
        love.graphics.setColor(red, green, blue)
        love.graphics.line(p1.x * scale, p1.y * scale, p2.x * scale, p2.y * scale)
    end)

    --- @brief
    --- void b2DrawTransformFcn(b2Transform*)
    b2.World._draw_transform = ffi.cast("b2DrawTransformFcn*", function(transform)
        local translate_x, translate_y = transform.p.x * scale, transform.p.y * scale
        local angle = math.atan2(transform.q.s, transform.q.c)
        -- noop
    end)

    --- @brief
    --- void b2DrawPointFcn(b2Vec2* p, float size, float red, float green, float blue);
    b2.World._draw_point = ffi.cast("b2DrawPointFcn*", function(p, size, red, green, blue)
        love.graphics.setColor(red, green, blue)
        love.graphics.circle("fill", p.x * scale, p.y * scale, size / 2)
    end)

    --- @brief
    --- void b2DrawString(b2Vec2* p, const char* s);
    b2.World._draw_string = ffi.cast("b2DrawString*", function(p, s)
        love.graphics.printf(ffi.string(s), p.x * scale, p.y * scale, POSITIVE_INFINITY)
    end)

end
