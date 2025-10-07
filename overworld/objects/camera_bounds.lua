--- @class ow.CameraBounds
--- @types Rectangle
ow.CameraBounds = meta.class("CameraBounds")

--- @brief
function ow.CameraBounds:instantiate(object, stage, scene)
    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)
    self._body:signal_connect("collision_start", function()
        scene:set_camera_bounds(rt.AABB(object.x, object.y, object.width, object.height))
    end)
end