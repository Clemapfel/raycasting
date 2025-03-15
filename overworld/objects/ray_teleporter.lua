--- @class ow.RayTeleporter
ow.RayTeleporter = meta.class("RayReleporter")
meta.add_signals(ow.RayTeleporter, "ray_collision_start", "ray_collision_end")

ow.RayTeleporterActiveSide = meta.enum("RayTeleporterActiveSide", {
    TOP = "top",
    RIGHT = "right",
    BOTTOM = "bottom",
    LEFT = "left"
})

local _object_to_instance

--- @brief
function ow.RayTeleporter:instantiate(object, stage, scene)
    _object_to_instance[object] = self
    assert(object.type == ow.ObjectType.RECTANGLE, "In ow.RayTeleporter: expected `RECTANGLE`, got `" .. object.type .. "`")

    local side = object:get_string("side", true)
    local other = object:get_object("target", true)
    local type = b2.BodyType.STATIC
    if object:get_string("type") ~= nil then
        type = object:get_string("type")
    end

    self._world = stage:get_physics_world()
    self._body = b2.Body(self._world, type, 0, 0, object:get_physics_shapes())
    self._body:set_collision_group(ow.RayMaterial.TELEPORTER)
    self._body:set_user_data(self)


end