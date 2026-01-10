--- @class ow.CameraBounds
--- @types Rectangle
ow.CameraBounds = meta.class("CameraBounds")

--- @brief
function ow.CameraBounds:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.RECTANGLE, "In ow.CamerBounds: object `", object:get_id(), "` is not a rectangle")

    self._scene = scene
    self._stage = stage

    self._scale = object:get_number("scale", false) -- can be nil

    self._should_apply_scale = object:get_boolean("should_apply_scale", false)
    if self._should_apply_scale == nil then self._should_apply_scale = self._scale ~= nil end

    self._bounds = rt.AABB(object.x, object.y, object.width, object.height)
    self._should_apply_bounds = object:get_boolean("should_apply_bounds", false)
    if self._should_apply_bounds == nil then self._should_apply_bounds = true end

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)

    self._scale_before = nil
    self._bounds_before = nil

    self._body:signal_connect("collision_start", function()
        local camera = self._scene:get_camera()

        if self._should_apply_bounds then
            self._bounds_before = camera:get_bounds()
            camera:set_bounds(self._bounds)
        end

        if self._should_apply_scale then
            self._scale_before = camera:get_scale()
            camera:scale_to(self._scale)
        end

        self._stage:signal_connect("respawn", function()
            self._body:signal_emit("collision_end")
            return meta.DISCONNECT_SIGNAL
        end)
    end)

    self._body:signal_connect("collision_end", function()
        local camera = self._scene:get_camera()

        if self._should_apply_bounds then
            camera:set_bounds(self._bounds_before)
        end

        if self._should_apply_scale then
            camera:scale_to(self._scale_before)
        end
    end)
end
