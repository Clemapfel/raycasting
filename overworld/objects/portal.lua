require "overworld.tether"
require "overworld.objects.portal_particles"
require "common.spline"
require "common.path"

rt.settings.overworld.portal = {
    default_winding = true,
    transition_min_velocity_non_bubble = 600,
    transition_min_velocity_bubble = 300,
    sensor_width = 2 * rt.settings.player.radius * rt.settings.player.bubble_radius_factor
}

--- @class ow.Portal
--- @types Point
--- @field target ow.Portal? other portal to teleport to, or nil for one-way
--- @field other ow.PortalNode! second node of line, winding order matters
--- @field left_or_right Boolean? override winding order
ow.Portal = meta.class("Portal", ow.MovableObject)

--- @class ow.PortalNode
ow.PortalNode = meta.class("PortalNode") -- dummy

local schema = {
    left_or_right = ow.Boolean,
    other = ow.Object,
    object = ow.Object
}

local _STATE_DEFAULT = 0
local _STATE_TRANSITIONING = 1
local _STATE_EXITING = 2

local _LEFT = 1
local _RIGHT = -1

function ow.Portal:instantiate(object, stage, scene)
    object:validate_schema(schema, ow.ShapeType.POINT)

    self._scene = scene
    self._stage = stage
    self._object = object

    self._stage.portal_active_portal = nil -- stage-wide flag
    self._state = _STATE_DEFAULT

    self._stage:signal_connect("initialized", function()
        local other = object:get_object("other", true)
        if other:get_type() ~= ow.ObjectType.POINT then
            rt.error("In ow.Portal: object `", other:get_id(), "` is not a point")
        end

        self._entry_t = 0.5 -- contraction point of portal

        self._ax, self._ay = object.x, object.y
        self._bx, self._by = other.x, other.y

        -- translate to origin
        self._mid_x, self._mid_y = math.mix2(self._ax, self._ay, self._bx, self._by, 0.5)
        self._ax = self._ax - self._mid_x
        self._ay = self._ay - self._mid_y
        self._bx = self._bx - self._mid_x
        self._by = self._by - self._mid_y

        self._winding = object:get_boolean("direction", false)
        if self._winding == nil then self._winding = rt.settings.overworld.portal.default_winding end

        self._dx, self._dy = math.normalize(self._ax - self._bx, self._ay - self._by)

        if self._winding == true then
            self._nx, self._ny = math.turn_left(self._dx, self._dy)
        else
            self._nx, self._ny = math.turn_right(self._dx, self._dy)
        end

        -- create body, used for segment light query and movable object velocity
        self._body = b2.Body(
            self._stage:get_physics_world(),
            object:get_physics_body_type(),
            self._mid_x, self._mid_y,
            b2.Segment(self._ax, self._ay, self._bx, self._by)
        )

        self._body:add_tag(b2.Tag.SEGMENT_LIGHT_SOURCE)
        self._body:set_user_data(self)

        -- body used to stencil player after passing portal
        local stencil_r = 4 * rt.settings.player.radius * rt.settings.player.bubble_radius_factor
        self._stencil_body = b2.Body(
            self._stage:get_physics_world(),
            self._object:get_physics_body_type(),
            b2.huge, b2.huge,
            b2.Rectangle(
                -stencil_r, -stencil_r,
                2 * stencil_r, 2 * stencil_r
            )
        )
        self._stencil_body_radius = stencil_r

        self._stencil_body:add_tag(
            b2.Tag.STENCIL,
            b2.Tag.CORE_STENCIL,
            b2.Tag.BODY_STENCIL
        )
        
        for body in range(self._body, self._stencil_body) do
            body:set_collides_with(0x0)
            body:set_collision_group(0x0)
        end

        -- only is active when player is ghost, needs non 0x0 group to be recognized as stencil
        self._stencil_body:set_collision_group(rt.settings.overworld.hitbox.collision_group)
        self._stencil_body:set_rotation(math.angle(self._bx - self._ax, self._by - self._ay))
        self._stencil_body:set_is_enabled(false)

        -- graphics
        self._particles = ow.PortalParticles(
            self._ax, self._ay, self._bx, self._by,
            self._winding == _LEFT
        )

        return meta.DISCONNECT_SIGNAL
    end)

    self._stage:signal_connect("post_initialized", function()
        -- color
        if stage.portal_hue_index == nil then stage.portal_hue_index = 0 end
        local hue = stage.portal_hue_index % 12

        if self._color == nil then
            self._particles:set_hue(hue)
            self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, hue, 1))
            stage.portal_hue_index = stage.portal_hue_index + 1
        end

        -- pair with other portal
        local target_object = object:get_object("target", false)
        if target_object ~= nil then
            self._target = self._stage:object_wrapper_to_instance(target_object)
            rt.assert(meta.isa(self._target, ow.Portal), "In ow.Portal: `target` object `", target_object:get_id(), "`: expected `ow.Portal`, got `", meta.typeof(self._target) , "`")

            -- synch color between portals
            if self._target._color == nil then
                self._target._particles:set_hue(hue)
                self._target._color = self._color
            end

            self._particles:set_is_enabled(true)
        else
            self._particles:set_is_enabled(false)
        end

        return meta.DISCONNECT_SIGNAL
    end)
