rt.settings.overworld.velocity_multiplier_field = {
    x_factor = 1,
    y_factor = 5,
}

--- @class ow.VelocityMultiplierField
ow.VelocityMultiplierField = meta.class("VelocityMultiplierField")

--- @brief
function ow.VelocityMultiplierField:instantiate(object, stage, scene)
    self._body = object:create_physics_body(stage:get_physics_world())

    self._body:set_is_sensor(true)
    self._body:signal_connect("collision_start", function(_, other_body)
        if other_body:has_tag("player") then
            other_body:get_user_data()._velocity_multiplier_x = rt.settings.overworld.velocity_multiplier_field.x_factor
            other_body:get_user_data()._velocity_multiplier_y = rt.settings.overworld.velocity_multiplier_field.y_factor
        end
    end)

    self._body:signal_connect("collision_end", function(_, other_body)
        if other_body:has_tag("player") then
            other_body:get_user_data()._velocity_multiplier_x = 1
            other_body:get_user_data()._velocity_multiplier_y = 1
        end
    end)
end

--- @brief
function ow.VelocityMultiplierField:draw()
    rt.Palette.BLUE_2:bind()
    self._body:draw()
end