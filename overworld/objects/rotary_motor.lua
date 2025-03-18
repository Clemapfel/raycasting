--- @class ow.RotaryMotor
--- @field target ow.ObjectWrapper
--- @field speed Number?
--- @field initial_position Number?
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

    self._anchor:set_is_sensor(true)

    local anchor_x, anchor_y = object:get_centroid()
    self._anchor_x, self._anchor_y = anchor_x, anchor_y
    self._joint = love.physics.newRevoluteJoint(
        self._anchor:get_native(),
        self._target:get_native(),
        anchor_x, anchor_y, -- pivot is centroid of anchor
        false
    )

    self._joint:setMotorEnabled(true)
    self._joint:setMotorSpeed(100 or object:get_number("speed"))
    self._joint:setMaxMotorTorque(math.huge)
    self._joint:setLimitsEnabled(true)
    self._joint:setLowerLimit(-math.huge)
    self._joint:setUserData(self)

    local initial_position = object:get_number("initial_position", false)
    if initial_position ~= nil then
        self:set_value(initial_position)
    else
        self:set_value(1)
    end
end

--- @brief
--- @param x Number radians
function ow.RotaryMotor:set_value(x)
    self._joint:setUpperLimit(x * (2 * math.pi))
end

--- @brief
function ow.RotaryMotor:set_speed(x)
    self._joint:setMotorSpeed(x)
end

local _elapsed = 0

--- @brief
function ow.RotaryMotor:update(delta)
    _elapsed = _elapsed + delta
    self:set_value(math.sin(_elapsed))
end

--- @brief
function ow.RotaryMotor:draw()
    self._anchor:draw()
    self._target:draw()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self._anchor_x, self._anchor_y, 3)
end