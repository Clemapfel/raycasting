rt.settings.overworld.linear_motor = {
    speed = 1
}

--- @class ow.LinearMotor
--- @field target ow.ObjectWrapper
--- @field initial_position Number?
ow.LinearMotor = meta.class("LinearMotor", rt.Drawable)
meta.add_signals(ow.LinearMotor,
    "start", --- @signal start (self) -> nil
    "stop",  --- @signal stop (self) -> nil
    "set",   --- @signal set (self, Number) -> nil
    "toggle" --- @signal toggle (self) -> nil
)

--- @class ow.LinearMotorTarget
ow.LinearMotorTarget = meta.class("LinearMotortarget") -- dummy

--- @brief
function ow.LinearMotor:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    local target = object:get_object("target", true)

    self._speed = rt.settings.overworld.linear_motor.speed
    self._value = 0

    stage:signal_connect("initialized", function(stage)
        meta.install(self, {
            _anchor = object:create_physics_body(world, b2.BodyType.STATIC),
            _target = stage:get_object_instance(target):get_physics_body()
        })

        self._target:set_type(b2.BodyType.KINEMATIC)
        self._target:add_tag("no_blood")
        self._anchor:set_is_sensor(true)

        local anchor_x, anchor_y = self._anchor:get_center_of_mass()
        local target_x, target_y = self._target:get_center_of_mass()

        self._anchor_x, self._anchor_y = anchor_x - target_x, anchor_y - target_y
        self._target_x, self._target_y = target_x, target_y
        self._axis_x, self._axis_y = math.normalize(target_x - anchor_x, target_y - anchor_y)
        self._length = math.distance(anchor_x, anchor_y, target_x, target_y)

        self._joint = love.physics.newPrismaticJoint(
            self._anchor:get_native(),
            self._target:get_native(),
            anchor_x, anchor_y,
            target_x - anchor_x, target_y - anchor_y,
            false
        )

        self._joint:setMotorEnabled(false)
        self._joint:setLimitsEnabled(false)

        self._lower, self._upper = object:get_number("lower"), object:get_number("upper")

        local cycle = object:get_number("cycle")
        if cycle ~= nil then
            self._is_cycling = true
            self._cycle_duration = cycle
            self._cycle_elapsed = 0
            self._speed = self._length / (2 * self._cycle_duration)
        else
            self._is_cycling = false
            self._cycle_duration = math.huge
            self._cycle_elapsed = 0
        end

        self._is_active = true

        local initial_position = object:get_number("initial_position", false)
        if initial_position ~= nil then
            self:set_value(initial_position)
        end

        self:signal_connect("start", function(self, value)
            self._is_active = true
        end)

        self:signal_connect("stop", function(self)
            self._is_active = false
        end)

        self:signal_connect("set", function(self, value)
            self:set_value(value)
            self._is_active = true
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
--- @param x Number 1: initial position, 0: fully contracted
function ow.LinearMotor:set_value(x)
    self._value = x
end

function ow.LinearMotor:update(delta)
    if self._is_active ~= true then return end

    local value = math.clamp(self._value, self._lower, self._upper)

    if self._is_cycling then
        self._cycle_elapsed = self._cycle_elapsed + delta
        value = (math.sin(self._cycle_elapsed / self._cycle_duration) + 1) / 2
    end

    if self._lower ~= nil and self._upper ~= nil then
        value = math.mix(self._lower, self._upper, value)
    end

    local target_length = value * self._length
    local target_x, target_y = self._anchor_x + target_length * self._axis_x, self._anchor_y + target_length * self._axis_y

    local speed = self._speed -- in px / s
    local current_x, current_y = self._target:get_position()

    local velocity_x = (target_x - current_x) * speed * delta
    local velocity_y = (target_y - current_y) * speed * delta

    self._target:set_linear_velocity(velocity_x, velocity_y)
end

--- @brief
function ow.LinearMotor:draw()
    self._anchor:draw()
    self._target:draw()

    local anchor_x, anchor_y = self._anchor:get_center_of_mass()
    local target_x, target_y = self._target:get_center_of_mass()
    love.graphics.line(anchor_x, anchor_y, target_x, target_y)
end