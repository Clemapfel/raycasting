--- @class ow.ControlIndicatorTrigger
--- @types Polygon, Rectangle, Ellipse
--- @field type String!
--- @field should_emit_particles Boolean?
ow.ControlIndicatorTrigger = meta.class("ControlIndicatorTrigger")

local _types
do
    _types = {}
    for type in values(meta.instances(ow.ControlIndicatorType)) do
        table.insert("`", tostring(type), "`")
        table.insert(", ")
    end
    _types[#_types] = nil -- last comma
    _types = table.concat(_types, "")
end

--- qbrief
function ow.ControlIndicatorTrigger:instantiate(object, stage, scene)
    assert(object:get_type() ~= ow.ObjectType.POINT, "In ow.ControlIndicatorTrigger: object `", object:get_id(), "` is a point")

    self._scene = scene
    self._stage = stage
    self._type = string.upper(object:get_string("type", true))
    self._should_emit_particles = object:get_boolean("should_emit_particles", false)
    if self._should_emit_particles == nil then self._should_emit_particles = false end

    assert(meta.is_enum_value(self._type, ow.ControlIndicatorType), "In ow.ControlIndicatorTrigger: property `type` of object `" .. object:get_id() .. "` unrecognized. Should be one of " .. _types)
    
    local body = object:create_physics_body(stage:get_physics_world(), b2.BodyType.STATIC)
    self._body = body

    body:set_is_sensor(true)
    body:set_collides_with(rt.settings.player.bounce_collision_group)
    body:set_collision_group(rt.settings.player.bounce_collision_group)
    
    body:signal_connect("collision_start", function(_, other_body)
        if other_body:has_tag("player") then
            self._scene:set_control_indicator_type(self._type, self._should_emit_particles)
        end
    end)

    body:signal_connect("collision_end", function()
        self._scene:set_control_indicator_type(nil)
    end)

    self._stage:signal_connect("respawn", function()
        self._scene:set_control_indicator_type(nil)
    end)
end
