--- @class ow.CameraFit
--- @types Rectangle
ow.CameraFit = meta.class("CameraFit")

--- @class ow.CameraFitBody
ow.CameraFitBody = meta.class("CameraFitBody") -- dummy

--- @brief
function ow.CameraFit:instantiate(object, stage, scene)
    if object:get_type() == ow.ObjectType.POLYGON then
        self._bounds = rt.contour.get_aabb(object:create_contour())
    elseif object:get_type() == ow.ObjectType.RECTANGLE then
        self._bounds = rt.AABB(object.x, object.y, object.width, object.height)
    else
        rt.assert(false, "In ow.CamerBounds: object `", object:get_id(), "` is not a rectangle")
    end

    self._scene = scene
    self._stage = stage

    if object:get_object("body") == nil then
        self._body = object:create_physics_body(stage:get_physics_world())
    else
        self._body = object:get_object("body"):create_physics_body(stage:get_physics_world())
    end

    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)
    self._body:set_collision_group(rt.settings.player.ghost_collision_group)

    local to_fraction = function(x)
        if x < 0 then return 1 / math.abs(x) else return x end
        -- 2 = twice the speed, -2 = half the speed
        -- this way it's easier to input fractions in tiled
    end

    self._before = {
        scale = 1,
        scale_speed = 1,
        speed = 1
    }

    self._scale_speed = to_fraction(object:get_number("scale_speed", false) or 1)
    self._speed = to_fraction(object:get_number("speed", false) or 1)

    self._is_active = false
    self._stage:signal_connect("respawn", function()
        if not self._bounds:contains(self._scene:get_player():get_position()) then
            self:_unbind()
        else
            self:_bind()
        end
    end)
end

--- @brief
function ow.CameraFit:_bind()
    local camera = self._scene:get_camera()

    self._scene:push_camera_mode(ow.CameraMode.CUTSCENE)
    camera:set_apply_bounds(false)
    camera:set_scale_speed(self._scale_speed)
    camera:set_speed(self._speed)
    camera:move_to(self._bounds.x + 0.5 * self._bounds.width, self._bounds.y + 0.5 * self._bounds.height)
    camera:fit_to(self._bounds)

    self._stage:signal_connect("respawn", function()
        self:_unbind()
        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.CameraFit:_unbind()
    local camera = self._scene:get_camera()
    self._scene:pop_camera_mode(ow.CameraMode.CUTSCENE)
end

--- @brief
function ow.CameraFit:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    local was_active = self._is_active
    local is_active = self._body:test_point(self._scene:get_player():get_position())

    if was_active == false and is_active == true then
        self:_bind()
    elseif was_active == true and is_active == false then
        self:_unbind()
    end

    self._is_active = is_active
end
