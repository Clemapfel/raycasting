--- @class ow.StageTransition
ow.StageTransition = meta.class("StageTransition")

--- @brief
function ow.StageTransition:instantiate(object, stage, scene)
    meta.assert(object, "ObjectWrapper", stage, "Stage", scene, "OverworldScene")

    meta.install(self, {
        _body = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC,
            0, 0,
            object:get_physics_shapes()
        ),
        _stage = stage,
        _scene = scene,
        _target = object.properties.target
    })
    assert(meta.typeof(self._target) == "String", "In ow.StageTransition.instantiate: tiled object `" .. object.id .. "` of stage `" .. stage:get_id() .. "` does not have `target` property, which should be a stage id")

    self._scene:preload_stage(self._target)
    self._body:signal_connect("collision_start", function(_, other)
        if other:has_tag(b2.BodyTag.IS_PLAYER) then
            self._scene:set_stage(self._target)
        end
    end)
    self._body:set_is_sensor(true)
    self._body:set_is_solid(false)
end