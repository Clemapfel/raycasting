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
    self._body = object:create_physics_body(self._world)

    if object:get_string("type") == b2.BodyType.DYNAMIC then
        self._body._native:setLinearDamping(30)
        self._body._native:setAngularDamping(30)
        self._body:add_tag("draw")
    end

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

    if type == b2.BodyType.DYNAMIC then
        self._body:add_tag("draw")
    end
end

--- @brief
function ow.Hitbox:draw()
    if self._body:has_tag("draw") then
        self._body:draw()
    end
end
