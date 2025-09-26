require "common.filesystem"
require "table.clear"

rt.settings.sound_manager_instance = {
    config_directory = "assets/sounds",
    envelope_attack = 5 / 60,
    envelope_decay = 5 / 60,
    default_equalization_alpha = 0.1,
    source_inactive_lifetime_threshold = 60, -- seconds
    enable_volume_equalization = true,

    reference_hearing_distance = rt.settings.native_resolution / 600,
    maximum_hearing_distance = rt.settings.native_resolution,
    distance_model = "inverseclamped"
}

--- @class rt.SoundManagerInstance
rt.SoundManagerInstance = meta.class("SoundManagerInstance")

local _is_config_file = function(path)
    return string.match(path, "%.lua$") ~= nil
end

local _is_sound_file = function(filename)
    local extension = string.match(filename, "%.([^%.]+)$") -- extract everything after . before end
    if extension then
        extension = string.lower(extension)
        return extension == "mp3"
            or extension == "wav"
            or extension == "ogg"
            or extension == "oga"
            or extension == "ogv"
            or extension == "flac"
    end
    return false
end

local _settings = rt.settings.sound_manager_instance

--- @brief
function rt.SoundManagerInstance:instantiate()
    self._id_to_entry = {}
    self._current_handler_id = 1

    self._entry_id_to_to_add = {} -- Set<String> which sources to add this update cycle
    self._active_entries = {} -- Set<Entry>

    self._listener_x = 0
    self._listener_y = 0
    self._velocity_x = 0
    self._velocity_y = 0

    -- audio config for side scroller
    love.audio.setPosition(0, 0, 0)
    love.audio.setVelocity(0, 0, 0)
    love.audio.setDistanceModel(_settings.distance_model)
    love.audio.setOrientation(
        0, 0, -1,
        0, 1, 0
    )

    -- volume equalization
    self._volume = rt.GameState:get_sound_effect_level()
    self._equalizer = {
        average_root_mean_square = nil,
        target_root_mean_square = nil,
        n_sounds_processed = 0,
        equalization_alpha = _settings.default_equalization_alpha
    }

    local get_entry = function(id)
        local entry = self._id_to_entry[id]
        if entry == nil then
            entry = {
                id = id,
                config_path = nil, -- String
                sound_path = nil,  -- String
                sound_data = nil, -- love.SoundData
                duration = nil, -- seconds
                handler_id_to_active_sources = {}, -- Table<Number, love.Source>
                inactive_source_to_elapsed = {}, -- Table<love.Source, Number>
                was_processed = false,
                equalizer_entry_rms = 0,
                equalizer_volume = 1
            }
            self._id_to_entry[id] = entry
        end
        return entry
    end

    bd.apply(rt.settings.sound_manager_instance.config_directory, function(filepath, filename)
        if _is_sound_file(filename) then
            get_entry(bd.get_file_name(filename, false)).sound_path = filepath
        elseif _is_config_file(filename) then
            get_entry(bd.get_file_name(filename, false)).config_path = filepath
        else
            -- noop
        end
    end)

    -- check for unmatched configs
    local to_remove = {}
    for id, entry in pairs(self._id_to_entry) do
        if entry.config_path ~= nil and entry.sound_path == nil then
            rt.critical("In rt.SoundManagerInstance: found config file at `" .. entry.config_path .. "` but no matching sound file with that id `" .. bd.get_file_name(entry.config_path, false) .. "`")
            table.insert(to_remove, id)
        end
    end

    for id in values(to_remove) do
        self._id_to_entry[id] = nil
    end
end

local _attack = rt.settings.sound_manager_instance.envelope_attack -- seconds
local _decay = rt.settings.sound_manager_instance.envelope_decay -- seconds
local _sigma = 0.3
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
        local x = normalized_pos * 3 - 3
        return math.exp(-(x * x) / (2 * _sigma * _sigma))
    end

    -- decay
    local decay_start = n_samples - decay_samples
    if sample_i >= decay_start then
        local normalized_pos = (sample_i - decay_start) / decay_samples
        local x = normalized_pos * 3
        return math.exp(-(x * x) / (2 * _sigma * _sigma))
    end

    -- sustain
    return 1.0
