--- @class ow.LinearMotor
--- @field target ow.ObjectWrapper
--- @field speed Number?
--- @field initial_position Number?
ow.LinearMotor = meta.class("LinearMotor", rt.Drawable)

--- @class ow.LinearMotorTarget
ow.LinearMotorTarget = meta.class("LinearMotorTarget") -- dummy

--- @brief
function ow.LinearMotor:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    local target = object:get_object("target", true)

    meta.install(self, {
        _anchor = object:create_physics_body(world, b2.BodyType.STATIC),
        _target = target:create_physics_body(world, b2.BodyType.DYNAMIC)
    })

    self._anchor:set_is_sensor(true)

    local anchor_x, anchor_y = object:get_centroid()
    local target_x, target_y = target:get_centroid()

    self._joint = love.physics.newPrismaticJoint(
        self._anchor:get_native(),
        self._target:get_native(),
        anchor_x, anchor_y,
        target_x - anchor_x, target_y - anchor_y,
        false
    )

    self._joint:setMotorEnabled(true)
    self._joint:setMotorSpeed(100 or object:get_number("speed"))
    self._joint:setMaxMotorForce(math.huge)
    self._joint:setLimitsEnabled(true)
    self._joint:setLowerLimit(-math.huge)
    self._joint:setUserData(self)

    self._length = math.distance(anchor_x, anchor_y, target_x, target_y)

    local initial_position = object:get_number("initial_position", false)
    if initial_position ~= nil then
        self:set_value(initial_position)
    else
        self:set_value(1)
    end
end

--- @brief
--- @param x Number 1: initial position, 0: fully contracted
function ow.LinearMotor:set_value(x)
    self._value = x
    self._joint:setUpperLimit(x * self._length - self._length)
end

--- @brief
function ow.LinearMotor:set_speed()
    self._joint:setMotorSpeed(100)
end

local _elapsed = 0

--- @brief
function ow.LinearMotor:update(delta)
    _elapsed = _elapsed + delta
    self:set_value(math.sin(_elapsed))
end

--- @brief
function ow.LinearMotor:draw()
    self._anchor:draw()
    self._target:draw()

    local anchor_x, anchor_y = self._anchor:get_center_of_mass()
    local target_x, target_y = self._target:get_center_of_mass()
    love.graphics.line(anchor_x, anchor_y, target_x, target_y)
end