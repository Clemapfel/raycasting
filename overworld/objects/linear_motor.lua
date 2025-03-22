--- @class ow.LinearMotor
--- @field target ow.ObjectWrapper
--- @field speed Number?
--- @field initial_position Number?
ow.LinearMotor = meta.class("LinearMotor", rt.Drawable)
meta.add_signals(ow.LinearMotor,
    "start", --- @signal start (self) -> nil
    "stop",  --- @signal stop (self) -> nil
    "set",   --- @signal set (self, Number) -> nil
    "toggle" --- @signal toggle (self) -> nil
)

--- @brief
function ow.LinearMotor:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    local target = object:get_object("target", true)

    local signal_id
    signal_id = stage:signal_connect("initialized", function(stage)
        meta.install(self, {
            _anchor = object:create_physics_body(world, b2.BodyType.STATIC),
            _target = stage:get_object_instance(target):get_physics_body()
        })

        if self._target:get_type() == b2.BodyType.STATIC then
            rt.warning("In ow.LinearMotor: instance of target object `" .. object.id .. "` of stage `" .. stage:get_id() .. "` is static, it cannot be moved")
        end

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
            self:set_value(0)
        end

        self:signal_connect("start", function(self, value)
            self._joint:setMotorEnabled(true)
            self:set_value(self, value or self._value)
        end)

        self:signal_connect("stop", function(self)
            self._joint:setMotorEnabled(false)
        end)

        self:signal_connect("set", function(self, value)
            self._joint:setMotorEnabled(true)
            self:set_value(value)
        end)

        self:signal_connect("toggle", function(self, value)
            if self._value > 0 then
                self:set_value(0)
            else
                self:set_value(1)
            end
            dbg(self._value)
        end)

        stage:signal_disconnect("initialized", signal_id)
    end)
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

--- @brief
function ow.LinearMotor:draw()
    self._anchor:draw()
    self._target:draw()

    local anchor_x, anchor_y = self._anchor:get_center_of_mass()
    local target_x, target_y = self._target:get_center_of_mass()
    love.graphics.line(anchor_x, anchor_y, target_x, target_y)
end