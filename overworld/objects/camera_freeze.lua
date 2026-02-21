--- @class ow.CameraFreeze
--- @types Rectangle
ow.CameraFreeze = meta.class("CameraFreeze")

--- @brief
function ow.CameraFreeze:instantiate(object, stage, scene)
    rt.assert(object:get_type() == ow.ObjectType.RECTANGLE, "In ow.CamerBounds: object `", object:get_id(), "` is not a rectangle")

    self._scene = scene
    self._stage = stage

    if object:get_object("body") then
        self._body = object:get_object("body"):create_physics_body(stage:get_physics_world())
    else
        self._body = object:create_physics_body(stage:get_physics_world())
    end

    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)

    self._scale = 1
    self._position_x, self._position_y = 0, 0

    self._body:signal_connect("collision_start", function()
        self:_bind()
    end)

    self._body:signal_connect("collision_end", function()
        self:_unbind()
    end)
end

--- @brief
function ow.CameraFreeze:_bind()
    local camera = self._scene:get_camera()
    self._scale = camera:get_scale()
    self._position_x, self._position_y = camera:get_position()
    self._scene:push_camera_mode(ow.CameraMode.FREEZE)

    self._stage:signal_connect("respawn", function()
        self:_unbind()
        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.CameraFreeze:_unbind()
    self._scene:pop_camera_mode(ow.CameraMode.FREEZE)
end