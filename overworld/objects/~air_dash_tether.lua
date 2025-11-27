require "common.path"

rt.settings.overworld.air_dash_tether = {
    radius_factor = 1,
    dash_duration = 0.5, -- seconds
    dash_velocity = 2000
}

--- @class AirDashTether
--- @types Point
ow.AirDashTether = meta.class("AirDashThether")

local _current_hue_step = 1
local _hue_steps, _n_hue_steps = {}, 8
do
    for i = 0, _n_hue_steps - 1 do
        table.insert(_hue_steps, i / _n_hue_steps)
    end
    rt.random.shuffle(_hue_steps)
end

--- @brief
function ow.AirDashTether:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.ELLIPSE and object.x_radius == object.y_radius, "In ow.AirDashTether: tiled object is not a circle")

    self._x, self._y = object.center_x, object.center_y
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

    -- sim
    self._is_active = false
    self._is_blocked = false

    self._player_vx, self._player_vy = 0, 0
    self._tether_elapsed = 0
    self._tether_path = rt.Path(0, 0, 0, 0)
    self._tether_goal_line = { self._x, self.x, self._x, self._y }
    self._tether_goal_sign = 0

    -- graphics
    self._hue = _hue_steps[_current_hue_step]
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    _current_hue_step = _current_hue_step % _n_hue_steps + 1

    self._sensor_fill_draw = { self._x, self._y, self._radius } -- love.Circle
    self._sensor_outline_draw = {}
    self._tether_draw = { self._x, self._y, self._x, self._y }

    local n_outer_vertices = 0.5 * self._radius
    for i = 1, n_outer_vertices + 1, 1 do
        local angle = (i - 1) / n_outer_vertices * 2 * math.pi
        table.insert(self._sensor_outline_draw, self._x + math.cos(angle) * self._radius)
        table.insert(self._sensor_outline_draw, self._y + math.sin(angle) * self._radius)
    end

    self._core_mesh = rt.MeshCircle(self._x, self._y, rt.settings.overworld.air_dash_tether.radius_factor * rt.settings.player.radius)
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, rt.random.number(0, 1), 1))
end

function _get_side(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1

    local dpx = px - x1
    local dpy = py - y1

    return math.sign(math.cross(dx, dy, dpx, dpy))
end

--- @brief
function ow.AirDashTether:update(delta)
    local player = self._scene:get_player()
    local px, py = player:get_position()

    if not self._is_active then
        local dx, dy = math.normalize(self._x - px, self._y - py)
        self._dbg = {
            self._x +  dx * self._radius,
            self._y +  dy * self._radius,
            self._x + -dx * self._radius,
            self._y + -dy * self._radius
        }
    end

    local active_radius = (self._radius + 2 * player:get_radius())
    local distance = math.distance(px, py, self._x, self._y)

    if self._is_active then
        self._tether_draw = { self._x, self._y, px, py }
        self._tether_elapsed = self._tether_elapsed + delta

        local t = self._tether_elapsed / rt.settings.overworld.air_dash_tether.dash_duration
        local target_x, target_y = self._tether_path:at(t)
        local tangent_x, tangent_y = self._tether_path:get_tangent(t)
        local current_x, current_y = player:get_position()
        local player_vx, player_vy = player:get_velocity()
        local target_velocity = rt.settings.overworld.air_dash_tether.dash_velocity
        target_velocity = target_velocity * rt.InterpolationFunctions.SINUSOID_EASE_IN(t)

        local target_vx = target_velocity * -tangent_x
        local target_vy = target_velocity * -tangent_y

        -- Calculate position error
        local pos_error_x = target_x - current_x
        local pos_error_y = target_y - current_y

        -- Calculate remaining time
        local remaining_time = (1 - t) * rt.settings.overworld.air_dash_tether.dash_duration

        -- Calculate correction velocity needed to reach target position
        local correction_vx = pos_error_x / remaining_time
        local correction_vy = pos_error_y / remaining_time

        -- Blend between current velocity trajectory and corrected velocity
        local blend = math.min(t / 1, 1)
        player:set_velocity(
            player_vx + (target_vx + correction_vx - player_vx) * blend,
            player_vy + (target_vy + correction_vy - player_vy) * blend
        )

        player:set_velocity(target_vx, target_vy)

        if _get_side(px, py, table.unpack(self._tether_goal_line)) ~= self._tether_goal_sign then
            player:set_velocity(target_vx, target_vy)
            self._is_active = false
            self._is_blocked = true
        end
    end

    if distance > active_radius then self._is_blocked = false end

    if not self._stage:get_is_body_visible(self._sensor) then return end

    -- update opacity
    local opacity_radius = 2 * self._radius
    if distance < self._radius then
        self._color.a = 1
    else
        self._color.a = 1 - (distance - self._radius) / opacity_radius
    end

    if self._is_active == false and self._is_blocked == false then
        -- tether
        if distance < active_radius then
            self._is_active = true
            self._is_blocked = true

            self._tether_draw = { self._x, self._y, px, py }
            self._tether_elapsed = 0

            local dx, dy = math.normalize(self._x - px, self._y - py)
            self._tether_path = rt.Path(
                self._x +  dx * self._radius,
                self._y +  dy * self._radius,
                self._x, -- + -dx * self._radius,
                self._y -- + -dy * self._radius
            )

            local left_x, left_y = math.turn_left(dx, dy)
            local right_x, right_y = math.turn_right(dx, dy)
            self._tether_goal_line = {
                self._x + left_x * self._radius,
                self._y + left_y * self._radius,
                self._x + right_x * self._radius,
                self._y + right_y * self._radius
            }

            self._tether_goal_sign = _get_side(px, py, table.unpack(self._tether_goal_line))

            self._tether_start_velocity = math.magnitude(player:get_velocity())


            self._dbg = {
                self._x +  dx * self._radius,
                self._y +  dy * self._radius,
                self._x + -dx * self._radius,
                self._y + -dy * self._radius
            }

        end
    elseif self._is_active == true then
        -- untether
        if distance > (self._radius + 2 * player:get_radius()) then
            self._is_active = false
            self._tether_draw = { self._x, self._y, self._x, self._y }
        end
    end

    -- apply force
    if self._is_active then
        self._tether_elapsed = self._tether_elapsed + delta
        local player_x, player_y = px, py
        local player_vx, player_vy = player:get_velocity()
        local attachment_x, attachment_y = self._x, self._y
        local attachment_vx, attachment_vy = self._sensor:get_velocity()
        local distance = math.distance(player_x, player_y, attachment_x, attachment_y)
    end
end

--- @brief
function ow.AirDashTether:get_render_priority()
    return -1
end

--- @brief
function ow.AirDashTether:draw()
    if not self._stage:get_is_body_visible(self._sensor) then return end
    local r, g, b, a = self._color:unpack()

    love.graphics.setColor(r, g, b, a)
    love.graphics.circle("fill", table.unpack(self._sensor_fill_draw))

    love.graphics.setColor(r, g, b, math.max(0.5, a))
    love.graphics.line(self._sensor_outline_draw)

    love.graphics.setColor(1, 1, 1, 1)
    self._core_mesh:draw()

    if self._is_active then
        love.graphics.line(self._tether_draw)
    end

    love.graphics.line(self._dbg)
end

--- @brief
function ow.AirDashTether:draw_bloom()
end

--- @brief
function ow.AirDashTether:get_color()
    return self._color
end

--- @brief
function ow.AirDashTether:reset()
    local player = self._scene:get_player()
    if player:get_is_air_dash_source(self) then
        player:remove_air_dash_source(self)
        self:update(0)
    end
end
