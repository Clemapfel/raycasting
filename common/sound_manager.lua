rt.settings.sound_manager = {
    music_volume = 1,
    sound_effects_volume = 1,
}

--- @class rt.SoundManager
rt.SoundManager = meta.class("SoundManager")

local _warning_printed = {}

--- @brief
function rt.SoundManager:play(id, position_x, position_y, pitch)
    if _warning_printed[id] == nil then
        rt.warning("In rt.SoundManager.play: no sound with id `" .. id .. "`")
        _warning_printed[id] = true
    end
end

rt.SoundManager = rt.SoundManager() -- static instance
