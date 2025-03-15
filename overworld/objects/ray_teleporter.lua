--- @class ow.RayTeleporter
ow.RayTeleporter = meta.class("RayReleporter", rt.Drawable)
meta.add_signals(ow.RayTeleporter, "ray_collision_start", "ray_collision_end")

ow.RayTeleporterActiveSide = meta.enum("RayTeleporterActiveSide", {
    TOP = "top",
    RIGHT = "right",
    BOTTOM = "bottom",
    LEFT = "left"
})


--- @brief
function ow.RayTeleporter:instantiate(object, stage, scene)
    assert(object.type == ow.ObjectType.RECTANGLE, "In ow.RayTeleporter: expected `RECTANGLE`, got `" .. object.type .. "`")

    local other = object:get_object("target", true)
    assert(object.type == ow.ObjectType.RECTANGLE, "In ow.RayTeleporter: expected `RECTANGLE` for `target` property, got `" .. other.type .. "`")

    local type = b2.BodyType.STATIC
    if object:get_string("type") ~= nil then
        type = object:get_string("type")
    end

    self._world = stage:get_physics_world()
    self._body = b2.Body(self._world, type, 0, 0, object:get_physics_shapes())
    self._body:set_collision_group(ow.RayMaterial.TELEPORTER)
    self._body:set_user_data(self)

    self._object = object
    self._target = other
end

function ow.RayTeleporter:teleport_ray(contact_x, contact_y, dx, dy, normal_x, normal_y)
    local self_x, self_y = self._object.x, self._object.y
    local other_x, other_y = self._target.x, self._target.y
    local self_angle, other_angle = self._object.rotation, self._target.rotation

    -- Rotate contact point by the negative angle of the first rectangle around its top-left corner
    local cos_self = math.cos(-self_angle)
    local sin_self = math.sin(-self_angle)
    local rotated_x = (contact_x - self_x) * cos_self - (contact_y - self_y) * sin_self
    local rotated_y = (contact_x - self_x) * sin_self + (contact_y - self_y) * cos_self

    -- Rotate direction vector by the negative angle of the first rectangle
    local rotated_dx = dx * cos_self - dy * sin_self
    local rotated_dy = dx * sin_self + dy * cos_self

    -- Rotate contact point by the angle of the second rectangle around its top-left corner
    local cos_other = math.cos(other_angle)
    local sin_other = math.sin(other_angle)
    local final_x = rotated_x * cos_other - rotated_y * sin_other
    local final_y = rotated_x * sin_other + rotated_y * cos_other

    -- Rotate direction vector by the angle of the second rectangle
    local final_dx = rotated_dx * cos_other + rotated_dy * sin_other
    local final_dy = rotated_dx * sin_other - rotated_dy * cos_other

    -- Translate to the position of the second rectangle
    local new_contact_x = final_x + other_x
    local new_contact_y = final_y + other_y

    return new_contact_x, new_contact_y, final_dx, final_dy
end
--- @brief
function ow.RayTeleporter:draw()
    self._body:draw()
end