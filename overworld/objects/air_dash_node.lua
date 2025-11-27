require "common.path"

rt.settings.overworld.air_dash_node = {
    core_radius = 10,
    cooldown = 25 / 60
}

--- @class AirDashNode
--- @types Point
ow.AirDashNode = meta.class("AirDashNode")

local _handler, _is_first = true
function ow.AirDashNode:reinitialize()
    _handler = nil
    _is_first = true
end

--- @brief
function ow.AirDashNode:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.ELLIPSE and math.equals(object.x_radius, object.y_radius), "In ow.AirDashNode: object `" .. object:get_id() .. "` is not a circle")

    self._x, self._y = object:get_centroid()
    self._radius = object.x_radius

    self._scene = scene
    self._stage = stage

    -- dummy collision, for camera queries
    self._body = b2.Body(
        stage:get_physics_world(),
        b2.BodyType.STATIC,
        self._x, self._y,
        b2.Circle(0, 0, self._radius)
    )

    self._body:set_is_sensor(true)
    self._body:set_collides_with(0x0)
    self._body:set_collision_group(0x0)

    -- if the player would initiate tether, this is the target
    self._is_current = false

    -- player is currently tethered
    self._is_tethered = false

    self._cooldown_elapsed = math.huge

    -- graphics
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, rt.random.number(0, 1), 1))

    if _is_first then -- first node is proxy instance
        require "overworld.air_dash_node_handler"
        _handler = ow.AirDashNodeHandler(self._scene, self._stage)
        self._update_handler = true
        _is_first = false
    else
        self._update_handler = false
    end

    -- add to global handler
    _handler:notify_node_added(self)
end

--- @brief
function ow.AirDashNode:set_is_tethered(b)
    self._is_tethered = b

    if b == false then
        self._cooldown_elapsed = 0
    end
end

--- @brief
function ow.AirDashNode:set_is_current(b)
    self._is_current = b
end

--- @brief
function ow.AirDashNode:get_position()
    return self._x, self._y
end

--- @brief
function ow.AirDashNode:get_radius()
    return self._radius
end

--- @brief
function ow.AirDashNode:get_body()
    return self._body
end

--- @brief
function ow.AirDashNode:get_is_on_cooldown()
    return self._cooldown_elapsed < rt.settings.overworld.air_dash_node.cooldown
end

--- @brief
function ow.AirDashNode:update(delta)
    if self._update_handler then _handler:update(delta) end

    if not self._is_tethered then
        self._cooldown_elapsed = self._cooldown_elapsed + delta
    end

    local is_visible = self._stage:get_is_body_visible(self._body)
end

--- @brief
function ow.AirDashNode:draw()
    if not self._stage:get_is_body_visible(self._body) then return end
    local r, g, b, a = self._color:unpack()

    if self._is_current then
        love.graphics.setColor(r, g, b, 0.5)
        love.graphics.circle("line", self._x, self._y, self._radius)
    end

    if self._is_current or self._is_tethered then
        local px, py = self._scene:get_player():get_position()
        love.graphics.line(px, py, self._x, self._y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self._x, self._y, rt.settings.overworld.air_dash_node.core_radius)
end

--- @brief
function ow.AirDashNode:draw_bloom()
    -- todo
end

--- @brief
function ow.AirDashNode:get_color()
    return self._color
end

--- @brief
function ow.AirDashNode:get_render_priority()
    return -1
end
