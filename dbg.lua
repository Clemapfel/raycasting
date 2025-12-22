local f = 100

return {
    ground_acceleration_duration = 5 / 60, -- seconds to target velocity if currently slower
    ground_deceleration_duration = 2 / 60, -- seconds to target velocity if currently faster
    air_acceleration_duration = 1 / 60,
    air_deceleration_duration = 0,

    air_decay_duration = 0.5, -- seconds to 0 if controller neutral
    ground_decay_duration = 0.2, -- seconds to 0 if controller neutral

    target_velocity_x = 300 -- px / s
}