end


--- @brief
local function _to_mono(sound_data)
    if not sound_data or sound_data:getChannelCount() == 1 then
        return sound_data
    end

    local sample_count = sound_data:getSampleCount()
    local channel_count = sound_data:getChannelCount()

    local mono_sound_data = love.sound.newSoundData(
        sample_count,
        sound_data:getSampleRate(),
        sound_data:getBitDepth(),
        1
    )

    for i = 0, sample_count - 1 do
        -- mean of all channels
        local sample_sum = 0
        for channel = 1, channel_count do
            sample_sum = sample_sum + sound_data:getSample(i, channel)
        end
        mono_sound_data:setSample(i, 1, sample_sum / channel_count)
    end

    return mono_sound_data
end

--- @brief
function rt.SoundManagerInstance:_process_entry(entry)
    assert(entry.sound_data ~= nil)

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

    local is_mono = entry.sound_data:getChannelCount() == 1

    local mono_sound_data
    if not is_mono then
        mono_sound_data = love.sound.newSoundData(
            sample_count,
            entry.sound_data:getSampleRate(),
            entry.sound_data:getBitDepth(),
            1
        )
    end

    for i = 0, sample_count - 1 do
        local sample

        -- get sample, convert to mono if necessary
        if not is_mono then
            -- mean of all channels
            local sample_sum = 0
            for channel = 1, channel_count do
                sample_sum = sample_sum + entry.sound_data:getSample(i, channel)
            end
            sample = sample_sum / channel_count
            mono_sound_data:setSample(i, 1, sample)
        else
            sample = entry.sound_data:getSample(i, 1)
        end

        -- apply envelope
        local enveloped_sample = sample * _envelope(i, sample_count, sample_rate)
        entry.sound_data:setSample(i, 1, enveloped_sample)

        -- update sum
        sum_of_squares = sum_of_squares + (enveloped_sample * enveloped_sample)
    end

    if not is_mono then
        local old = entry.sound_data
        entry.sound_data = mono_sound_data
        old:release()
        is_mono = true
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

    entry.duration = entry.sound_data:getDuration()
end

--- @brief
function rt.SoundManagerInstance:_get_entry(id, scope)
    local entry = self._id_to_entry[id]
    if entry == nil then
        rt.error("In rt.SoundManagerInstance." .. scope .. ": no sound with id `" .. id .. "`")
        return nil
    else
        return entry
    end
end

-- game xy to OpenAL xyz
local _map_coordinates = function(x, y)
    return x, -y, 0
end

--- @brief
function rt.SoundManagerInstance:set_player_position(position_x, position_y)
    self._listener_x, self._listener_y = position_x, position_y
    love.audio.setPosition(_map_coordinates(self._listener_x, self._listener_y))
end

--- @brief
function rt.SoundManagerInstance:set_player_velocity(velocity_x, velocity_y)
    self._velocity_x, self._velocity_y = velocity_x, velocity_y
    love.audio.setVelocity(_map_coordinates(velocity_x, velocity_y))
end

local _config_valid_keys = {}
for key in range(
    "pitch",
    "position_x",
    "position_y"
) do
    _config_valid_keys[key] = true
end

