require "common.path"
require "overworld.objects.air_dash_node"
require "overworld.movable_object"

rt.settings.overworld.directional_air_dash_node = {

}

--- @class DirectionalAirDashNode
--- @types Circle
ow.DirectionalAirDashNode = meta.class("DirectionalAirDashNode", ow.MovableObject)

--- @class DirectionalAirDashNodeDirection
--- @types Point
ow.DirectionalAirDashNodeDirection = meta.class("DirectionalAirDashNode")

--- @brief
function ow.DirectionalAirDashNode:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.ELLIPSE and math.equals(object.x_radius, object.y_radius), "In ow.DirectionalAirDashNode: object `" .. object:get_id() .. "` is not a circle")

    if stage.air_dash_node_manager_is_first == true then
        self._is_handler_proxy = true
    else
        self._is_handler_proxy = false
    end

    self._x, self._y = object:get_centroid()
    self._radius = object.x_radius

    self._scene = scene
    self._stage = stage

    -- dummy collision, for camera queries
    self._body = b2.Body(
        stage:get_physics_world(),
        object:get_physics_body_type(),
        self._x, self._y,
        b2.Circle(0, 0, self._radius)
    )

    self._body:set_is_sensor(true)
    self._body:set_collides_with(0x0)
    self._body:set_collision_group(0x0)
    self._body:add_tag("point_light_source")
    self._body:set_user_data(self)

    local direction = object:get_object("direction", true)
    rt.assert(direction:get_type() == ow.ObjectType.POINT, "In ow.DirectionalAirDashNode: direction object `", direction:get_id(), "` is not a point")
    self._direction_x, self._direction_y = math.normalize(
        direction.x - self._x,
        direction.y - self._y
    )

    self._is_current = false -- if the player initiates tether, this is the target
    self._is_tethered = false -- player is currently tethered
    self._cooldown_elapsed = math.huge

    if scene.air_dash_node_hue == nil then -- sic
        scene.air_dash_node_hue = 0
    end

    local n_hue_steps = rt.settings.overworld.air_dash_node.n_hue_steps
    self._hue = (scene.air_dash_node_hue % n_hue_steps) / n_hue_steps
    scene.air_dash_node_hue = scene.air_dash_node_hue + 1
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))

    self._particle = ow.AirDashNodeParticle(rt.settings.player.radius * rt.settings.overworld.double_jump_tether.radius_factor)

    stage.air_dash_node_manager:notify_directional_node_added(self)
end

--- @brief
function ow.DirectionalAirDashNode:set_is_tethered(b)
    local before = self._is_tethered
    self._is_tethered = b

    if b == false then
        self._cooldown_elapsed = 0
    end
    
    if before == false and b == true then
        self._particle:set_is_exploded(true)
    elseif before == true and b == false then
        self._particle:set_is_exploded(false)
    end
end

--- @brief
function ow.DirectionalAirDashNode:set_is_current(b)
    self._is_current = b

    if b == true then
        -- skip animation
        self._is_current_motion:set_value(1)
    end
end

--- @brief
function ow.DirectionalAirDashNode:set_tether_path(path)
    self._tether_path = path
end

--- @brief
function ow.DirectionalAirDashNode:set_is_current(b)
    self._is_current = b
end

--- @brief
function ow.DirectionalAirDashNode:set_is_outline_visible(b)
    -- TODO
end

--- @brief
function ow.DirectionalAirDashNode:get_position()
    return self._body:get_position()
end

--- @brief
function ow.DirectionalAirDashNode:get_radius()
    return self._radius
end

--- @brief
function ow.DirectionalAirDashNode:get_body()
    return self._body
end

--- @brief
function ow.DirectionalAirDashNode:get_is_on_cooldown()
    return self._cooldown_elapsed < rt.settings.overworld.air_dash_node.cooldown
    -- sic, shared settings
end

--- @brief
function ow.DirectionalAirDashNode:update(delta)
    if self._is_handler_proxy == true then self._stage.air_dash_node_manager:update(delta) end

    if not self._is_tethered then
        self._cooldown_elapsed = self._cooldown_elapsed + delta
    end

    if self._stage:get_is_body_visible(self._body) then
        self._particle:update(delta)
    end
end

--- @brief
function ow.DirectionalAirDashNode:draw(priority)
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()

    love.graphics.push()
    love.graphics.setColor(self._color:unpack())
    love.graphics.translate(-self._x + offset_x, -self._y + offset_y)

    if self._is_current then
        love.graphics.circle("line", self._x, self._y, self._radius)
    end

    self._particle:draw(self._x, self._y, true, true)

    local magnitude = self._radius
    local dx, dy = self._direction_x, self._direction_y
    local ax, ay = self._x - dx * magnitude, self._y - dy * magnitude
    local bx, by = self._x + dx * magnitude, self._y + dy * magnitude

    love.graphics.line(ax, ay, bx, by)

    love.graphics.pop()

    if self._tether_path ~= nil then
        love.graphics.push()
        love.graphics.translate(offset_x, offset_y)
        love.graphics.line(self._tether_path:get_points())
        love.graphics.pop()
    end
end

--- @brief
function ow.DirectionalAirDashNode:get_color()
    return self._color
end

--- @brief
function ow.DirectionalAirDashNode:collect_point_lights(callback)
    local x, y = self._body:get_position()
    local r, g, b, a = self._color:unpack()
    local radius = self._radius
    callback(x, y, radius, r, g, b, a)
end