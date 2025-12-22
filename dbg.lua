return {
    ground_acceleration_duration = 5 / 60, -- seconds to target velocity if currently slower
    ground_deceleration_duration = 2 / 60, -- seconds to target velocity if currently faster
    air_acceleration_duration = 8 / 60,
    air_deceleration_duration = 8 / 60,

    air_decay_duration = 20 / 60, -- seconds to 0 if controller neutral
    ground_decay_duration = 4.5 / 60, -- seconds to 0 if controller neutral

    ground_target_velocity_x = 180, -- px / s
    air_target_velocity_x = 160,

    wall_jump_duration = 12 / 60,
    wall_jump_initial_impulse = 400,
    wall_jump_freeze_duration = 7 / 60,

    bottom_wall_ray_length_factor = 1.5,
}

