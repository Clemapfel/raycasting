require "love.audio"
require "love.sound"
require "love.data"

require "include"
require "common.smoothed_motion_1d"
require "common.filesystem"
require "common.interpolation_functions"
require "common.audio_time_unit"
require "common.sound_effect"
require "common.cross_fader"

rt.settings.music_manager = {
    assets_directory = "assets/music",
    loop_config_path = "assets/music/.loops.lua",
    update_step = 1 / 240, -- seconds
    source_buffer_count = 8,
    n_samples_per_chunk = 2^12, -- bits
    silence_threshold = 0.01, -- gain, in [0, 1]
    max_cache_size_mb = 150 -- mb
}

--- @class rt.MusicManager
rt.MusicManager = meta.class("MusicManager")
meta.add_signal(rt.MusicManager, "changed")

local _FADER_A = -1
local _FADER_B = 1
local _A = true
local _B = false
local _DEFAULT_LOOP_ID = 0

local _MODE_NOOP = 0
local _MODE_PAUSE = 1
local _MODE_STOP = 2
local _MODE_RESTART = 3

-- priority based sound data caching
local _cache = {} -- Table<Path, SoundData>
local _cache_size_mb = 0
local _cache_priority = {} -- Priority Queue, most recently used at back, oldest first

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

            loop = {}, -- Pair<Sample_i, Sample_i>

            n_channels = nil, -- 1 or 2
            bit_depth = nil, -- 8 or 16
            sample_type = nil, -- "uint8_t" or "int16_t"
            sample_rate = nil
        }
    end

    self._queue = {} -- cf. `play`
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
    self._pause_motion = rt.SmoothedMotion1D(1, 2) -- 2x speed
    -- 0: fully pause, 1: unpaused
    
    self._on_silence = nil -- Function, oneshot

    -- load looping metadata
    do
        local path = rt.settings.music_manager.loop_config_path
        local throw = function(...)
            rt.error("In rt.MusicManager.instantiate: when trying to load file at `", path, "`:")
        end

        local config, valid = nil, false
        if bd.is_file(path) then
            config = bd.load(path, true)
            if config ~= nil then
                for id, loop in pairs(config) do
                    if not meta.is_string(id) then
                        throw("id `", id, "` is not a string")
                    end

                    if self._id_to_path[id] == nil then
                        throw("id `", id, "` does not point to a valid path in `", rt.settings.music_manager.assets_directory, "`")
                    end

                    if not meta.is_table(loop) then
                        throw("value for id `", id, "` is not a table")
                    end

                    if not (#loop == 2 and meta.is_integer(loop[1]) and meta.is_integer(loop[2])) then
                        throw("value for id `", id, "` is not a pair of integers. Loop positions sample positions, not seconds, and there is only 1 loop region")
                    end
                end

                valid = true
            end
        end

        if not valid then
            rt.critical("In rt.MusicManager: music loop metadata file at `", path, "` does not exist or does not return a table")
        end

        self._id_to_loop = config
    end
end

--- @brief
function rt.MusicManager:play(id, skip_fade)
    if skip_fade == nil then skip_fade = false end
    meta.assert(
        id, mt.String,
        skip_fade, mt.Boolean
    )

    -- sic, override queue
    self._queue = {{
        id = id,
        skip_fade = skip_fade
    }}
end

--- @brief
function rt.MusicManager:stop(reset_to_loop_or_file)
    if reset_to_loop_or_file == nil then reset_to_loop_or_file = true end
    meta.assert(reset_to_loop_or_file, mt.Boolean)
    if self._a.source == nil and self._b.source == nil then return end

    self._pause_motion:set_target_value(0)
    self._on_silence = function(entry)
        -- reset entry
        if reset_to_loop_or_file == true then
            entry.sample_position = entry.loop[1]
        else
            entry.sample_position = 0
        end

        if entry.source ~= nil then
            entry.source:stop()
        end
    end
end

--- @brief
function rt.MusicManager:unpause()
    if self._a.source == nil and self._b.source == nil then return end

    if not self:get_is_paused() then return end
    self._pause_motion:set_target_value(1)
end

--- @brief
function rt.MusicManager:pause()
    if self._a.source == nil and self._b.source == nil then return end

    if self:get_is_paused() then return end
   self._pause_motion:set_target_value(0)
end

--- @brief
function rt.MusicManager:get_is_paused()
    return self._pause_motion:get_target_value() == 0 or
        (self._a.source == nil and self._b.source == nil )
end

--- @brief
function rt.MusicManager:add_effect(effect)
    meta.assert(effect, rt.SoundEffect)
    self:add_effect_native(effect:get_native())
end

--- @brief
function rt.MusicManager:add_effect_native(effect)
    meta.assert(effect, mt.String)

    self._sound_effects[effect] = true
    self._sound_effects_need_update = true
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
        for i, other in ipairs(_cache_priority) do
            if other == path then
                table.remove(_cache_priority, i)
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
        table.insert(_cache_priority, path)
    end

    while _cache_size_mb > rt.settings.music_manager.max_cache_size_mb do
        local oldest = _cache_priority[1]
        if oldest == nil then break end

        local old_data = _cache[oldest]

        _cache[oldest] = nil -- free cache ref, MusicManager may keep it next to the source
        table.remove(_cache_priority, 1)
        _cache_size_mb = _cache_size_mb - _get_data_size_mb(old_data)
    end

    return data
end

--- @brief
function rt.MusicManager:_apply_state(entry)
    if entry.source == nil then return end
    entry.source:setVolume(entry.gain * self._volume_motion:get_value() * self._pause_motion:get_value())
    entry.source:setPitch(self._pitch_motion:get_value())

    local filter_t = self._filter_motion:get_value()
    entry.source:setFilter({
        type = "bandpass",
        highgain = filter_t,
        lowgain = 1 - filter_t
    })
end

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

    local current, next, fader_current, fader_next
    if self._which == _A then
        current, next = self._a, self._b
        fader_current, fader_next = _FADER_A, _FADER_B
    else
        current, next = self._b, self._a
        fader_current, fader_next = _FADER_B, _FADER_A
    end

    -- update source effects
    for entry in range(current, next) do
        self:_apply_state(entry)
    end

    -- queue next entry
    if #self._queue > 0 and math.abs(fader_t) > (1 - silence_threshold) then
        local id = self._queue[1].id
        local path = self._id_to_path[id]
        local skip_fade = next.source == nil or self._queue[1].skip_fade == true

        if path == nil then
            rt.error("In MusicManager: when trying to queue file with id `", id, "`: no such resource ID exists")
        else
            local data = self:_load_data(path)
            if data ~= nil then
                if next.source ~= nil then
                    next.source:stop()
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

                    next.n_samples = data:getSampleCount() * data:getChannelCount()
                    next.sample_type = ternary(next.bit_depth == 8, "uint8_t", "int16_t")
                    next.source = love.audio.newQueueableSource(
                        next.sample_rate,
                        next.bit_depth,
                        next.n_channels,
                        rt.settings.music_manager.source_buffer_count
                    )
                end

                -- default loop id: full track
                local loop = self._id_to_loop[id]
                if loop == nil then
                    loop = { 0, next.n_samples}
                end

                next.loop = loop
                next.sample_position = next.loop[1]

                self:_apply_state(next)
            end
        end

        self._fader_motion:set_target_value(fader_next)

        if skip_fade then
            self._fader_motion:set_value(self._fader_motion:get_target_value())
        end

        self._which = not self._which

        table.remove(self._queue, 1)
        if _skip_next_delta then return end
    end


    local n_samples_per_chunk = rt.settings.music_manager.n_samples_per_chunk
    for entry in range(current, next) do
        local source, data = entry.source, entry.data

        if source ~= nil and data ~= nil then
            local n_samples_to_n_bytes = function(n_samples)
                return n_samples * (entry.bit_depth / 8)
            end

            local chunk_n_samples = n_samples_per_chunk * entry.n_channels

            local loop = entry.loop
            local loop_start = math.max(0, loop[1])
            local loop_end = math.min(entry.n_samples, loop[2])

            local position = entry.sample_position

            while source:getFreeBufferCount() > 0 do
                if position >= loop_end then
                    position = loop_start
                end

                local to_queue_n = math.min(chunk_n_samples, loop_end - position)
                if to_queue_n <= 0 or not source:queue(data,
                    n_samples_to_n_bytes(position),
                    n_samples_to_n_bytes(to_queue_n)
                ) then
                    -- no buffers left
                    break
                end

                position = position + to_queue_n
            end

            entry.sample_position = position
        end
    end

    for entry in range(current, next) do
        if entry.source ~= nil then
            if pause > silence_threshold then
                entry.source:play()
                -- play needs to be called every update because of `Source:queue`
            else
                entry.source:pause()
                if self._on_silence ~= nil then
                    self._on_silence(entry)
                end
            end
        end
    end

    self._on_silence = nil
end