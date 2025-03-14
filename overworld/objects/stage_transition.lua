--- @class ow.StageTransition
--- @field target String stage id
--- @field entrance Number? entrance index
ow.StageTransition = meta.class("StageTransition", rt.Drawable)

--- @brief
function ow.StageTransition:instantiate(object, stage, scene)
    meta.assert(object, "ObjectWrapper", stage, "Stage", scene, "OverworldScene")

    local centroid_x, centroid_y = object:get_centroid()
    meta.install(self, {
        _body = b2.Body(stage:get_physics_world(), b2.BodyType.STATIC,
            0, 0,
            object:get_physics_shapes()
        ),
        _stage = stage,
        _scene = scene,
        _target = object.properties.target,
        _target_entrance_i = object.properties.entrance or 1,
        _centroid_x = centroid_x,
        _centroid_y = centroid_y
    })
    assert(meta.typeof(self._target) == "String", "In ow.StageTransition.instantiate: tiled object `" .. object.id .. "` of stage `" .. stage:get_id() .. "` does not have `target` property, which should be a stage id")
    self._body:set_is_sensor(true)

    self._scene:_notify_stage_transition(
        self._target,
        stage:get_id(),
        self._target_entrance_i,
        centroid_x, centroid_y
    )

    self._body:signal_connect("collision_start", function(_, other)
        if other:has_tag("player") then
            self._scene:set_stage(self._target)
        end
    end)
end

--- @brief
function ow.StageTransition:draw()
    self._body:draw()
    love.graphics.circle("fill", self._centroid_x, self._centroid_y, 2)
end