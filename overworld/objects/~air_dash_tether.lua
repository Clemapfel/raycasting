require "common.path"

rt.settings.overworld.air_dash_node = {
    core_radius = 10,
    dash_duration = 0.5, -- seconds
    dash_velocity = 1100, -- on exit
    dash_cooldown = 25 / 60
}

--- @class AirDashNode
--- @types Point
ow.AirDashNode = meta.class("AirDashNode")

local _handler, _is_first = true
function ow.AirDashNode:reinitialize()
    require "overworld.objects.air_dash_node_manager"
    _handler = ow.AirDashNodeManager()
end
ow.AirDashNode:reinitialize()

--- @brief
function ow.AirDashNode:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.ELLIPSE and math.equals(object.x_radius, object.y_radius), "In ow.AirDashNode: object `" .. object:get_id() .. "` is not a circle")

    self._x, self._y = object:get_centroid()
    self._radius = object.x_radius

    self._scene = scene
    self._stage = stage

    -- collision
    self._sensor = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.STATIC,
        self._x, self._y,
        b2.Circle(0, 0, self._radius)
    )

    self._sensor:set_is_sensor(true)
    self._sensor:set_collides_with(rt.settings.player.bounce_collision_group)
    self._sensor:set_collision_group(rt.settings.player.bounce_collision_group)

    -- tether
    self._is_active = false
    self._is_tethered = false
    self._is_blocked = false

    self._tether_path = nil -- rt.Path
    self._tether_elapsed = math.huge
    self._tether_sign = 0
    self._tether_sign_line = { 0, 0, 0, 0 } -- Array<Number, 4>

    self._cooldown_elapsed = math.huge

    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        if which == rt.InputAction.JUMP then
            if not self._is_blocked and self._cooldown_elapsed >= rt.settings.overworld.air_dash_node.dash_cooldown then
                self:_tether()
            elseif self._is_tethered then
                self:_untether()
            end
        end
    end)
    self._input:deactivate()

    -- graphics
    self._sensor_circle = { self._x, self._y, self._radius } -- love.Circle
    self._core_circle = { self._x, self._y, rt.settings.overworld.air_dash_node.core_radius } -- love.Circle
    self._path_line = { self._x, self._y, self._x, self._y } -- love.Line

    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, rt.random.number(0, 1), 1))

    -- global handler
    _handler:notify_node_add(self)
    self._update_handler = _is_first -- first instance forwards update
    _is_first = false
end

local function _get_side(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1

    local dpx = px - x1
    local dpy = py - y1

    return math.sign(math.cross(dx, dy, dpx, dpy))
end

--- @brief
function ow.AirDashNode:_tether()
    if self._tether_path == nil then self:update(0) end

    self._is_tethered = true
    self._tether_elapsed = 0

    local player = self._scene:get_player()
    local px, py = player:get_position()
    local dx, dy = math.normalize(self._x - px, self._y - py)

    local left_x, left_y = math.turn_left(dx, dy)
    local right_x, right_y = math.turn_right(dx, dy)

    local end_x, end_y = self._tether_path:at(0)
    self._tether_sign_line = {
        end_x + left_x * self._radius,
        end_y + left_y * self._radius,
        end_x + right_x * self._radius,
        end_y + right_y * self._radius
    }

    self._tether_sign = _get_side(
        px, py, table.unpack(self._tether_sign_line)
    )

    self._is_blocked = true
end

--- @brief
function ow.AirDashNode:_untether()
    self._is_tethered = false
    self._is_blocked = false
    self._cooldown_elapsed = 0
end

--- @brief
function ow.AirDashNode:update(delta)
    if self._update_handler then _handler:update(delta) end

    local player = self._scene:get_player()
    local px, py = player:get_position()

    local is_visible = self._stage:get_is_body_visible(self._sensor)

    if not self._is_tethered then
        self._cooldown_elapsed = self._cooldown_elapsed + delta
    end

    -- manually check if player in range, box2d sensor to unreliable
    local before = self._is_active
    local now = math.distance(px, py, self._x, self._y) < self._radius + player:get_radius()
    self._is_active = now

    if before == false and now == true then
        self._input:activate()
    elseif before == true and now == false then
        self._input:deactivate()
    end

    -- update velocity when tethered
    if self._is_tethered then
        local duration = rt.settings.overworld.air_dash_node.dash_duration
        local target_velocity = rt.settings.overworld.air_dash_node.dash_velocity

        local ax, ay = self._tether_path:at(0)
        local bx, by = self._tether_path:at(1)
        local t = rt.InterpolationFunctions.SINUSOID_EASE_IN(
            math.mix(0.5, 1, (1 - math.distance(px, py, self._x, self._y) / math.distance(ax, ay, bx, by)))
        )

        local tangent_x, tangent_y = self._tether_path:get_tangent(t)

        local target_vx = t * target_velocity * -tangent_x
        local target_vy = t * target_velocity * -tangent_y

        player:set_velocity(target_vx, target_vy)
        self._tether_elapsed = self._tether_elapsed + delta

        if _get_side(px, py, table.unpack(self._tether_sign_line)) ~= self._tether_sign
            or (t > 0.5 and #(player:get_colliding_bodies()) ~= 0) -- if past mid point, skip if hitting obstacle
        then
            player:set_velocity(target_vx, target_vy) -- exit velocity always consistent
            self:_untether()
        end
    end

    if is_visible then
        -- update opacity
        local opacity_radius = 2 * self._radius
        local distance = math.distance(px, py, self._x, self._y)
        if distance < self._radius then
            self._color.a = 1
        else
            self._color.a = 1 - (distance - self._radius) / opacity_radius
        end

        -- update path: reflect player to center through center
        if not self._is_tethered and not self._is_blocked then
            local dx, dy = math.normalize(self._x - px, self._y - py)
            local r = math.min(self._radius, math.distance(px, py, self._x, self._y))
            local ax = self._x --+  dx * r
            local ay = self._y --+  dy * r
            local bx = self._x + -dx * r
            local by = self._y + -dy * r

            self._tether_path = rt.Path(ax, ay, bx, by)

            local overshoot = 50
            self._path_line = {
                bx, by,
                self._x + dx * overshoot, self._y + dy * overshoot
            }
        end
    end
end

--- @brief
function ow.AirDashNode:draw()
    if not self._stage:get_is_body_visible(self._sensor) then return end
    local r, g, b, a = self._color:unpack()

    if not self._is_blocked and self._cooldown_elapsed >= rt.settings.overworld.air_dash_node.dash_cooldown then
        love.graphics.setColor(r, g, b, a)
        --love.graphics.circle("fill", table.unpack(self._sensor_circle))

        love.graphics.setColor(r, g, b, math.max(a, 0.5))
        love.graphics.circle("line", table.unpack(self._sensor_circle))
    end

    if self._is_active then
        love.graphics.line(self._path_line)

        if self._is_tethered then
            love.graphics.line(self._tether_sign_line)
        end
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", table.unpack(self._core_circle))
end

--- @brief
function ow.AirDashNode:draw_bloom()
end

--- @brief
function ow.AirDashNode:get_color()
    return self._color
end

--- @brief
function ow.AirDashNode:get_render_priority()
    return -1
end
