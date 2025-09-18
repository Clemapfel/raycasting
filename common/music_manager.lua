rt.settings.music_manager = {
    config_directory = "assets/music"
}

    --[[
    set_music
    play(next, crossfade = true)
    reset()
    pause()
    resume(next?)

    ]]--

--- @class rt.MusicManager
rt.MusicManager = meta.class("MusicManager")

--- @brie
function rt.MusicManager:instantiate()

end


rt.MusicManager = rt.MusicManager() -- singleton instance