require "love.audio"
require "love.sound"
require "love.data"

require "include"
require "common.filesystem"
require "common.interpolation_functions"
require "common.audio_time_unit"
require "common.sound_effect"
require "common.cross_fader"

rt.settings.music_manager = {
    assets_directory = "assets/music",
    update_step = 1 / 240, -- seconds
    source_buffer_count = 8,
    n_samples_per_chunk = 2^12,
    silence_threshold = 0.1, -- gain, in [0, 1]
    max_cache_size_mb = 50, -- mb
}

--- @class rt.MusicManager
rt.MusicManager = meta.class("MusicManager")

local _FADER_A = -1
local _FADER_B = 1
local _A = true
local _B = false
local _DEFAULT_LOOP_ID = 0

local _cache = {} -- Table<Path, SoundData>
local _cache_size_mb = 0
local _cache_queue = {} -- Priority Queue, most recently used at back, oldest first

--- @brief
function rt.MusicManager:instantiate()
    self._id_to_entry = {}

    local prefix = bd.normalize_path(rt.settings.music_manager.assets_directory)
    if string.last(prefix) ~= "/" then prefix = prefix .. "/" end
    self._id_to_path = bd.generate_resource_ids(prefix, bd.is_sound_file)

    self._new_entry = function(self, id)
        return {
            id = nil, -- ID
            source = nil, -- love.QueueableSource
            data = nil, -- love.SoundData
            sample_position = 0,
            n_samples = 0,
            gain = 0,

            loops = {}, -- Table<Pair<Sample_i, Sample_i>>
            loop_id = _DEFAULT_LOOP_ID,

            n_channels = nil, -- 1 or 2
            bit_depth = nil, -- 8 or 16
            sample_type = nil, -- "uint8_t" or "int16_t"
            sample_rate = nil
        }
    end

    self._queue = {} -- Table<ID>
    self._a = self:_new_entry()
    self._b = self:_new_entry()
    self._which = _A

    self._fader = rt.CrossFader(0)
    self._fader_motion = rt.SmoothedMotion1D(-1,
        1 / 4
    )
    -- -1: current, 1: next

    self._sound_effects = {}
    self._sound_effects_need_update = false

    self._filter = 0
    self._filter_motion = rt.SmoothedMotion1D(0.5)
    -- 0: lowpass, 0.5: no filter, 1: highpass

    self._pitch_motion = rt.SmoothedMotion1D(1)
    -- -1: -12 semitones, 0: no change, +1: +12 semitones

    self._volume_motion = rt.SmoothedMotion1D(1)
    self._pause_motion = rt.SmoothedMotion1D(1)
    -- 0: fully pause, 1: unpaused
end

--- @brief
function rt.MusicManager:play(id, loop_id)
    if loop_id == nil then loop_id = _DEFAULT_LOOP_ID end
    meta.assert(id, mt.String, loop_id, mt.Union(mt.Number, mt.String))

    table.insert(self._queue, {
        id = id,
        loop_id = loop_id
    })
end

--- @brief
function rt.MusicManager:stop(should_reset_playback)
    if should_reset_playback == nil then should_reset_playback = true end
    meta.assert(should_reset_playback, mt.Boolean)

end

--- @brief
function rt.MusicManager:unpause()
    self:play(ternary(self._which == _A, self._a.id, self._b.id), false)
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
    self._filter_motion:set_target_value(t)
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
    self._pitch_motion:set_target_value(pitch)
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

    -- TODO
end

local _skip_next_delta = false
local _get_data_size_mb = function(data)
    return (data:getSampleCount() * data:getBitDepth() * data:getChannelCount()) / (8 * 1024^2)
end

--- @brief
function rt.MusicManager:_load_data(path)
    local data = _cache[path]
    local should_add_size = false

    if data ~= nil then
        -- remove to bubble up to most recently used
        for i, other in ipairs(_cache_queue) do
            if other == path then
                table.remove(_cache_queue, i)
                break
            end
        end

        -- was already in queue, cache did not increase size
    else
        local success, data_or_error = pcall(love.sound.newSoundData, path)
        if not success then
            rt.error(data_or_error)
        else
            data = data_or_error
            _cache[path] = data
            _cache_size_mb = _cache_size_mb + _get_data_size_mb(data)
            _skip_next_delta = true -- prevent lag spike
        end
    end

    if data ~= nil then
        table.insert(_cache_queue, path)
    end

    while _cache_size_mb > rt.settings.music_manager.max_cache_size_mb do
        local oldest = _cache_queue[1]
        if oldest == nil then break end

        local old_data = _cache[oldest]

        _cache_queue[oldest] = nil -- free cache ref, MusicManager may keep it next to the source
        table.remove(_cache_queue, 1)
        _cache_size_mb = _cache_size_mb - _get_data_size_mb(old_data)
    end

    return data
end

