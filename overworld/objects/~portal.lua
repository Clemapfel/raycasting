--- @class ow.Portal
ow.Portal = meta.class("Portal")

--- @class ow.PortalNode
ow.PortalNode = meta.class("PortalNode") -- dummy

local _assert_point = function(object)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Portal: object `" .. object:get_id() .. " is not a point")
end

local _windedness = function(ax, ay, bx, by)
    return ax * by - ay * bx
end

function ow.Portal:_get_side(px, py)
    local v =  math.cross(
        self._bx - self._ax, self._by - self._ay,
        px - self._ax, py - self._ay
    )
    if v == 0 then return nil else return v > 0 end
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

        self._sidedness = _windedness(self._ax, self._ay, self._bx, self._by)

        self._target = stage:get_object_instance(object:get_object("target", true))
        assert(self._target ~= nil and meta.isa(self._target, ow.Portal), "In ow.Portal: `target` of object `" .. object:get_id() .. "` is not another portal")

        -- create sensor area
        local sensor_w = rt.settings.player.radius
        local dx, dy = self._ax - self._bx, self._ay - self._by
        local left_x, left_y = math.normalize(math.turn_left(dx, dy))
        local right_x, right_y = math.normalize(math.turn_right(dx, dy))
        local center_x, center_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)

        -- ghost collision guards
        self._top_left_segment = b2.Body(
            stage:get_physics_world(),
            b2.BodyType.STATIC,
            self._ax, self._ay,
            b2.Segment(
                0 + left_x * sensor_w, 0 + left_y * sensor_w,
                0, 0
            )
        )

        self._top_right_segment = b2.Body(
            stage:get_physics_world(),
            b2.BodyType.STATIC,
            self._ax, self._ay,
            b2.Segment(
                0, 0,
                0 + right_x * sensor_w, 0 + right_y * sensor_w
            )
        )

        self._bottom_left_segment = b2.Body(
            stage:get_physics_world(),
            b2.BodyType.STATIC,
            self._bx, self._by,
            b2.Segment(
                0 + left_x * sensor_w, 0 + left_y * sensor_w,
                0, 0
            )
        )

        self._bottom_right_segment = b2.Body(
            stage:get_physics_world(),
            b2.BodyType.STATIC,
            self._bx, self._by,
            b2.Segment(
                0, 0,
                0 + right_x * sensor_w, 0 + right_y * sensor_w
            )
        )

        self._left_segment = b2.Body(
            stage:get_physics_world(),
            b2.BodyType.STATIC,
            center_x, center_y,
            b2.Segment(
                0 + left_x * sensor_w - 0.5 * dx, 0 + left_y * sensor_w - 0.5 * dy,
                0 + left_x * sensor_w + 0.5 * dx, 0 + left_y * sensor_w + 0.5 * dy
            )
        )

        self._right_segment = b2.Body(
            stage:get_physics_world(),
            b2.BodyType.STATIC,
            center_x, center_y,
            b2.Segment(
                0 + right_x * sensor_w - 0.5 * dx, 0 + right_y * sensor_w - 0.5 * dy,
                0 + right_x * sensor_w + 0.5 * dx, 0 + right_y * sensor_w + 0.5 * dy
            )
        )

        self._segment_sensor = b2.Body(
            stage:get_physics_world(),
            b2.BodyType.STATIC,
            center_x, center_y,
            b2.Segment(self._ax - center_x, self._ay - center_y, self._bx - center_x, self._by - center_y)
        )
        self._segment_sensor:set_is_sensor(true)
        self._segment_sensor:set_collides_with(rt.settings.player.player_collision_group)
        self._segment_sensor:signal_connect("collision_start", function()
            if not self._is_disabled and self._disabled_cooldown <= 0 then
                self:_teleport()
            end
        end)

        for segment in range(
            self._top_left_segment,
            self._top_right_segment,
            self._left_segment,
            self._bottom_left_segment,
            self._bottom_right_segment,
            self._right_segment
        ) do
            segment:set_collision_group(rt.settings.player.ghost_collision_group)
            segment:set_collides_with(rt.settings.player.player_collision_group)
            segment:add_tag("slippery")
            segment:set_is_sensor(true)
        end

        local sensor_shape = b2.Polygon(
            self._ax +  left_x * sensor_w - center_x, self._ay +  left_y * sensor_w - center_y,
            self._ax + right_x * sensor_w - center_x, self._ay + right_y * sensor_w - center_y,
            self._bx + right_x * sensor_w - center_x, self._by + right_y * sensor_w - center_y,
            self._bx +  left_x * sensor_w - center_x, self._by +  left_y * sensor_w - center_y
        )

        self._sensor = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC, center_x, center_y, sensor_shape)
        self._sensor:set_is_sensor(true)

        self._sensor:signal_connect("collision_start", function()
            self._is_active = true

            -- enable opposite side of cage
            local px, py = self._scene:get_player():get_position()
            local left = self:_get_side(px, py) == true
            self._left_segment:set_is_sensor(left)
            self._top_left_segment:set_is_sensor(left)
            self._bottom_left_segment:set_is_sensor(left)

            local right = not left
            self._top_right_segment:set_is_sensor(right)
            self._bottom_right_segment:set_is_sensor(right)
            self._right_segment:set_is_sensor(right)
        end)

        self._was_in_sensor = self._sensor:test_point(self._scene:get_player():get_position())
        self._is_active = self._was_in_sensor
        self._last_side = self:_get_side(self._scene:get_player():get_position())
        self._is_disabled = false
        self._disabled_cooldown = 0
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

    for segment in range(
        self._top_left_segment,
        self._top_right_segment,
        self._bottom_left_segment,
        self._bottom_right_segment,
        self._left_segment,
        self._right_segment
    ) do
        if segment:get_is_sensor() then
            love.graphics.setColor(1, 0, 1, 0.5)
        else
            love.graphics.setColor(1, 0, 1, 1)
        end
        segment:draw()
    end
end

local _get_ratio = function(px, py, ax, ay, bx, by)
    local abx, aby = bx - ax, by - ay
    local apx, apy = px - ax, py - ay

    local ab_length_squared = math.dot(abx, aby, abx, aby)
    local t = math.dot(apx, apy, abx, aby) / ab_length_squared
    return math.max(0, math.min(1, t))
end

local _reflect = function(vx, vy, ax, ay, bx, by)
    local seg_x, seg_y = bx - ax, by - ay
    local normal_x, normal_y = math.normalize(-seg_y, seg_x)

    -- Calculate the dot product of velocity and normal
    local dot = math.dot(vx, vy, normal_x, normal_y)

    -- Reflect the velocity using the formula: v' = v - 2 * (v . n) * n
    local reflected_vx = vx - 2 * dot * normal_x
    local reflected_vy = vy - 2 * dot * normal_y

    return reflected_vx, reflected_vy
end

local _teleport_velocity = function(vx, vy, source_ax, source_ay, source_bx, source_by, target_ax, target_ay, target_bx, target_by)
    -- Calculate the direction vectors of the source and target segments
    local source_dx, source_dy = source_bx - source_ax, source_by - source_ay
    local target_dx, target_dy = target_bx - target_ax, target_by - target_ay

    -- Normalize the direction vectors
    source_dx, source_dy = math.normalize(source_dx, source_dy)
    target_dx, target_dy = math.normalize(target_dx, target_dy)

    -- Calculate the rotation needed to align the source segment with the target segment
    local rotation_cos = math.dot(target_dx, target_dy, source_dx, source_dy)
    local rotation_sin = math.cross(target_dx, target_dy, source_dx, source_dy)

    -- Rotate the velocity vector
    local new_vx = vx * rotation_cos - vy * rotation_sin
    local new_vy = vx * rotation_sin + vy * rotation_cos

    return new_vx, new_vy
end

function ow.Portal:_teleport()
    local player = self._scene:get_player()
    local px, py = player:get_position()
    local target = self._target

    -- disable to prevent loops
    target:_disable()
    self:_disable()

    -- project onto other line segment
    local ratio = _get_ratio(px, py, self._ax, self._ay, self._bx, self._by)

    player:teleport_to(math.mix2(target._ax, target._ay, target._bx, target._by, ratio))
    local vx, vy = player:get_velocity()
    vx, vy = _teleport_velocity(vx, vy, self._ax, self._ay, self._bx, self._by, target._ax, target._ay, target._bx, target._by)
    if self._sidedness ~= target._sidedness then
        vx, vy = _reflect(vx, vy, target._ax, target._ay, target._bx, target._by)
    end

    player:set_velocity(vx, vy)
    target._is_active = true
end

function ow.Portal:_disable()
    self._is_disabled = true
    self._disable_cooldown = 2
end

--- @brief
function ow.Portal:update(delta)
    local is_in_sensor
    if self._is_active then
        -- manually detect exit / enter, since collision_start set_ghost triggers collision_end
        is_in_sensor = self._sensor:test_point(self._scene:get_player():get_position())
        if self._was_in_sensor == false and is_in_sensor == true then
            --self._scene:get_player():set_is_ghost(true)
        elseif self._was_in_sensor == true and is_in_sensor == false then
            --self._scene:get_player():set_is_ghost(false)

            for segment in range(
                self._top_left_segment,
                self._top_right_segment,
                self._left_segment,
                self._bottom_left_segment,
                self._bottom_right_segment,
                self._right_segment
            ) do
                segment:set_is_sensor(true)
            end

            self._is_active = false

            if self._disabled_cooldown <= 0 then
                self._is_disabled = false -- disabled when player leaves sensor
            end
        end
        self._was_in_sensor = is_in_sensor
    end

    -- manually detect crossing
    if not self._is_disabled and self._disabled_cooldown <= 0 and is_in_sensor then
        local player = self._scene:get_player()
        local px, py = player:get_position()

        local current_side = self:_get_side(px, py)
        local last_side = self._last_side
        if current_side ~= last_side then
            --self:_teleport()
        end
    end

    if self._disabled_cooldown > 0 then
        self._disabled_cooldown = self._disabled_cooldown - 1
    end
end

--- @brief
function ow.Portal:get_render_priority()
    return 1
end

function _reflect_velocity(contact_x, contact_y, dx, dy, normal_x, normal_y)
    local self_x, self_y = self._object.x, self._object.y
    local other_x, other_y = self._target.x, self._target.y
    local self_angle, other_angle = self._object.rotation, self._target.rotation

    -- Rotate contact point by the negative angle of the first rectangle around its top-left corner
    local cos_self = math.cos(-self_angle)
    local sin_self = math.sin(-self_angle)
    local rotated_x = (contact_x - self_x) * cos_self - (contact_y - self_y) * sin_self
    local rotated_y = (contact_x - self_x) * sin_self + (contact_y - self_y) * cos_self

    -- Rotate direction vector by the negative angle of the first rectangle
    local rotated_dx = dx * cos_self - dy * sin_self
    local rotated_dy = dx * sin_self + dy * cos_self

    -- Rotate contact point by the angle of the second rectangle around its top-left corner
    local cos_other = math.cos(other_angle)
    local sin_other = math.sin(other_angle)
    local final_x = rotated_x * cos_other - rotated_y * sin_other
    local final_y = rotated_x * sin_other + rotated_y * cos_other

    -- Rotate direction vector by the angle of the second rectangle
    local final_dx = rotated_dx * cos_other + rotated_dy * sin_other
    local final_dy = rotated_dx * sin_other - rotated_dy * cos_other

    -- Translate to the position of the second rectangle
    local new_contact_x = final_x + other_x
    local new_contact_y = final_y + other_y

    return new_contact_x, new_contact_y, final_dx, final_dy
end