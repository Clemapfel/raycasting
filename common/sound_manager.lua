require "common.sound_manager_handler"
require "common.sound_manager_instance"

if true then
    -- proxy manager, run real manager threaded
    -- this allows a higher refresh rate than vsync
    -- which is important for smooth audio effects
    rt.SoundManager = meta.as_singleton(rt.SoundManagerHandler)
else
    -- run at vsync rate in main
    rt.SoundManager = meta.as_singleton(rt.SoundManager)
end

if rt.GameState ~= nil then
    rt.SoundManager:set_global_volume(rt.GameState:get_sound_effect_level())
end