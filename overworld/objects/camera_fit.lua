--- @class ow.CameraFit
--- @types Rectangle
ow.CameraFit = meta.class("CameraFit")

--- @brief
function ow.CameraFit:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.RECTANGLE, "In ow.CamerBounds: object `", object:get_id(), "` is not a rectangle")

    self._scene = scene
    self._stage = stage
    self._bounds = rt.AABB(object.x, object.y, object.width, object.height)

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)

    self._scale_before = 1
    self._camera_mode_before = nil

    self._body:signal_connect("collision_start", function()
        local camera = self._scene:get_camera()

        self._scale_before = camera:get_scale()
        camera:fit_to(self._bounds)

        self._camera_mode_before = self._scene:get_camera_mode()
        self._scale_before = camera:get_scale()
        self._scene:set_camera_mode(ow.CameraMode.MANUAL)

        self._stage:signal_connect("respawn", function()
            self._body:signal_emit("collision_end")
            return meta.DISCONNECT_SIGNAL
        end)
    end)

    self._body:signal_connect("collision_end", function()
        self._scene:set_camera_mode(self._camera_mode_before)
        self._scene:get_camera():set_scale(self._scale_before)
    end)
end
