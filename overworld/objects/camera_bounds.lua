--- @class ow.CameraBounds
--- @types Rectangle
ow.CameraBounds = meta.class("CameraBounds")

local schema = meta.Schema({
    scale = mt.Optional(ow.Number),
    body = mt.Optional(ow.Object),
    should_apply_bounds = mt.Optional(ow.Boolean),
})

--- @brief
function ow.CameraBounds:instantiate(object, stage, scene)
    object:validate_schema(schema,
        ow.ShapeType.AXIS_ALIGNED_RECTANGLE,
        ow.ShapeType.POLYGON
    )

    local bounds
    if object:get_type() == ow.ObjectType.RECTANGLE then
        bounds = rt.AABB(object.x, object.y, object.width, object.height)
    else
        bounds = object:create_contour():get_aabb()
    end

    self._scene = scene
    self._stage = stage

    self._scale = object:get_number("scale", false)
    self._should_apply_bounds = object:get_boolean("should_apply_bounds", false)

    self._bounds = bounds

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
function ow.CameraBounds:update(delta, override)
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
function ow.CameraBounds:_bind()
    local camera = self._scene:get_camera()
    if self._should_apply_bounds ~= false then
        camera:request_bounds(self, self._bounds)
    end

    if self._scale ~= nil then
        camera:request_scale(self, self._scale)
    end
end

--- @brief
function ow.CameraBounds:_unbind()
    local camera = self._scene:get_camera()
    if self._should_apply_bounds ~= nil then
        camera:request_bounds(self, nil)
    end

    if self._scale ~= nil then
        camera:request_scale(self, nil)
    end
end

--- @brief
function ow.CameraBounds:reset()
    self:_unbind()

    -- force check if should bind agai
    self._is_active = false
    self:update(0)
end