end

local function _t_on_line(x1, y1, x2, y2, px, py)
    local sdx = x2 - x1
    local sdy = y2 - y1
    local pdx = px - x1
    local pdy = py - y1

    return math.dot(pdx, pdy, sdx, sdy) /
        math.dot(sdx, sdy, sdx, sdy)
end

local function _side_of(ax, ay, bx, by, px, py)
    return math.cross(
        px - ax, py - ay,
        bx - ax, by - ay
    ) > 0
end

local function _clamp_point_to_line(ax, ay, bx, by, normal_x, normal_y, x, y)
    local line_dx = bx - ax
    local line_dy = by - ay

    line_dx, line_dy = math.normalize(line_dx, line_dy)
    local line_length = math.magnitude(bx - ax, by - ay)

    normal_x, normal_y = math.normalize(normal_x, normal_y)
    local to_point_x = x - ax
    local to_point_y = y - ay

    local distance = math.dot(to_point_x, to_point_y, normal_x, normal_y)

    if distance < 0 then
        local projection = math.dot(to_point_x, to_point_y, line_dx, line_dy)
        projection = math.clamp(projection, 0, line_length)
        x = ax + line_dx * projection
        y = ay + line_dy * projection
    end

    return x, y
end

--- @brief
function ow.Portal:_update_stencil_body(enabled, px, py)

end

--- @brief
function ow.Portal:update(delta)
    local player = self._scene:get_player()
    local settings = rt.settings.overworld.portal

    local update_stencil_body = function(self, enabled, px, py)
        local self_x, self_y = self:get_position()
        local ax, ay, bx, by = math.add4(
            self._ax, self._ay, self._bx, self._by,
            self_x, self_y, self_x, self_y
        )
        local nx, ny = -self._nx, -self._ny
        local r = self._stencil_body_radius

        self._stencil_body:set_is_enabled(enabled)
        self._stencil_body:set_position(_clamp_point_to_line(
            ax - nx * r, ay - ny * r, bx - nx * r, by - ny * r,
            -nx, -ny,
            px, py
        ))
    end

    local is_visible = self._stage:get_is_body_visible(self._body)

    if is_visible then
        self._particles:update(delta)
    end

    -- check if teleport should be started
    if self._stage.portal_active_portal == nil
        and self._target ~= nil
        and self._state == _STATE_DEFAULT
        and is_visible
    then
        local px, py = player:get_position()
        local pr = player:get_radius()

        local self_x, self_y = self:get_position()
        local ax, ay = math.add2(self._ax, self._ay, self_x, self_y)
        local bx, by = math.add2(self._bx, self._by, self_x, self_y)

        -- get which side of the portal the player is on
        if _side_of(ax, ay, bx, by, px, py) == self._winding then
            local padding = pr
            local lax, lay, lbx, lby = ax - self._dx * padding,
                ay - self._dy * padding,
                bx + self._dx * padding,
                by + self._dy * padding

            local entry_t = math.clamp(_t_on_line(
                lax, lay, lbx, lby, px, py
            ), 0, 1)

            -- get distance from player to line segment
            if math.distance(px, py, math.mix2(
                lax, lay, lbx, lby, entry_t
            )) <= pr then
                -- initiate teleport
                self._stage.portal_active_portal = self

                self._start_x, self._start_y = px, py
                self._start_t = entry_t
                self._start_time = love.timer.getTime()

                self._transition_velocity_magnitude = math.max(
                    ternary(player:get_is_bubble(),
                        settings.transition_min_velocity_bubble,
                        settings.transition_min_velocity_non_bubble
                    ),
                    math.magnitude(player:get_velocity())
                )

                self._scene:push_camera_mode(ow.CameraMode.CUTSCENE)
                player:request_is_disabled(self, true)
                player:request_is_ghost(self, true)
                -- trail disabled once player properly crosses portal

                -- angle player towards portal
                self._transition_velocity_x, self._transition_velocity_y =
                self._nx * self._transition_velocity_magnitude,
                self._ny * self._transition_velocity_magnitude
                player:set_velocity(
                    self._transition_velocity_x,
                    self._transition_velocity_y
                )

                self._state = _STATE_TRANSITIONING

                update_stencil_body(self, true, self:get_position())
                update_stencil_body(self._target, true, self._target:get_position())

                self._particles:contract(entry_t)
                self._entry_t = entry_t
            end
        end
    end

    -- teleport active
    if self._stage.portal_active_portal == self and self._target ~= nil then
        local target = self._target
        local penetration_r = settings.sensor_width

        -- moving from one portal to the other
        if self._state == _STATE_TRANSITIONING then
            local elapsed = love.timer.getTime() - self._start_time
            local target_x, target_y = target:get_position()
            local self_x, self_y = self:get_position()

            -- move camera
            local path = rt.Path(rt.Spline(
                self._start_x, self._start_y,
                --self_x, self_y,
                --self_x + self._nx * penetration_r,
                --self_y + self._ny * penetration_r,
                target_x, target_y
            ):discretize())

            local px, py = player:get_position()
            local ax, ay = math.add2(self._ax, self._ay, self_x, self_y)
            local bx, by = math.add2(self._bx, self._by, self_x, self_y)

            if _side_of(ax, ay, bx, by, px, py) ~= self._winding then
                player:request_is_trail_enabled(self, false)
            end

            local length = path:get_length()
            local duration = length / self._transition_velocity_magnitude
            local t = math.min(elapsed / duration, 1)
            t = rt.InterpolationFunctions.SINUSOID_EASE_IN_OUT(t)
            self._scene:get_camera():move_to(path:at(t))

            player:set_velocity(
                self._transition_velocity_x,
                self._transition_velocity_y
            )

            if t >= 1 then
                player:teleport_to(target:get_position())
                player:request_is_trail_enabled(self, false) -- safety for degenerate geometry

                -- reset stencils
                update_stencil_body(self, false, self:get_position())
                update_stencil_body(self._target, true, self._target:get_position())

                self._state = _STATE_EXITING
                self._start_time = love.timer.getTime()

                target._particles:contract(self._entry_t) -- exit always from center
            else
                -- move stencil along with player, automatically clamped behind line
                update_stencil_body(self, true, px, py)
                update_stencil_body(self._target, true, self._target:get_position())
            end
        end

        -- exiting target portal
        if self._state == _STATE_EXITING and self._target ~= nil then
            local target_x, target_y = target:get_position()
            local dx, dy = math.normalize(-target._nx, -target._ny)

            local target_vx, target_vy = target._body:get_velocity()
            player:set_velocity(
                dx * self._transition_velocity_magnitude + target_vx,
                dy * self._transition_velocity_magnitude + target_vy
            )

            local px, py = player:get_position()
            self._scene:get_camera():move_to(px, py)

            local ax, ay = math.add2(target._ax, target._ay, target_x, target_y)
            local bx, by = math.add2(target._bx, target._by, target_x, target_y)
            if _side_of(ax, ay, bx, by, px, py) ~= target._winding then
                player:request_is_trail_enabled(self, nil)
            end

            if math.distance(px, py, target_x, target_y) > penetration_r + player:get_radius() then
                -- player is far enough, disengage transitioning state
                self._scene:pop_camera_mode(ow.CameraMode.CUTSCENE)

                player:request_is_ghost(self, nil)
                player:request_is_disabled(self, nil)
                player:request_is_trail_enabled(self, nil) -- safety

                update_stencil_body(self, false, self:get_position())
                update_stencil_body(self._target, false, self._target:get_position())

                self._state = _STATE_DEFAULT
                self._stage.portal_active_portal = nil
            else
                update_stencil_body(self, false, self:get_position())
                update_stencil_body(self._target, true, self._target:get_position())
            end
        end
    end
