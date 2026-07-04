--- @class ow.DarknessArea
ow.DarknessArea = meta.class("DarknessArea", ow.MovableObject)

local schema = {
    strength = ow.Number,
}

--- @brief
function ow.DarknessArea:instantiate(object, stage, scene)
    object:validate_schema(schema, ow.ShapeType.NOT_A_POINT)

    local body = object:create_physics_body(stage:get_physics_world(), b2.BodyType.KINEMATIC)
    body:add_tags("use_darkness", "use_lighting")
    body:set_collision_group(0x0)
    self._body = body

    local strength = object:get_number("strength")
    if strength == nil then strength = 1 end

    rt.assert(strength >= 0 and strength <= 1, "In ow.DarknessArea: `strength` attribute is outside of [0, 1]")
    self.get_darkness_strength = function(self)
        return strength
    end
    body:set_user_data(self)
end