require "common.blend_mode"
require "overworld.object_wrapper"
require "overworld.ray_material"

--- @class ow.Hitbox
--- @field is_absorptive Boolean
--- @field is_reflective Boolean
--- @field is_transmissive Boolean
--- @field is_filtrative Boolean
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
    self._body:set_user_data(self)
    self._color = rt.Palette.GRAY_4

    local group = 0x0
    local once = false
    if object:get_boolean("is_reflective") then
        group = bit.bor(group, ow.RayMaterial.REFLECTIVE)
        self._body:add_tag("draw")
        self._color = rt.Palette.WHITE
        once = true
    end

    if object:get_boolean("is_transmissive") then
        group = bit.bor(group, ow.RayMaterial.TRANSMISSIVE)
        self._body:add_tag("draw")
        self._color = rt.Palette.BLUE_2
        once = true
    end

    if object:get_boolean("is_filtrative") then
        group = bit.bor(group, ow.RayMaterial.FILTRATIVE)
        self._body:add_tag("draw")
        self._color = rt.Palette.BLACK
        once = true
    end

    if object:get_boolean("is_absorptive") or once == false then
        group = bit.bor(group, ow.RayMaterial.ABSORPTIVE)
        once = true
    end

    self._body:set_collision_group(group)
    self._shapes = self._body:get_shapes()
end

--- @brief
function ow.Hitbox:draw()
    if self._body:has_tag("draw") then
        love.graphics.setColor(rt.color_unpack(self._color))
        love.graphics.translate(self._body:get_position())
        for shape in values(self._shapes) do
            shape:draw()
        end
    end
end