end

--- @brief
function ow.Portal:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self:get_position()
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)
    self._particles:draw()
    love.graphics.pop()
end

--- @brief
function ow.Portal:collect_segment_lights(callback)
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self:get_position()
    callback(
        self._ax + offset_x, self._ay + offset_y,
        self._bx + offset_x, self._by + offset_y,
        self._color:unpack()
    )
end

--- @brief
function ow.Portal:set_position(x, y)
    self._body:set_position(x, y)
end

--- @brief
function ow.Portal:get_position()
    return self._body:get_position()
end

--- @brief
function ow.Portal:set_velocity(vx, vy)
    self._body:set_velocity(vx, vy)
end

--- @brief
function ow.Portal:get_velocity()
    return self._body:get_velocity()
end

--- @brief
function ow.Portal:reset()
    local target = self._target
    local player = self._scene:get_player()

    if player ~= nil then
        player:request_is_disabled(self, nil)
        player:request_is_ghost(self, nil)
        player:request_is_trail_enabled(self, nil)
    end

    self._stencil_body:set_is_enabled(false)
    if target ~= nil then
        target._stencil_body:set_is_enabled(false)
    end

    self._start_x, self._start_y = nil, nil
    self._start_t = nil
    self._start_time = nil
    self._transition_velocity_magnitude = nil
    self._transition_velocity_x, self._transition_velocity_y = nil, nil
    self._entry_t = 0.5

    self._state = _STATE_DEFAULT
    if target ~= nil then
        target._state = _STATE_DEFAULT
    end

    if self._stage.portal_active_portal == self then
        self._stage.portal_active_portal = nil
    end

    self._scene:pop_camera_mode(ow.CameraMode.CUTSCENE)
end