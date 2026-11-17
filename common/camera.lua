require "common.random"
require "common.smoothed_motion_2d"
require "common.transform"
require "common.envelope"

rt.settings.camera = {
    max_velocity = 500, -- px per second
    target_velocity = 50,

    max_scale_velocity = 5, -- fraction per second
    target_scale_velocity = 2,

    min_scale = 1 / 4,
    max_scale = 30,

    shake_max_frequency = 30,
    shake_max_offset = 6, -- px
    shake_impulse = {
        envelope_attack = 0,
        envelope_decay = 0,
        default_duration = 0.05,
        default_intensity = 2,
        max_offset = 5,
        frequency = 20, -- nodes per second
    }
}

--- @class rt.Camera
rt.Camera = meta.class("Camera")

--- @brief
function rt.Camera:instantiate()
    meta.install(self, {

    })
end