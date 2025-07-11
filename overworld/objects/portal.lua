--- @class ow.Portal
ow.Portal = meta.class("Portal")

--- @class ow.PortalNode
ow.PortalNode = meta.class("PortalNode") -- dummy

local _assert_point = function(object)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Portal: object `" .. object:get_id() .. " is not a point")
end

local _get_side = function(px, py, ax, ay, bx, by)
    return math.cross(
        bx - ax, by - ay,
        px - ax, py - ay
    ) > 0
end

--- @brief
function ow.Portal:instantiate(object, stage, scene)
    self._stage = stage
    self._scene = scene

    stage:signal_connect("initialized", function()
        -- get portal pairs as ordered points
        self._a = object
        _assert_point(self._a)
        self._ax, self._ay = object.x, object.y

        self._b = object:get_object("other", true)
        _assert_point(self._b)
        self._bx, self._by = self._b.x, self._b.y

        self._target = stage:get_object_instance(object:get_object("target", true))
        assert(self._target ~= nil and meta.isa(self._target, ow.Portal), "In ow.Portal: `target` of object `" .. object:get_id() .. "` is not another portal")

        -- create sensor area
        local sensor_w = rt.settings.player.radius * 4
        local dx, dy = self._ax - self._bx, self._ay - self._by
        local left_x, left_y = math.normalize(math.turn_left(dx, dy))
        local right_x, right_y = math.normalize(math.turn_right(dx, dy))
        local center_x, center_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)

        local sensor_shape = b2.Polygon(
            self._ax +  left_x * sensor_w - center_x, self._ay +  left_y * sensor_w - center_y,
            self._ax + right_x * sensor_w - center_x, self._ay + right_y * sensor_w - center_y,
            self._bx + right_x * sensor_w - center_x, self._by + right_y * sensor_w - center_y,
            self._bx +  left_x * sensor_w - center_x, self._by +  left_y * sensor_w - center_y
        )

        self._ghost_sensor = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC, center_x, center_y, sensor_shape)
        self._non_ghost_sensor = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC, center_x, center_y, sensor_shape)

        for sensor in range(self._ghost_sensor, self._non_ghost_sensor) do
            sensor:set_is_sensor(true)
            sensor:set_collides_with(rt.settings.player.player_collision_group)
        end

        self._ghost_sensor:set_collision_group(rt.settings.player.ghost_collision_group)
        self._non_ghost_sensor:set_collision_group(bit.bnot(rt.settings.player.ghost_collision_group))

        -- manually collect events to assure order of operations
        self._events = {}
        self._non_ghost_sensor:signal_connect("collision_start", function()
            table.insert(self._events, 0)
        end)

        self._ghost_sensor:signal_connect("collision_end", function()
            table.insert(self._events, 1)
        end)

        -- ghost collision guards
        self._ghost_segments = {}
        local add_segment = function(x, y)
            local segment = b2.Body(
                stage:get_physics_world(),
                b2.BodyType.STATIC,
                x, y,
                b2.Segment(
                    0 + left_x * sensor_w, 0 + left_y * sensor_w,
                    0 + right_x * sensor_w, 0 + right_y * sensor_w
                )
            )

            segment:set_collision_group(rt.settings.player.ghost_collision_group)
            table.insert(self._ghost_segments, segment)
        end

        add_segment(self._ax, self._ay)
        add_segment(self._bx, self._by)
    end)
end

--- @brief
function ow.Portal:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(3)
    love.graphics.setPointSize(5)
    love.graphics.points(self._ax, self._ay, self._bx, self._by)
    love.graphics.line(self._ax, self._ay, self._bx, self._by)

    love.graphics.setLineWidth(1)
    love.graphics.setColor(1, 0, 1, 1)
    local other = self._target

    local ax, ay = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)
    local bx, by = math.mix2(other._ax, other._ay, other._bx, other._by, 0.5)
    love.graphics.line(ax, ay, bx, by)

    --self._sensor:draw()
    for segment in values(self._ghost_segments) do
        segment:draw()
    end
end

--- @brief
function ow.Portal:update(delta)
    if #self._events ~= 0 then
        local is_ghost = self._scene:get_player():get_is_ghost()
        table.sort(self._events, function(a, b)
            if is_ghost then return a > b else return a < b end
        end)

        for event in values(self._events) do
            if event == 0 then
                self._scene:get_player():set_is_ghost(true)
            elseif event == 1 then
                self._scene:get_player():set_is_ghost(true)
            end
        end

        self._events = {}
    end
end

--- @brief
function ow.Portal:get_render_priority()
    return 1
end