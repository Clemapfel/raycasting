require "common.filesystem"
require "table.clear"

rt.settings.sound_manager = {
    config_directory = "assets/sounds",
    envelope_attack = 5 / 60,
    envelope_decay = 5 / 60,
    default_equalization_alpha = 0.1,
    source_inactive_lifetime_threshold = 60, -- seconds
    enable_volume_equalization = true
}

--- @class rt.SoundManager
rt.SoundManager = meta.class("SoundManager")

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

--- @brief
function rt.SoundManager:instantiate()
    self._id_to_entry = {}
    self._current_handler_id = 1

    self._entry_id_to_handler_id_to_add = {} -- Set<String> which sources to add this update cycle
    self._active_entries = {} -- Set<Entry>

    -- volume equalization
    self._equalizer = {
        average_root_mean_square = nil,
        target_root_mean_square = nil,
        n_sounds_processed = 0,
        equalization_alpha = rt.settings.sound_manager.default_equalization_alpha
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

    bd.apply(rt.settings.sound_manager.config_directory, function(filepath, filename)
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
            rt.critical("In rt.SoundManager: found config file at `" .. entry.config_path .. "` but no matching sound file with that id `" .. bd.get_file_name(entry.config_path, false) .. "`")
            table.insert(to_remove, id)
        end
    end

    for id in values(to_remove) do
        self._id_to_entry[id] = nil
    end
end

local _attack = rt.settings.sound_manager.envelope_attack -- seconds
local _decay = rt.settings.sound_manager.envelope_decay -- seconds
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
function rt.SoundManager:_process_entry(entry)
    if entry.sound_data == nil or entry.was_processed == true then
        return
    end

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

    -- apply envelope to sound data and compute root mean square (RMS) for this entry using the modified samples
    local before = love.timer.getTime()
    for i = 0, sample_count - 1 do
        for channel = 1, channel_count do
            local original_sample = entry.sound_data:getSample(i, channel)
            local enveloped_sample = original_sample * _envelope(i, sample_count, sample_rate)
            entry.sound_data:setSample(i, channel, enveloped_sample)
            sum_of_squares = sum_of_squares + (enveloped_sample * enveloped_sample)
        end
    end

    local current_rms = math.sqrt(sum_of_squares / total_samples)
    entry.equalizer_entry_rms = current_rms

    -- update running average RMS using exponential moving average
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

--- @brief
function rt.SoundManager:_get_entry(id, scope)
    local entry = self._id_to_entry[id]
    if entry == nil then
        rt.error("In rt.SoundManager." .. scope .. ": no sound with id `" .. id .. "`")
        return nil
    else
        return entry
    end
end

--- @brief
function rt.SoundManager:play(id)
    local entry = self:_get_entry(id, "play")
    local handler_id = self._current_handler_id
    self._current_handler_id = self._current_handler_id + 1

    if entry.sound_data == nil then
        local success, data_or_error = pcall(love.sound.newSoundData, entry.sound_path)
        if not success then
            rt.critical("In rt.SoundManager.play: when trying to play sound at `" .. entry.sound_path .. "`: " .. data_or_error)
            return
        end

        entry.sound_data = data_or_error
        entry.duration = entry.sound_data:getDuration()

        if entry.was_processed == false then
            self:_process_entry(entry)
        end
    end

    self._entry_id_to_handler_id_to_add[id] = handler_id
    -- `Set` prevents multiple source of the same ID per frame
    --  cleared at the end of update cycle

    return handler_id
end

--- @brief
function rt.SoundManager:stop(id, handler_id)
    local entry = self:_get_entry(id, "stop")
    local source = entry.handler_id_to_active_sources[id]
    if source ~= nil then
        source:stop()
    end
end

--- @brief
function rt.SoundManager:update(delta)

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
        for entry_id, handler_id in pairs(self._entry_id_to_handler_id_to_add) do
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
                source:setVolume(entry.equalizer_volume)
                source:play()
            end

            entry.handler_id_to_active_sources[handler_id] = source
            table.insert(to_mark_active, entry)
        end

        for entry in values(to_mark_active) do
            self._active_entries[entry] = true
        end

        table.clear(self._entry_id_to_handler_id_to_add)
    end

    do -- deallocate
        for entry in keys(self._active_entries) do
            local to_remove = {}
            for source, elapsed in pairs(entry.inactive_source_to_elapsed) do
                elapsed = elapsed + delta
                if elapsed > rt.settings.sound_manager.source_inactive_lifetime_threshold then
                    table.insert(to_remove)
                end
            end

            for source in values(to_remove) do
                entry.inactive_source_to_elapsed[source] = nil
                source:release()
            end

            if table.sizeof(entry.handler_id_to_active_sources) == 0
                and table.sizeof(entry.inactive_source_to_elapsed) == 0
            then
                -- free entry
                entry.sound_data:release()
                entry.sound_data = nil
                -- keep .was_processed and rms
            end
        end
    end
end

rt.SoundManager = rt.SoundManager() -- singleton instance