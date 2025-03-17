rt.settings.sound_manager = {
    music_volume = 1,
    sound_effects_volume = 1,
}

--- @class rt.SoundManager
rt.SoundManager = meta.class("SoundManager")

--- @brief
function rt.SoundManager:play(id, position_x, position_y, pitch)
    rt.warning("In rt.SoundManager.play: no sound with id `" .. id .. "`")
end

rt.SoundManager = rt.SoundManager() -- static instance
