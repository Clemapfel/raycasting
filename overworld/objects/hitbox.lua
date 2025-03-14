require "common.blend_mode"
require "overworld.object_wrapper"

--- @class ow.Hitbox
--- @field body_type b2.BodyType
ow.Hitbox = meta.class("OverworldHitbox", rt.Drawable)

--- @brief
function ow.Hitbox:instantiate(object, stage, scene)
    meta.assert(object, "ObjectWrapper", stage, "Stage", scene, "OverworldScene")

    self._world = stage:get_physics_world()
    local type = b2.BodyType.KINEMATIC
    if object.properties.body_type ~= nil then
        type = object.properties.body_type
        assert(meta.is_enum_value(type, b2.BodyType), "In ow.Hitbox.instantiate: `type` property of object `" .. object.id .. "` is `" .. type .. "` which is not a b2.BodyType")
    end

    self._body = b2.Body(self._world, type, 0, 0, object:get_physics_shapes())
    self._body:add_tag("activatable")
    self._body:set_user_data(self)
end

--- @brief
function ow.Hitbox:draw()
    if self._body:has_tag("draw") then
        self._body:draw()
    end
end
