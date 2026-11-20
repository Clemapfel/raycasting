--- @class ow.CameraFit
--- @types Rectangle
ow.CameraFit = meta.class("CameraFit")

local schema = meta.Schema({
    scale_speed = mt.Optional(ow.Number),
    move_speed = mt.Optional(ow.Number),
    body = mt.Optional(ow.Object)
})

--- @brief
function ow.CameraFit:instantiate(object, stage, scene)
    object:validate_schema(schema,
        ow.ShapeType.AXIS_ALIGNED_RECTANGLE,
        ow.ShapeType.POLYGON
    )

    local fit
    if object:get_type() == ow.ObjectType.RECTANGLE then
        fit = rt.AABB(object.x, object.y, object.width, object.height)
    else
        fit = object:create_contour():get_aabb()
    end
    self._fit = fit

    self._scale_speed = object:get_number("scale_speed", false)
    self._move_speed = object:get_number("move_speed", false)

    self._scene = scene
    self._stage = stage

    if object:get_object("body") ~= nil then
        self._body = object:get_object("body"):create_physics_body(stage:get_physics_world())
    else
        self._body = object:create_physics_body(stage:get_physics_world())
    end

    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)
    self._body:set_collision_group(rt.settings.player.ghost_collision_group)

    self._is_active = false
    self:update(0, true) -- check if should bind
end

--- @brief
function ow.CameraFit:update(delta, override)
    if override ~= true and not self._stage:get_is_body_visible(self._body) then return end

    local was_active = self._is_active
    local is_active = self._body:test_point(self._scene:get_player():get_position())

    if was_active == false and is_active == true then
        self:_bind()
    elseif was_active == true and is_active == false then
        self:_unbind()
    end
end

--- @brief
function ow.CameraFit:_bind()
    local camera = self._scene:get_camera()
    if self._scale_speed ~= nil then
        camera:request_scale_speed(self, self._scale_speed)
    end

    if self._move_speed ~= nil then
        camera:request_scale_speed(self, self._move_speed)
    end

    camera:request_fit(self, self._fit)
end

--- @brief
function ow.CameraFit:_unbind()
    local camera = self._scene:get_camera()
    if self._scale_speed ~= nil then
        camera:request_scale_speed(self, nil)
    end

    if self._move_speed ~= nil then
        camera:request_scale_speed(self, nil)
    end

    camera:request_fit(self, nil)
end

--- @brief
function ow.CameraFit:reset()
    self:_unbind()
    self._is_active = false
    self:update(0)
end