--- @class ow.CameraFit
--- @types Rectangle
ow.CameraFit = meta.class("CameraFit")

--- @class ow.CameraFitFocus
ow.CameraFitFocus = meta.class("CameraFitFocus") -- dummy

--- @brief
function ow.CameraFit:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.RECTANGLE, "In ow.CamerBounds: object `", object:get_id(), "` is not a rectangle")

    self._scene = scene
    self._stage = stage

    self._bounds = rt.AABB(object.x, object.y, object.width, object.height)

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)

    local to_fraction = function(x)
        if x < 0 then return 1 / math.abs(x) else return x end
        -- 2 = twice the speed, -2 = half the speed
        -- this way it's easier to input fractions in tiled
    end

    self._before = {
        mode = ow.CameraMode.AUTO,
        scale = 1,
        scale_speed = 1,
        speed = 1
    }

    self._scale_speed = to_fraction(object:get_number("scale_speed", false) or 1)
    self._speed = to_fraction(object:get_number("speed", false) or 1)

    -- focus as point
    self._use_focus = object:get_has_property("focus")
    if self._use_focus then
        local focus = object:get_object("focus")
        rt.assert(focus:get_type() == ow.ObjectType.POINT, "In ow.CameraFit: property `focus` does not point to a `POINT` object")
        self._focus_x = focus.x
        self._focus_y = focus.y

        -- shift body so focus is new center
        local center_x, center_y = object.x + 0.5 * object.width, object.y + 0.5 * object.height
        local current_x, current_y = self._body:get_position()
        local focus_offset_x, focus_offset_y = (self._focus_x - center_x),  (self._focus_y - center_y)
        self._body:set_position(
            current_x + focus_offset_x,
            current_y + focus_offset_y
        )

        self._bounds.x = self._bounds.x + focus_offset_x
        self._bounds.y = self._bounds.y + focus_offset_y
    else
        self._focus_x = nil
        self._focus_y = nil
    end

    self._is_active = false
    self._stage:signal_connect("respawn", function()
        if not self._bounds:contains(self._scene:get_player():get_position()) then
            self:_unbind()
        end
    end)
end

--- @brief
function ow.CameraFit:_bind()
    local camera = self._scene:get_camera()

    local before = self._before
    before.mode = self._scene:get_camera_mode()
    before.scale = camera:get_scale()
    before.speed = camera:get_speed()
    before.scale_speed = camera:get_scale_speed()

    self._scene:set_camera_mode(ow.CameraMode.MANUAL)
    camera:set_scale_speed(self._scale_speed)
    camera:set_speed(self._speed)

    camera:fit_to(self._bounds, self._focus_x, self._focus_y)

    self._stage:signal_connect("respawn", function()
        self._body:signal_emit("collision_end")
        self._is_active = false
        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.CameraFit:_unbind()
    local camera = self._scene:get_camera()
    self._scene:set_camera_mode(self._camera_mode_before)

    local before = self._before
    camera:scale_to(before.scale)
    camera:set_scale_speed(before.scale_speed)
    camera:set_speed(before.speed)
end

--- @brief
function ow.CameraFit:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    local was_active = self._is_active
    local is_active = self._bounds:contains(self._scene:get_player():get_position())

    if was_active == false and is_active == true then
        self:_bind()
    elseif was_active == true and is_active == false then
        self:_unbind()
    end

    self._is_active = is_active
end
