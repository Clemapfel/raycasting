--- @class ow.StageTransition
--- @field target String stage id
--- @field entrance Number? entrance index of self
--- @field target_entrance Number? entrance index of target
ow.StageTransition = meta.class("StageTransition", rt.Drawable)

--- @brief
function ow.StageTransition:instantiate(object, stage, scene)
    meta.assert(object, "ObjectWrapper", stage, "Stage", scene, "OverworldScene")

    local centroid_x, centroid_y = object:get_centroid()
    local target_stage = object:get_string("target", true)
    local self_entrance_i = object:get_number("entrance", false)
    local target_entrance_i = object:get_number("target_entrance", false)

    meta.install(self, {
        _body = object:create_physics_body(stage:get_physics_world()),
        _stage = stage,
        _scene = scene,
        _target_stage = object.properties.target,
        _target_entrance_i = target_entrance_i or 1,
        _self_entrance_i = self_entrance_i or 1,
        _centroid_x = centroid_x,
        _centroid_y = centroid_y,
        _is_disabled = false
    })
    self._body:set_is_sensor(true)

    self._scene:_notify_stage_transition_added( -- set self as spawn point when entering
        self,
        self._stage:get_id(),   -- from id
        self._self_entrance_i,  -- from entrance
        self._target_stage,     -- to id
        self._target_entrance_i -- to entrance
    )

    self._body:signal_connect("collision_start", function(_, other)
        if self._is_disabled ~= true and (other:has_tag("player") or other:has_tag("agent"))  then
            self._scene:set_stage(self._target_stage, self._target_entrance_i)
        end
    end)

    self._body:signal_connect("collision_end", function(_, other)
        if other:has_tag("player") then
            self._is_disabled = false
        end
    end)
end

--- @brief
function ow.StageTransition:draw()
    self._body:draw()
    love.graphics.circle("fill", self._centroid_x, self._centroid_y, 2)
end

--- @brief
function ow.StageTransition:set_is_disabled(b)
    self._is_disabled = b
end

--- @brief
function ow.StageTransition:get_spawn_position()
    return self._centroid_x, self._centroid_y
end