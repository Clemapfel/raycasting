require "common.sound_manager_handler"
require "common.sound_manager_instance"

if false then
    -- proxy manager, run real manager threaded
    -- this allows a higher refresh rate than vsync
    -- which is important for smooth audio effects
    rt.SoundManager = meta.as_singleton(rt.SoundManagerHandler)
else
    rt.SoundManager = meta.as_singleton(rt.SoundManager)
end