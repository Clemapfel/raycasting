rt.settings.overworld.linear_motor = {
    speed = 10 -- px / s
}

--- @class ow.LinearMotor
--- @field target ow.ObjectWrapper object to move
--- @field lower ow.ObjectWrapper object axis start
--- @field upper ow.ObjectWrapper object axis end
--- @field cycle Number? cycle duration in seconds
ow.LinearMotor = meta.class("LinearMotor", rt.Drawable)

--- @class ow.LinearMotorTarget
ow.LinearMotorTarget = meta.class("LinearMotorTarget") -- dummy

--- @brief
function ow.LinearMotor:instantiate(object, stage, scene)
    local world = stage:get_physics_world()
    local target = object:get_object("target", true)
    local lower = object:get_object("lower", true)
    local upper = object:get_object("upper", true)

    stage:signal_connect("initialized", function(stage)
        self._target = stage:get_object_instance(target):get_physics_body()
        self._target:set_type(b2.BodyType.KINEMATIC)
        self._target:set_mass(1)
        self._target:add_tag("no_blood")

        assert(lower:get_type() == ow.ObjectType.POINT and upper:get_type() == ow.ObjectType.POINT, "In ow.LinearMotor.instantiate: `lower` or `upper` property is not a point")

        self._lower_x, self._lower_y = lower.x, lower.y
        self._upper_x, self._upper_y = upper.x, upper.y
        self._length = math.distance(lower.x, lower.y, upper.x, upper.y)

        self._target_x, self._target_y = self._target:get_center_of_mass()

        self._dx = self._upper_x - self._lower_x
        self._dy = self._upper_y - self._lower_y

        self._value = object:get_number("initial_value") or 0

        local cycle = object:get_number("cycle")
        if cycle ~= nil then
            self._is_cycling = true
            self._cycle_duration = cycle
            self._cycle_elapsed = 0
            self._speed = self._length / self._cycle_duration
        else
            self._is_cycling = false
            self._cycle_duration = math.huge
            self._cycle_elapsed = 0
            self._speed = rt.settings.overworld.linear_motor.default_speed
        end

        return meta.DISCONNECT_SIGNAL
    end)
end

--- @brief
function ow.LinearMotor:set_value(x)
    self._value = x
end

--- @brief
function ow.LinearMotor:update(delta)
    if self._is_cycling then
        self._cycle_elapsed = self._cycle_elapsed + delta
        self._value = (math.cos(self._cycle_elapsed / self._cycle_duration) + 1) / 2 -- cos for y = 0 at t = 0
    end

    local target_x, target_y = self._lower_x + self._value * self._dx, self._lower_y + self._value * self._dy
    local speed = self._speed -- in px / s
    local current_x, current_y = self._target:get_center_of_mass()

    self._target:set_linear_velocity(
        (target_x - current_x) * speed * delta,
        (target_y - current_y) * speed * delta
    )
end

--- @brief
function ow.LinearMotor:draw()
    if not self._scene:get_is_body_visible(self._target) then return end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setLineWidth(1)
    love.graphics.line(self._lower_x, self._lower_y, self._upper_x, self._upper_y)

    local target_x, target_y = self._lower_x + self._value * self._dx, self._lower_y + self._value * self._dy

    rt.Palette.BLACK:bind()
    love.graphics.circle("fill", target_x, target_y, 5)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.circle("fill", target_x, target_y, 4)
end