--- @class ow.ZeroGravityField
ow.ZeroGravityField = meta.class("ZeroGravityField")

--- @brief
function ow.ZeroGravityField:instantiate(object, stage, scene)
    self._body = object:create_physics_body(stage:get_physics_world())

    self._body:set_is_sensor(true)
    self._body:signal_connect("collision_start", function(_, other_body)
        if other_body:has_tag("player") then
            other_body:get_user_data()._gravity_multiplier = 0
        end
    end)

    self._body:signal_connect("collision_end", function(_, other_body)
        if other_body:has_tag("player") then
            other_body:get_user_data()._gravity_multiplier = 1
        end
    end)
end

--- @brief
function ow.ZeroGravityField:draw()
    rt.Palette.BLUE_2:bind()
    self._body:draw()
end