--[[
--- @class ow.RotaryMotor
--- @field target ow.ObjectWrapper
--- @field initial_angle Number in [0, 1]
ow.RotaryMotor = meta.class("RotaryMotor", rt.Drawable)

--- @class ow.RotaryMotorTarget
ow.RotaryMotorTarget = meta.class("RotaryMotorTarget") -- dummy

--- @brief
function ow.RotaryMotor:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    local target = object:get_object("target", true)

    meta.install(self, {
        _anchor = object:create_physics_body(world, b2.BodyType.STATIC),
        _target = target:create_physics_body(world, b2.BodyType.DYNAMIC)
    })

    self._anchor:set_is_sensor()

    local anchor_x, anchor_y = object:get_centroid()

    self._joint = love.physics.newRevoluteJoint(
        self._anchor:get_native(),
        self._target:get_native(),
        anchor_x, anchor_y, -- pivot is centroid of anchor
        false
    )
end

--- @brief
--- @param x Number radians
function ow.RotaryMotor:set_value(x)
end
]]--