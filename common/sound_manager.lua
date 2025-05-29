--- @class rt.SoundManager
rt.SoundManager = meta.class("SoundManager")

local _warning_printed = {}

--- @brief
function rt.SoundManager:play(id, position_x, position_y, pitch)
    local music_level = rt.GameState:get_music_level()
    local sound_level = rt.GameState:get_sound_level()

    if _warning_printed[id] == nil then
        rt.warning("In rt.SoundManager.play: no sound with id `" .. id .. "`")
        _warning_printed[id] = true
    end
end

rt.SoundManager = rt.SoundManager() -- static instance
