require "love.audio"
require "love.sound"
require "love.timer"

require "include"
require "common.filesystem"
require "common.sound_effect"
require "common.smoothed_motion_1d"
require "common.smoothed_motion_2d"
require "common.interpolation_functions"

rt.settings.sound_manager = {
    assets_directory = "assets/sounds",

    default_equalization_alpha = 0.1,
    source_inactive_lifetime_threshold = 30, -- seconds
    source_stop_decay_duration = 20 / 60, -- seconds

    update_step = 1 / 240, -- seconds
}

--- @class rt.SoundManager
rt.SoundManager = meta.class("SoundManager")
meta.add_signals(rt.SoundManager,
    "sound_done" -- (rt.SoundManager, sound_id, handler_id)
)

--- @brief
function rt.SoundManager:instantiate()
    self._id_to_entry = {}
    self._current_handler_id = 1
    self._handler_id_to_sound_id = {}

    self._id_to_n_active_sources = {} -- Table<String, Number>
    self._active_entries = {} -- Set<Entry>

    -- positional audio
    self._listener_x = 0
    self._listener_y = 0

    love.audio.setPosition(0, 0, 0)
    love.audio.setVelocity(0, 0, 0)
    love.audio.setDistanceModel("inverse") -- non-clamped: attenuation can reach 0 for far-away sources
    love.audio.setOrientation(
        0, 0, 1,
        0, -1, 0
    ) -- automatically flips x and y to aligned with y-down, x-left coordinate system

    self._reference_distance = 1500 -- in px, adjust to increase attenuation
    self._z_height = -1500 -- in px, adjust to modify singularity in panning if source is close to listener

    -- volume equalization
    self._volume = 1.0
    self._equalizer = {
        average_root_mean_square = nil,
        target_root_mean_square = nil,
        n_sounds_processed = 0,
        equalization_alpha = rt.settings.sound_manager.default_equalization_alpha
    }

    self._id_to_entry = {}
    self._stop_entries = {}

    do -- generate entries
        local prefix = bd.normalize_path(rt.settings.sound_manager.assets_directory)
        if string.last(prefix) ~= "/" then prefix = prefix .. "/" end

        local id_to_path = bd.generate_resource_ids(prefix, bd.is_sound_file)

        if false then
        -- allow indexing like `rt.SoundManager.overworld.foo.effect.play()`, instead of `rt.SoundManager:play("overworld.foo.effect.play")

        local ids = {}
        local leaves = {}
        for id, path in pairs(id_to_path) do
            local split = { string.split(id, ".") }
            local current = ids
            for i = 1, #split do
                local key = split[i]
                if i == #split then
                    -- leaf
                    local leaf = {}

                    leaf.play = function(self, ...)
                        rt.assert(self == leaf, "In rt.SoundManager." .. id .. ".play: play called without instance, use `bar.foo:play()` instead of `bar.foo.play()` ")
                        return rt.SoundManager:play(id, ...)
                    end

                    leaf.stop = function(self, ...)
                        rt.assert(self == leaf, "In rt.SoundManager." .. id .. ".stop: play called without instance, use `bar.foo:stop()` instead of `bar.foo.stop()` ")
                        return rt.SoundManager:stop(id, ...)
                    end

                    leaf.id = id
                    leaf.path = path

                    current[key] = leaf
                    table.insert(leaves, leaf)
                else
                    if current[key] == nil then
                        current[key] = {}
                        local to_write = {}
                        for j = 1, i do table.insert(to_write, split[j]) end
                        setmetatable(current[key], { id = table.concat(to_write, ".") })
                    end
                    current = current[key]
                end
            end
        end

        -- make intermediate nodes immutable
        local function make_id_table(t, seen)
            if meta.is_table(t) then
                local metatable = getmetatable(t)
                if metatable ~= nil then
                    metatable.__index = function(self, key)
                        rt.error("In rt.SoundManager: no sound with id `", metatable.id .. "." .. key, "`")
                    end

                    metatable.__newindex = function(self, key)
                        rt.fatal("In rt.SoundManager.", metatable.id, ": trying to assign key `", key, "`, but this object is immutable")
                    end
                end

                for v in values(t) do
                    make_id_table(v, seen)
                end
            end

            return t
        end

        -- make leaves immutable
        for leaf in values(leaves) do
            setmetatable(leaf, {
                __index = function(self, key)
                    rt.error("In rt.SoundManager.", self.id, ": key `", key, "` does not exist")
                end,

                __newindex = function(self, key, new)
                    rt.fatal("In rt.SoundManager.", self.id, ": trying to assign key `", key, "`, but this object is immutable")
                end
            })
        end

        for key, value in pairs(make_id_table(ids, {})) do
            rt.assert(rt.SoundManager[key] == nil, "In rt.SoundManager.instantiate: sound root folder name `", key, "` is invalid, it conflicts with an existing method of `rt.SoundManager`")
            rt.SoundManager[key] = value
        end
        end -- if false

        self._id_to_entry = {} -- Table<String, String>, indexable like `self._id_to_entry["overworld.foo.effect"]`
        for id, path in pairs(id_to_path) do
            self._id_to_entry[id] = {
                id = id,
                sound_path = path,  -- String
                sound_data = nil, -- love.SoundData
                duration = nil, -- seconds
                handler_id_to_active_sources = {}, -- Table<Number, love.Source>
                handler_id_to_volume_motion = {}, -- Table<Number, rt.SmoothedMotion1D>
                handler_id_to_pitch_motion = {}, -- Table<Number, rt.SmoothedMotion1D>
                handler_id_to_position_motion = {}, -- Table<Number, rt.SmoothedMotion2D>
                inactive_source_to_timestamp = {}, -- Table<love.Source, Number>
                was_processed = false,
                equalizer_entry_rms = 0,
                equalizer_volume = 1
            }
        end
    end
end

--- @brief
function rt.SoundManager:_import_audio(sound_path)
    local _attack = 5 / 60 -- seconds
    local _decay = 5 / 60 -- seconds

    local _envelope = function(sample_i, n_samples, sample_rate)
        -- convert sample index to time in seconds
        local t = sample_i / sample_rate
        local total_duration = n_samples / sample_rate

        -- calculate phase durations
        local attack_samples = _attack * sample_rate
        local decay_samples = _decay * sample_rate

        -- attack
        if sample_i <= attack_samples then
            local normalized_pos = sample_i / attack_samples
            return 0.5 * (1 - math.cos(math.pi * normalized_pos))
        end

        -- decay
        local decay_start = n_samples - decay_samples
        if sample_i >= decay_start then
            local normalized_pos = (sample_i - decay_start) / decay_samples
            return 0.5 * (1 + math.cos(math.pi * normalized_pos))
        end

        -- sustain
        return 1.0
    end

    local success, data_or_error = pcall(love.sound.newSoundData, sound_path)
    if not success then
        rt.critical("In rt.SoundManager.play: when trying to play sound at `", sound_path,  "`: ",  data_or_error)
        return nil
    end

    local data = data_or_error

    local sample_count = data:getSampleCount()
    local sample_rate = data:getSampleRate()
    local channel_count = data:getChannelCount()
    local bit_depth = data:getBitDepth()

    if sample_count == 0 then
        return nil
    end

    local is_mono = channel_count == 1

    local mono_sound_data
    if not is_mono then
        mono_sound_data = love.sound.newSoundData(
            sample_count,
            sample_rate,
            bit_depth,
            1
        )
    else
        mono_sound_data = data
    end

    for i = 0, sample_count - 1 do
        local sample

        -- get sample, convert to mono if necessary
        if not is_mono then
            -- mean of all channels
            local sample_sum = 0
            for channel = 1, channel_count do
                sample_sum = sample_sum + data:getSample(i, channel)
            end
            sample = sample_sum / channel_count
        else
            sample = data:getSample(i, 1)
        end

        -- apply envelope
        local enveloped_sample = sample * _envelope(i, sample_count, sample_rate)

        if bit_depth == 8 then -- uint8_t
            enveloped_sample = math.floor(((enveloped_sample + 1) / 2) * 2^8) / 2^8
            enveloped_sample = math.mix(-1, 1, enveloped_sample)
        elseif bit_depth == 16 then -- int16_t
            enveloped_sample = math.round(enveloped_sample * 2^16) / 2^16
        end

        mono_sound_data:setSample(i, 1, enveloped_sample)
    end

    if not is_mono then
        data:release()
    end

    return mono_sound_data
end

--- @brief
function rt.SoundManager:_process_entry(entry)
    entry.duration = entry.sound_data:getDuration()

    local sample_count = entry.sound_data:getSampleCount()
    local sample_rate = entry.sound_data:getSampleRate()
    local channel_count = entry.sound_data:getChannelCount()
    local duration = entry.sound_data:getDuration()

    if sample_count == 0 then
        entry.equalizer_entry_rms = 0
        entry.was_processed = true
        return
    end

    local total_samples = sample_count * channel_count
    local sum_of_squares = 0.0

    -- calculate RMS from the processed mono audio data
    for i = 0, sample_count - 1 do
        local sample = entry.sound_data:getSample(i, 1)
        sum_of_squares = sum_of_squares + (sample * sample)
    end

    local current_rms = math.sqrt(sum_of_squares / total_samples)
    entry.equalizer_entry_rms = current_rms

    -- update running average RMS using exponential moving average
    if not entry.was_processed then
        local alpha = self._equalizer.equalization_alpha
        if self._equalizer.average_root_mean_square == nil then
            self._equalizer.average_root_mean_square = current_rms
        else
            self._equalizer.average_root_mean_square = alpha * current_rms +
                (1 - alpha) * self._equalizer.average_root_mean_square
        end

        self._equalizer.n_sounds_processed = self._equalizer.n_sounds_processed + 1

        if self._equalizer.target_root_mean_square == nil then
            self._equalizer.target_root_mean_square = current_rms
        end

        entry.was_processed = true
    end

    return true
end

local _sound_id_to_error_thrown = {} -- Set<ID, Boolean>

--- @brief
function rt.SoundManager:_get_entry(scope, id)
    local entry = self._id_to_entry[id]
    if entry == nil then
        rt.critical("In rt.SoundManager.",  scope,  ": no sound with id `", id,  "`")
        return nil
    else
        return entry
    end
end

--- @brief
function rt.SoundManager:_map_coordinates(x, y)
    -- no mapping needed, face/up transform and reference distance automatically scale and flip coords
    return x, y, 0
end

--- @brief
function rt.SoundManager:set_player_position(position_x, position_y)
    if position_x == nil then position_x = 0 end
    if position_y == nil then position_y = 0 end

    meta.assert(position_x, mt.Number, position_y, mt.Number)

    self._listener_x, self._listener_y = position_x, position_y
    local x, y, z = self:_map_coordinates(self._listener_x, self._listener_y)
    love.audio.setPosition(x, y, z + self._z_height)
end

local _config_valid_keys = {} -- Set<String, Boolean>
for key in range(
    "pitch",
    "position_x",
    "position_y",
    "should_loop"
) do
    _config_valid_keys[key] = true
end

--- @brief
function rt.SoundManager:_set_source_position(source, position_x, position_y)
    if position_x ~= nil and position_y ~= nil then
        -- static position in world
        local x, y, z = self:_map_coordinates(position_x, position_y)
        source:setPosition(x, y, z)
        source:setRelative(false)
    else
        -- always 0 distance away from player
        source:setPosition(0, 0, 0)
        source:setRelative(true)
    end
end

--- @brief
--- @return Number handler id
function rt.SoundManager:play(id, config)
    meta.assert(id, mt.String, config, mt.Optional(mt.Table))

    self._current_handler_id = self._current_handler_id + 1
    return self:_play(self._current_handler_id, id, config)
end

--- @brief
function rt.SoundManager:_play(handler_id, id, config)
    meta.assert(handler_id, mt.Number, id, mt.String, config, mt.Optional(mt.Table))

    if config == nil then config = {} end
    local position_specified = config.position_x ~= nil or config.position_y ~= nil

    if config.pitch == nil then config.pitch = 1 end
    if config.position_x == nil then config.position_x = self._listener_x end
    if config.position_y == nil then config.position_y = self._listener_y end
    if config.should_loop == nil then config.should_loop = false end

    for key in keys(config) do
        if _config_valid_keys[key] ~= true then
            rt.critical("In rt.SoundManager.player: unrecognized option `", key,  "`")
        end
    end

    local entry = self:_get_entry("play", id)

    config.handler_id = handler_id
    self._handler_id_to_sound_id[config.handler_id] = id

    if entry == nil then return config.handler_id end

    if entry.sound_data == nil then
        entry.sound_data = self:_import_audio(entry.sound_path)
        if entry.sound_data == nil then return end
    end

    self:_process_entry(entry)

    -- update rms volume on play
    entry.equalizer_volume = self._equalizer.average_root_mean_square / math.max(0.01, entry.equalizer_entry_rms)
    entry.equalizer_volume = math.clamp(entry.equalizer_volume, 0.05, 3)

    -- check if inactive source available
    local source, elapsed = next(entry.inactive_source_to_timestamp)
    if source ~= nil then
        entry.inactive_source_to_timestamp[source] = nil
    else
        source = love.audio.newSource(entry.sound_data)
    end

    entry.handler_id_to_active_sources[config.handler_id] = source
    entry.handler_id_to_volume_motion[config.handler_id] = nil
    entry.handler_id_to_pitch_motion[config.handler_id] = nil

    self:_set_source_position(source, config.position_x, config.position_y)

    source:setPitch(config.pitch)
    source:setRolloff(1)
    source:setAttenuationDistances(
        self._reference_distance,
        self._reference_distance
    )
    source:setVelocity(0, 0, 0)
    source:setVolume(entry.equalizer_volume * self._volume)
    source:setLooping(config.should_loop)

    for effect in values(config.effects) do
        source:setEffect(effect:get_native(), true)
    end

    source:play()

    local current = self._id_to_n_active_sources[id]
    if current == nil then current = 0 end
    self._id_to_n_active_sources[id] = current + 1
    self._active_entries[entry] = true

    return config.handler_id
end

--- @brief
function rt.SoundManager:set_global_volume(value)
    meta.assert(value, mt.Number)
    self._volume = value

    for entry in keys(self._active_entries) do
        for handler_id, source in pairs(entry.handler_id_to_active_sources) do
            if source ~= nil then
                local motion_value = 1
                do
                    local motion = entry.handler_id_to_volume_motion[handler_id]
                    if motion ~= nil then motion_value = motion:get_value() end
                end

                source:setVolume(motion_value * entry.equalizer_volume * self._volume)
            end
        end
    end
end

local _handler_id_to_has_thrown = {}
local _throw_handler_id_not_present = function(scope, id, handler_id)
    if id == nil then id = "nil" end -- sic, use as key
    if handler_id == nil then handler_id = "nil" end

    local entry = _handler_id_to_has_thrown[id]
    if entry == nil then
        entry = {}
        _handler_id_to_has_thrown[id] = entry
    end

    local should_throw = entry[handler_id] ~= true
    entry[handler_id] = true

    if should_throw then
        rt.critical("In rt.SoundManager.", scope, ": sound `", id, "` has no active source with handler id `", handler_id, "`")
    end
end

--- @brief
function rt.SoundManager:set_volume(handler_id, volume, use_smoothing)
    if use_smoothing == nil then use_smoothing = true end
    meta.assert(handler_id, mt.Number, volume, mt.Number, use_smoothing, mt.Boolean)

    local id = self._handler_id_to_sound_id[handler_id]
    if id == nil then
        _throw_handler_id_not_present("set_volume", id, handler_id)
        return
    end

    local entry = self:_get_entry("set_volume", id)
    if entry == nil then return end

    if entry.handler_id_to_active_sources[handler_id] == nil then
        _throw_handler_id_not_present("set_volume", id, handler_id)
    else
        local motion =  entry.handler_id_to_volume_motion[handler_id]
        if motion == nil then
            motion = rt.SmoothedMotion1D(1)
            entry.handler_id_to_volume_motion[handler_id] = motion
        end

        volume = math.clamp(volume, 0, 1)
        motion:set_target_value(volume)
        if use_smoothing == false then
            motion:set_current_value(volume)
        end

        -- applied to source next update
    end
end

--- @brief
function rt.SoundManager:set_pitch(handler_id, pitch, use_smoothing)
    if use_smoothing == nil then use_smoothing = true end
    meta.assert(handler_id, mt.Number, pitch, mt.Number, use_smoothing, mt.Boolean)

    local id = self._handler_id_to_sound_id[handler_id]
    if id == nil then
        _throw_handler_id_not_present("set_pitch", id, handler_id)
        return
    end

    local entry = self:_get_entry("set_pitch", id)
    if entry == nil then return end

    if entry.handler_id_to_active_sources[handler_id] == nil then
        return
    end

    local motion =  entry.handler_id_to_pitch_motion[handler_id]
    if motion == nil then
        motion = rt.SmoothedMotion1D(1)
        entry.handler_id_to_pitch_motion[handler_id] = motion
    end

    motion:set_target_value(pitch)
    if use_smoothing == false then
        motion:set_current_value(pitch)
    end
end

--- @brief
function rt.SoundManager:set_filter(handler_id, t)
    meta.assert(handler_id, mt.Number, t, mt.Number)

    local id = self._handler_id_to_sound_id[handler_id]
    if id == nil then
        _throw_handler_id_not_present("set_filter", id, handler_id)
        return
    end

    local entry = self:_get_entry("set_filter", id)
    if entry == nil then return end

    t = math.clamp(t, 0, 1)

    local source = entry.handler_id_to_active_sources[handler_id]
    if source == nil then return end

    source:setFilter({
        type = "bandpass",
        highgain = t,
        lowgain = 1 - t
    })
end

--- @brief
function rt.SoundManager:remove_filter(handler_id)
    meta.assert(handler_id, mt.Number)

    local id = self._handler_id_to_sound_id[handler_id]
    if id == nil then
        _throw_handler_id_not_present("set_filter", id, handler_id)
        return
    end

    local entry = self:_get_entry("set_filter", id)
    if entry == nil then return end

    local source = entry.handler_id_to_active_sources[handler_id]
    if source == nil then return end

    source:setFilter(nil)
end

--- @brief
function rt.SoundManager:add_effect(handler_id, effect)
    meta.assert(handler_id, mt.Number, effect, rt.SoundEffect)
    self:add_effect_native(handler_id, effect:get_native())
end

--- @brief
function rt.SoundManager:add_effect_native(handler_id, native)
    meta.assert(handler_id, mt.Number, native, mt.String)

    local id = self._handler_id_to_sound_id[handler_id]
    if id == nil then
        _throw_handler_id_not_present("add_effect", id, handler_id)
        return
    end

    local entry = self:_get_entry("add_effect", id)
    if entry == nil then return end

    local source = entry.handler_id_to_active_sources[handler_id]
    if source == nil then return end

    source:setEffect(native, true) -- enable
end

--- @brief
function rt.SoundManager:set_position(handler_id, position_x, position_y, use_smoothing)
    if use_smoothing == nil then use_smoothing = false end
    if position_x == nil then position_x = 0 end
    if position_y == nil then position_y = 0 end
    
    meta.assert(handler_id, mt.Number,
        position_x, mt.Number, 
        position_y, mt.Number, 
        use_smoothing, mt.Boolean
    )

    local id = self._handler_id_to_sound_id[handler_id]
    if id == nil then
        _throw_handler_id_not_present("set_position", id, handler_id)
        return
    end

    local entry = self:_get_entry("set_position", id)
    if entry == nil then return end

    local source = entry.handler_id_to_active_sources[handler_id]
    if source == nil then return end

    local motion =  entry.handler_id_to_position_motion[handler_id]
    if motion == nil then
        motion = rt.SmoothedMotion2D(position_x, position_y)
        entry.handler_id_to_position_motion[handler_id] = motion
    end

    motion:set_target_position(position_x, position_y)
    if use_smoothing == false then
        motion:set_position(position_x, position_y)
    end

    self:_set_source_position(source, position_x, position_y)
end

--- @brief
function rt.SoundManager:remove_effect(handler_id, effect)
    meta.assert(handler_id, mt.Number, effect, rt.SoundEffect)
    self:remove_effect_native(handler_id, effect:get_native())
end

--- @brief
function rt.SoundManager:remove_effect_native(handler_id, native)
    meta.assert(handler_id, mt.Number, effect, mt.String)

    local id = self._handler_id_to_sound_id[handler_id]
    if id == nil then
        _throw_handler_id_not_present("remove_effect", id, handler_id)
        return
    end

    local entry = self:_get_entry("remove_effect", id)
    if entry == nil then return end

    local source = entry.handler_id_to_active_sources[handler_id]
    if source == nil then return end

    source:setEffect(native, false) -- disable
end

--- @brief
function rt.SoundManager:stop(handler_id, fade_out_duration)
    meta.assert(handler_id, mt.Number, fade_out_duration, mt.Optional(mt.Number))

    local id = self._handler_id_to_sound_id[handler_id]
    if id == nil then
        _throw_handler_id_not_present("stop", id, handler_id)
        return
    end

    if fade_out_duration == nil then fade_out_duration = rt.settings.sound_manager.source_stop_decay_duration end

    local entry = self:_get_entry("stop", id)
    if entry == nil then return end

    local to_stop = {}
    local add = function(entry, handler_id)
        table.insert(to_stop, {
            entry = entry,
            handler_id = handler_id,
            elapsed = 0,
            duration = fade_out_duration
        })
    end

    if handler_id == nil then
        for current_id, source in pairs(entry.handler_id_to_active_sources) do
            add(entry, current_id)
        end
    else
        local source = entry.handler_id_to_active_sources[handler_id]
        if source ~= nil then
            add(entry, handler_id)
        end
    end

    for stop_entry in values(to_stop) do
        table.insert(self._stop_entries, stop_entry)
    end
end

--- @brief
function rt.SoundManager:list_active_handler_ids(sound_id)
    meta.assert(sound_id, mt.String)

    local entry = self:_get_entry("list_handler_ids", sound_id)
    local out = {}
    if entry ~= nil then
        for handler_id in keys(entry.handler_id_to_active_sources) do
            table.insert(out, handler_id)
        end
    end
    return out
end


--- @brief
function rt.SoundManager:has_handler_id(handler_id)
    return self._handler_id_to_sound_id[handler_id] ~= nil
end

--- @brief
function rt.SoundManager:_get_state()
    local sound_id_to_active_handlers = {}
    for entry in keys(self._active_entries) do
        local to_fill = sound_id_to_active_handlers[entry.id]
        if to_fill == nil then
            to_fill = {}
            sound_id_to_active_handlers[entry.id] = to_fill
        end

        for handler_id, source in pairs(entry.handler_id_to_active_sources) do
            if source ~= nil then
                table.insert(to_fill, handler_id)
            end
        end
    end

    return sound_id_to_active_handlers
end

-- sound manager is run at very high refresh rate for
-- smooth fading, but deallocation only needs to
-- check rarely, run it at 60 fps
local _elapsed = 0
local _step = 1 / 60

--- @brief
function rt.SoundManager:update(delta)
    meta.assert(delta, mt.Number)

    do -- fade out
        local easing = function(t)
            return rt.InterpolationFunctions.SINUSOID_EASE_OUT(1 - math.clamp(t, 0, 1))
        end

        do -- smoothing
            for entry in keys(self._active_entries) do
                for handler_id, motion in pairs(entry.handler_id_to_pitch_motion) do
                    local source = entry.handler_id_to_active_sources[handler_id]
                    if source ~= nil then
                        source:setPitch(motion:update(delta))
                    end
                end

                for handler_id, motion in pairs(entry.handler_id_to_volume_motion) do
                    local source = entry.handler_id_to_active_sources[handler_id]
                    if source ~= nil then
                        source:setVolume(motion:update(delta) * entry.equalizer_volume * self._volume)
                    end
                end

                for handler_id, motion in pairs(entry.handler_id_to_position_motion) do
                    local source = entry.handler_id_to_active_sources[handler_id]
                    if source ~= nil then
                        self:_set_source_position(source, motion:get_position())
                    end
                end
            end
        end

        do -- stops & volume
            local to_remove = {}
            for i, stop_entry in ipairs(self._stop_entries) do
                -- sinusoid because it is smooth on both ends and actually reaches 0
                local t = easing(stop_entry.elapsed / stop_entry.duration)

                local entry, handler_id = stop_entry.entry, stop_entry.handler_id
                local source = entry.handler_id_to_active_sources[handler_id]
                if source ~= nil then
                    local motion = entry.handler_id_to_volume_motion[handler_id]
                    if motion == nil then
                        source:setVolume(t * entry.equalizer_volume * self._volume)
                    else
                        source:setVolume(t * motion:get_value() * entry.equalizer_volume * self._volume)
                    end
                end

                if stop_entry.elapsed > stop_entry.duration then
                    if source ~= nil then
                        source:stop()
                    end

                    table.insert(to_remove, i)
                end

                stop_entry.elapsed = stop_entry.elapsed + delta
            end

            for i = #to_remove, 1, -1 do
                table.remove(self._stop_entries, to_remove[i])
            end
        end
    end

    _elapsed = _elapsed + delta
    while _elapsed >= _step do
        _elapsed = _elapsed - _step

        do -- mark for deallocation
            for entry in keys(self._active_entries) do
                local to_move = {}
                for handler_id, source in pairs(entry.handler_id_to_active_sources) do
                    if not source:isPlaying() then
                        -- reset
                        self:signal_emit("sound_done", entry.id, handler_id)
                        source:stop()
                        source:setVolume(0)
                        source:setFilter(nil)
                        for effect in values(source:getActiveEffects()) do
                            source:setEffect(effect, false)
                        end
                        table.insert(to_move, handler_id)
                    end
                end

                for handler_id in values(to_move) do
                    local source = entry.handler_id_to_active_sources[handler_id]
                    entry.handler_id_to_active_sources[handler_id] = nil
                    entry.handler_id_to_volume_motion[handler_id] = nil
                    entry.handler_id_to_pitch_motion[handler_id] = nil
                    --self._handler_id_to_sound_id[handler_id] = nil

                    entry.inactive_source_to_timestamp[source] = love.timer.getTime()
                    local current = self._id_to_n_active_sources[entry.id]
                    self._id_to_n_active_sources[entry.id] = current - 1
                end
            end
        end

        do -- deallocate
            local to_make_inactive = {}
            for entry in keys(self._active_entries) do
                local to_remove = {}
                for source, timestamp in pairs(entry.inactive_source_to_timestamp) do
                    if timestamp == -math.huge or love.timer.getTime() - timestamp > rt.settings.sound_manager.source_inactive_lifetime_threshold then
                        table.insert(to_remove, source)
                    end
                end

                for source in values(to_remove) do
                    entry.inactive_source_to_timestamp[source] = nil
                    source:release()
                end

                if entry.sound_data ~= nil
                    and table.sizeof(entry.handler_id_to_active_sources) == 0
                    and table.sizeof(entry.inactive_source_to_timestamp) == 0
                then
                    -- free entry
                    entry.sound_data:release()
                    entry.sound_data = nil
                    -- keep .was_processed and rms

                    table.insert(to_make_inactive, entry)
                end
            end

            for entry in values(to_make_inactive) do
                self._active_entries[entry] = nil
            end
        end
    end
end

--- @brief
function rt.SoundManager:reset()
    for entry in pairs(self._active_entries) do
        for _, source in pairs(entry.handler_id_to_active_sources) do
            source:stop()
            source:release()
        end
        for source in pairs(entry.inactive_source_to_timestamp) do
            source:release()
        end
        if entry.sound_data then
            entry.sound_data:release()
            entry.sound_data = nil
        end

        entry.handler_id_to_active_sources = {}
        entry.handler_id_to_volume_motion = {}
        entry.handler_id_to_pitch_motion = {}
        entry.inactive_source_to_timestamp = {}
        entry.was_processed = false
    end

    self._active_entries = {}
    self._stop_entries = {}
    self._id_to_n_active_sources = {}
    self._handler_id_to_sound_id = {}
    self._current_handler_id = 1
    self._equalizer.average_root_mean_square = nil
    self._equalizer.n_sounds_processed = 0
end
