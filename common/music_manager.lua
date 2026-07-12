require "common.music_manager_handler"
require "common.music_manager_instance"

if true then
    -- proxy manager, run real manager threaded
    -- allows for higher refresh rate than vsync
    -- also protects against frame dips causing
    -- audio artifacting
    rt.MusicManager = meta.as_singleton(rt.MusicManagerHandler)
else
    -- run in main at vsync rate
    rt.MusicManager = meta.as_singleton(rt.MusicManager)
end

if rt.GameState ~= nil then
    rt.MusicManager:set_volume(rt.GameState:get_music_level())
end