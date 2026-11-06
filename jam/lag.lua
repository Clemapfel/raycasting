Lag_t = "lag"

lag_new = function(value, speed, ramp)
    if speed == nil then speed = 1 end
    if ramp == nil then ramp = math_ln(1000) end
    log_typecheck(value, Number_t, speed, Number_t, ramp, Number_t)

    return new(Lag_t, {
        attack_speed = speed,
        decay_speed = speed,
        ramp = ramp,
        current_value = value,
        target_value = value,
    })
end

lag_get_value = function(self)
    log_typecheck(self, Lag_t)
    return self.current_value
end

lag_get_target_value = function(self)
    log_typecheck(self, Lag_t)
    return self.target_value
end

lag_set_target_value = function(self, x)
    log_typecheck(self, Lag_t, x, Number_t)
    self.target_value = x
    return self
end

lag_set_value = function(self, x)
    log_typecheck(self, Lag_t, x, Number_t)
    log.current_value = x
    return self
end

lag_skip = function(self)
    log_typecheck(self, Lag_t)
    log.current_value = log.target_value
    return self
end

lag_set_speed = function(self, attack_speed, decay_speed)
    if decay_speed == nil then decay_speed = attack_speed end
    log_typecheck(self, Lag_t, attack_speed, Number_t, decay_speed, Number_t)
    self.attack_speed = attack_speed
    self.decay_speed = decay_speed
    return self
end

lag_update = function(self, delta)
    log_typecheck(self, Lag_t, delta, Number_t)

    local distance = self.target_value - self.current_value
    local speed = distance > 0 and self.attack_speed or self.decay_speed
    local step = self.ramp * distance * speed * delta
    local value = self.current_value + step

    if (distance > 0 and value > self.target_value)
        or (distance < 0 and value < self.target_value)
    then
        value = self.target_value
    end

    self.current_value = value
    return self
end