--- @brief
function rt.MusicManager:update(delta)
    meta.assert(delta, mt.Number)

    if _skip_next_delta then _skip_next_delta = false; return end

    local silence_threshold = rt.settings.music_manager.silence_threshold

    local fader_t = self._fader_motion:update(delta)
    local filter_t = self._filter_motion:update(delta)
    local pitch = self._pitch_motion:update(delta)
    local volume = self._volume_motion:update(delta)
    local pause = self._pause_motion:update(delta)

    self._a.gain, self._b.gain = self._fader:get_gain(fader_t)

    local current, next
    if self._which == _A then
        current, next = self._a, self._b
    else
        current, next = self._b, self._a
    end

    -- update source effects
    for entry in range(current, next) do
        local source = entry.source
        if source ~= nil then
            source:setVolume(entry.gain * volume * pause)
            source:setPitch(pitch)
            source:setFilter({
                type = "bandpass",
                highgain = filter_t,
                lowgain = 1 - filter_t
            })
        end
    end

    -- queue next entry
    if #self._queue > 0 and math.abs(fader_t) > (1 - silence_threshold) then
        local id = self._queue[1].id
        local loop_id = self._queue[1].loop_id
        local path = self._id_to_path[id]

        if path == nil then
            rt.error("In MusicManager: when trying to queue file with id `", id, "`: no such resource ID exists")
        else
            local data = self:_load_data(path)
            if data ~= nil then
                if next.source ~= nil then
                    next.source:stop()
                    next.source = nil
                end

                if next.data ~= nil then
                    next.data = nil
                end

                next.path = path
                next.id = id
                next.data = data

                local n_channels = data:getChannelCount()
                local bit_depth = data:getBitDepth()
                local sample_rate = data:getSampleRate()

                -- if format differs, allocate new source
                local source = next.source
                if source == nil
                    or next.n_channels ~= n_channels
                    or next.bit_depth ~= bit_depth
                    or next.sample_rate ~= sample_rate
                then
                    next.n_channels = n_channels
                    next.bit_depth = bit_depth
                    next.sample_rate = sample_rate

                    next.n_samples = data:getSampleCount()
                    next.sample_type = ternary(next.bit_depth == 8, "uint8_t", "int16_t")
                    next.source = love.audio.newQueueableSource(
                        next.sample_rate,
                        next.bit_depth,
                        next.n_channels,
                        rt.settings.music_manager.source_buffer_count
                    )
                    next.source:play()
                end

                -- default loop id: full track
                local loops = { [0] = { 0, next.n_samples} }
                -- TODO: load loop points from config

                if loops[loop_id] == nil then
                    rt.error("In rt.MusicManager: track with id `", id, "` does not have a loop point `", loop_id, "`")
                    loop_id = _DEFAULT_LOOP_ID
                end

                next.loops = loops
                next.loop_id = loop_id
                next.sample_position = next.loops[next.loop_id][1]
                next.n_samples = next.data:getSampleCount()
            end
        end

        if self._which == _A then
            self._fader_motion:set_target_value(_FADER_B) -- fade toward B, which now holds the "next" track
        else
            self._fader_motion:set_target_value(_FADER_A) -- fade toward A, which now holds the "next" track
        end

        self._which = not self._which
        table.remove(self._queue, 1)

        return
    end

    -- queue chunks
    local n_samples_per_chunk = rt.settings.music_manager.n_samples_per_chunk
    for entry in range(current, next) do
        local n_samples_to_n_bytes = function(n_samples)
            return n_samples * (entry.bit_depth / 8) -- bit depth is uint8_t or int16_t
        end

        local source, data = entry.source, entry.data
        local n_samples_to_n_bytes = function(n_samples)
            return n_samples * (entry.bit_depth / 8) -- bit depth is uint8_t or int16_t
        end

        local source, data = entry.source, entry.data
        if entry.source ~= nil and entry.data ~= nil then
            local chunk_n_samples = n_samples_per_chunk * entry.n_channels

            for _ = 1, source:getFreeBufferCount() do
                local loop = entry.loops[entry.loop_id]
                local loop_start_samples = loop[1] -- 0-based
                local loop_end_samples = loop[2] -- exclusive end

                local was_queued = false

                if entry.sample_position + chunk_n_samples > loop_end_samples then
                    local remaining_samples = chunk_n_samples
                    local position = entry.sample_position

                    while remaining_samples > 0 do
                        local to_queue_n = math.min(
                            loop_end_samples - position, -- samples until end of loop
                            remaining_samples
                        )

                        if to_queue_n > 0 then
                            was_queued = source:queue(data,
                                n_samples_to_n_bytes(position),
                                n_samples_to_n_bytes(to_queue_n)
                            )

                            if not was_queued then break end
                        end

                        remaining_samples = remaining_samples - to_queue_n
                        position = position + to_queue_n

                        -- wrap back to loop start once we hit the loop end
                        if position >= loop_end_samples then
                            position = loop_start_samples
                        end
                    end

                    entry.sample_position = position
                else
                    local chunk_start = n_samples_to_n_bytes(entry.sample_position)
                    local chunk_size = n_samples_to_n_bytes(chunk_n_samples)

                    was_queued = source:queue(data,
                        chunk_start, -- offset in bytes
                        chunk_size  -- size in bytes
                    )

                    if was_queued then
                        entry.sample_position = entry.sample_position + chunk_n_samples
                    end
                end

                if not was_queued then break end
            end

            entry.source:play()
        end
    end
end