--- @class ow.FlowOverride
--- @types Rectangle
ow.FlowOverride = meta.class("FlowOverride")

local schema = meta.Schema({
    value = mt.Optional(ow.Number)
})

--- @brief
function ow.FlowOverride:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    object:validate_schema(schema, ow.ShapeType.NOT_A_POINT)
    self._target_value = object:get_has_property("value") and object:get_number("value") or 1
    self._flow_motion = rt.SmoothedMotion1D(0)

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)
    self._body:set_collides_with(rt.settings.player.player_collision_group)
end

--- @brief
function ow.FlowOverride:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    local player = self._scene:get_player()
    if self._body:test_point(player:get_position()) then
        player:request_flow_override(self, self._target_value)
    else
        player:request_flow_override(self, nil)
    end
end

--- @brief
function ow.FlowOverride:reset()
    self._scene:get_player():request_flow_override(self, nil)
end
