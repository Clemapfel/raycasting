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
    local self_x, self_y, self_w, self_h = self._object.x, self._object.y, self._object.width, self._object.height
    local other_x, other_y, other_w, other_h = self._target.x, self._target.y, self._target.width, self._target.height
    local self_angle, other_angle = self._object.rotation, self._target.rotation

    -- Calculate the center of the self rectangle
    local self_center_x = self_x + self_w / 2
    local self_center_y = self_y + self_h / 2

    -- Calculate the center of the other rectangle
    local other_center_x = other_x + other_w / 2
    local other_center_y = other_y + other_h / 2

    -- Translate contact point to local coordinates of self, using the center as origin
    local local_contact_x = (contact_x - self_center_x) * math.cos(-self_angle) + (contact_y - self_center_y) * math.sin(-self_angle)
    local local_contact_y = -(contact_x - self_center_x) * math.sin(-self_angle) + (contact_y - self_center_y) * math.cos(-self_angle)

    -- Calculate relative position within self
    local relative_x = local_contact_x / self_w
    local relative_y = local_contact_y / self_h

    -- Determine the opposite side for translation
    local opposite_relative_x = 1 - relative_x
    local opposite_relative_y = 1 - relative_y

    -- Translate relative position to local coordinates of other
    local local_translated_x = opposite_relative_x * other_w
    local local_translated_y = opposite_relative_y * other_h

    -- Transform local coordinates to world coordinates of other, using the center as origin
    local translated_x = other_center_x + local_translated_x * math.cos(other_angle) + local_translated_y * math.sin(other_angle)
    local translated_y = other_center_y - local_translated_x * math.sin(other_angle) + local_translated_y * math.cos(other_angle)

    -- Calculate the angle difference
    local angle_difference = other_angle - self_angle

    -- Rotate the direction vector (dx, dy) by the angle difference
    local rotated_dx = dx * math.cos(angle_difference) + dy * math.sin(angle_difference)
    local rotated_dy = -dx * math.sin(angle_difference) + dy * math.cos(angle_difference)

    return translated_x, translated_y, rotated_dx, rotated_dy
end

--- @brief
function ow.RayTeleporter:draw()
    self._body:draw()
end