--- @brief
--- @return Number handler id
function rt.SoundManagerInstance:play(id, config)
    if config == nil then config = {} end
    if config.pitch == nil then config.pitch = 1 end
    if config.position_x == nil then config.position_x = self._listener_x end
    if config.position_y == nil then config.position_y = self._listener_y end

    for key in keys(config) do
        if not _config_valid_keys[key] == true then
            rt.critical("In rt.SoundManagerInstance.player: unrecognized option `" .. key .. "`")
        end
    end

    local entry = self:_get_entry(id, "play")
    local handler_id = self._current_handler_id
    self._current_handler_id = self._current_handler_id + 1

    if entry.sound_data == nil then
        local success, data_or_error = pcall(love.sound.newSoundData, entry.sound_path)
        if not success then
            rt.critical("In rt.SoundManagerInstance.play: when trying to play sound at `" .. entry.sound_path .. "`: " .. data_or_error)
            return
        end

        entry.sound_data = data_or_error
        self:_process_entry(entry)
    end

    config.handler_id = handler_id
    self._entry_id_to_to_add[id] = config
    -- being a`Set` prevents multiple source of the same ID per frame
    -- cleared at the end of update cycle

    return handler_id
end

--- @brief
function rt.SoundManagerInstance:stop(id, handler_id)
    local entry = self:_get_entry(id, "stop")
    local source = entry.handler_id_to_active_sources[id]
    if source ~= nil then
        source:stop()
    end
end

--- @brief
function rt.SoundManagerInstance:update(delta)
    do -- mark inactive
        local to_mark_inactive = {}
        for entry in keys(self._active_entries) do
            local to_move = {}
            for handler_id, source in pairs(entry.handler_id_to_active_sources) do
                if source:tell("samples") >= entry.sound_data:getSampleCount() then
                    source:stop()
                    table.insert(to_move, handler_id)
                end
            end

            for handler_id in values(to_move) do
                local source = entry.handler_id_to_active_sources[handler_id]
                entry.handler_id_to_active_sources[handler_id] = nil
                entry.inactive_source_to_elapsed[source] = 0 -- elapsed

                if table.sizeof(entry.handler_id_to_active_sources) == 0 then
                    table.insert(to_mark_inactive, entry)
                end
            end
        end
    end

    do -- add active
        local to_mark_active = {}
        for entry_id, config in pairs(self._entry_id_to_to_add) do
            local entry = self._id_to_entry[entry_id]

            -- update rms volume on play
            entry.equalizer_volume = self._equalizer.average_root_mean_square / entry.equalizer_entry_rms
            entry.equalizer_volume = math.clamp(entry.equalizer_volume, 0.05, 3)

            -- check if inactive source available
            local old_handler_id, source = next(entry.inactive_source_to_elapsed)
            if source ~= nil then
                entry.inactive_source_to_elapsed[old_handler_id] = nil
            else
                source = love.audio.newSource(entry.sound_data)
            end

            entry.handler_id_to_active_sources[config.handler_id] = source
            source:setPosition(_map_coordinates(config.position_x, config.position_y))
            source:setRelative(true)
            source:setPitch(config.pitch)
            source:setAttenuationDistances(
                _settings.reference_hearing_distance,
                _settings.maximum_hearing_distance
            )
            source:setRolloff(1)
            source:setVelocity(_map_coordinates(0, 0))
            source:setVolume(entry.equalizer_volume * self._volume)
            source:play()

            table.insert(to_mark_active, entry)
        end

        for entry in values(to_mark_active) do
            self._active_entries[entry] = true
        end

        table.clear(self._entry_id_to_to_add)
    end

    do -- deallocate
        for entry in keys(self._active_entries) do
            local to_remove = {}
            for source, elapsed in pairs(entry.inactive_source_to_elapsed) do
                elapsed = elapsed + delta
                if elapsed > rt.settings.sound_manager_instance.source_inactive_lifetime_threshold then
                    table.insert(to_remove)
                end
            end

            for source in values(to_remove) do
                entry.inactive_source_to_elapsed[source] = nil
                source:release()
            end

            --[[
            if table.sizeof(entry.handler_id_to_active_sources) == 0
                and table.sizeof(entry.inactive_source_to_elapsed) == 0
            then
                -- free entry
                entry.sound_data:release()
                entry.sound_data = nil
                -- keep .was_processed and rms
            end
            ]]--
        end
    end
end
