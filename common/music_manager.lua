if true then
    -- proxy manager, run real manager threaded
    -- allows for higher refresh rate than vsync
    -- also protects against frame dips causing
    -- audio artifacting
    require "common.music_manager_handler"
    rt.MusicManager = meta.as_singleton(rt.MusicManagerHandler)
else
    -- run in main at vsync rate
    require "common.music_manager_instance"
    rt.MusicManager = meta.as_singleton(rt.MusicManager)
end

if rt.GameState ~= nil then
    rt.MusicManager:set_volume(rt.GameState:get_music_level())
end