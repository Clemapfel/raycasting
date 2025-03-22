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

    -- delay until other object is initialized
    local signal_id
    signal_id = stage:signal_connect("initialized", function(stage)
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

        self._joint:setMotorEnabled(false)
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

        self:signal_connect("start", function(self)
            self._joint:setMotorEnabled(true)
        end)

        self:signal_connect("stop", function(self)
            self._joint:setMotorEnabled(false)
        end)

        self:signal_connect("set", function(self, value)
            self._joint:setMotorEnabled(true)
            self:set_value(value)
        end)

        stage:signal_disconnect("initialized", signal_id)
    end)
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

--- @brief
function ow.RotaryMotor:draw()
    self._anchor:draw()
    self._target:draw()

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", self._anchor_x, self._anchor_y, 3)
end