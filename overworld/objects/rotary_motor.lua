rt.settings.overworld.rotary_motor = {
    speed = 1.5
}

--- @class ow.RotaryMotor
--- @field target ow.ObjectWrapper
--- @field speed Number?
--- @field initial_position Number?
ow.RotaryMotor = meta.class("RotaryMotor", rt.Drawable)
meta.add_signals(ow.RotaryMotor,
    "start", --- @signal start (self) -> nil
    "stop",  --- @signal stop (self) -> nil
    "set",   --- @signal set (self, Number) -> nil
    "toggle" --- @signal toggle (self) -> nil
)

--- @brief
function ow.RotaryMotor:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    local target = object:get_object("target", true)

    self._speed = rt.settings.overworld.rotary_motor.speed
    self._value = 0

    -- delay until other object is initialized
    stage:signal_connect("initialized", function(stage)
        meta.install(self, {
            _anchor = object:create_physics_body(world, b2.BodyType.STATIC),
            _target = stage:get_object_instance(target):get_physics_body()
        })

        if self._target:get_type() == b2.BodyType.STATIC then
            rt.warning("In ow.RotaryMotor: instance of target object `" .. object.id .. "` of stage `" .. stage:get_id() .. "` is static, it cannot be moved")
        end

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
        self._joint:setMotorSpeed(0)
        self._joint:setMaxMotorTorque(math.huge)
        self._joint:setLimitsEnabled(true)
        self._joint:setLimits(0, 2 * math.pi)
        self._joint:setUserData(self)

        self._is_active = true

        local initial_position = object:get_number("initial_position", false)
        if initial_position ~= nil then
            self:set_value(initial_position)
        end

        self:signal_connect("start", function(self)
            self._is_active = true
        end)

        self:signal_connect("stop", function(self)
            self._is_active = false
        end)

        self:signal_connect("set", function(self, value)
            self._is_active = true
            self:set_value(value)
        end)

        self:signal_connect("toggle", function(self, value)
            self._is_active = true
            if self._value > 0 then
                self:set_value(0)
            else
                self:set_value(1)
            end
        end)

        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
--- @param x Number radians
function ow.RotaryMotor:set_value(x)
    self._value = x
end

--- @brief
function ow.RotaryMotor:update(delta)
    if self._is_active ~= true then return end

    local target_angle = self._value * (2 * math.pi)
    local current_angle = self._joint:getJointAngle()
    local angle_difference = target_angle - current_angle
    self._joint:setMotorSpeed(angle_difference * self._speed)
end

--- @brief
function ow.RotaryMotor:draw()
    self._anchor:draw()
    self._target:draw()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self._anchor_x, self._anchor_y, 3)
end