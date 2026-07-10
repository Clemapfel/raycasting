require "love.audio"
require "love.sound"
require "love.data"

require "include"
require "common.filesystem"
require "common.smoothed_motion_nd"
require "common.interpolation_functions"
require "common.audio_time_unit"
require "common.sound_effect"
require "common.fader"

rt.settings.music_manager = {
    assets_directory = "assets/music",
    update_step = 1 / 240 -- seconds
}

--- @class rt.MusicManager
rt.MusicManager = meta.class("MusicManager")

--- @brief
function rt.MusicManager:instantiate()
    self._id_to_entry = {}

    do -- generate entries
        local prefix = bd.normalize_path(rt.settings.music_manager.assets_directory)
        if string.last(prefix) ~= "/" then prefix = prefix .. "/" end

        local id_to_path = bd.generate_resource_ids(prefix, bd.is_sound_file)
        for id, path in pairs(id_to_path) do
            self._id_to_entry[id] = {
                id = id,
                path = path,
                loop_points = {},
                data = nil -- love.SoundData
            }
        end
    end

    self._current_id = nil
    self._current_source = nil -- love.QueueableSource
    self._current_entry = nil

    self._next_id = nil
    self._next_source = nil -- love.QueueableSource
    self._next_entry = nil

    self._fader = rt.CrossFader()
    self._fader_motion = rt.SmoothedMotion1D(0)
    -- 0: current, 1: next

    self._sound_effects = {}
    self._sound_effects_need_update = false

    self._filter = 0
    self._filter_motion = rt.SmoothedMotion1D(0.5)
    -- 0: lowpass, 0.5: no filter, 1: highpass

    self._pitch_motion = rt.SmoothedMotion1D(1)
    -- 1: no change, 0.5: -12 semitones, 2: +12 semitones

    self._volume_motion = rt.SmoothedMotion1D(1)
end

--- @brief
function rt.MusicManager:play(id, restart_if_active)
    if id == nil and self._current_id == nil then return end
    if restart_if_active == nil then restart_if_active = false end
    meta.assert(id, mt.String, restart_if_active, mt.Boolean)
end

--- @brief
function rt.MusicManager:stop(should_reset_playback)
    if should_reset_playback == nil then should_reset_playback = true end
    meta.assert(should_reset_playback, mt.Boolean)

end

--- @brief
function rt.MusicManager:unpause()
    if self._current_id == nil then return end
    self:play(self._current_id, false)
end

--- @brief
function rt.MusicManager:pause()
    self:stop(false)
end

--- @brief
function rt.MusicManager:add_effect(effect)
    meta.assert(effect, rt.SoundEffect)

    self._sound_effects[effect:get_native()] = true
    self._sound_effects_need_update = true
end

--- @brief
function rt.MusicManager:add_effect_native(effect)
    meta.assert(effect, rt.SoundEffect)
end

--- @brief
function rt.MusicManager:remove_effect(effect)
    meta.assert(effect, rt.SoundEffect)

    local was_removed = self._sound_effects[effect] == true
    self._sound_effects[effect] = nil

    if was_removed == true then
        self._sound_effects_need_update = true
    end
end

--- @brief
function rt.MusicManager:set_filter(t)
    meta.assert(t, mt.Number)

    t = math.clamp(t, 0, 1)
    self._filter_motion:set_target_value(1)
end

--- @brief
function rt.MusicManager:remove_filter()
    self._filter_motion:set_target_value(0)
end

--- @brief
function rt.MusicManager:set_volume(volume)
    meta.assert(volume, mt.Number)
    self._volume_motion:set_target_value(volume)
end

--- @brief
function rt.MusicManager:set_pitch(pitch)
    meta.assert(pitch, mt.Number)

    pitch = math.max(pitch, 0)
    self._pitch_motion.set_target_value(pitch)
end

--- @brief
function rt.MusicManager:reset()
    local volume = 1
    if rt.GameState ~= nil then volume = rt.GameState:get_music_level() end

    for motion_value in range(
        { self._fader_motion, 1 },
        { self._filter_motion, 0.5 },
        { self._pitch_motion, 1 },
        { self._volume_motion, volume}
    ) do
        local motion, value = table.unpack(motion_value)
        motion:set_value(value)
        motion:set_target_value(value)
    end

    for source in range(
        self._current_source,
        self._next_source
    ) do -- already filters nils
        source:stop()
        source:setVolume(0)
        source:setFilter(nil)
        for effect in values(source:getActiveEffects()) do
            source:setEffect(effect, false)
        end
    end

    for id, entry in pairs(self._entries) do
        entry.data = nil
    end
end

--- @brief
function rt.MusicManager:update(delta)
    meta.assert(delta, mt.Number)

    local fader_t = self._fader_motion:update(delta)
    local filter_t = self._filter_motion:update(delta)
    local pitch = self._pitch_motion:update(delta)
    local volume = self._volume_motion:update(delta)

    local current_gain, next_gain = self._fader:get_gain(fader_t)
    for source_gain in range(
        { self._current_source, current_gain },
        { self._next_source, next_gain }
    ) do
        local source, gain = table.unpack(source_gain)
        if source ~= nil then
            source:setVolume(gain * volume)
            source:setPitch(pitch)
            source:setFilter({
                type = "bandpass",
                highgain = filter_t,
                lowgain = 1 - filter_t
            })
        end
    end
end