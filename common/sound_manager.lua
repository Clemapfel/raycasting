require "common.sound_source"
require "common.filesystem"
require "table.clear"
require "common.sound_ids"

rt.settings.sound_manager = {
    config_directory = "assets/sounds",
    default_equalization_alpha = 0.1,
    source_inactive_lifetime_threshold = 30, -- seconds
    enable_volume_equalization = true,
    source_stop_decay_duration = 20 / 60, -- seconds

    reference_hearing_distance = 50,
    maximum_hearing_distance = 600,
    distance_model = "inverseclamped",

    throw_id_error_only_once = false
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

local _settings = rt.settings.sound_manager

--- @brief
function rt.SoundManager:instantiate()
    self._id_to_entry = {}
    self._current_handler_id = 1

    self._id_to_n_active_sources = {} -- Table<String, Number>
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
                inactive_source_to_timestamp = {}, -- Table<love.Source, Number>
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

    self._stop_entries = {}

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

local _import_audio = require "common.sound_manager_import_audio"

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
function rt.SoundManager:_get_entry(id, scope)
    local entry = self._id_to_entry[id]
    if entry == nil then
        local should_throw = true

        if rt.settings.sound_manager.throw_id_error_only_once == true then
            if _sound_id_to_error_thrown[id] == true then should_throw = false end
            _sound_id_to_error_thrown[id] = true
        end

        if should_throw then
            rt.critical("In rt.SoundManager." .. scope .. ": no sound with id `" .. id .. "`")
        end

        return nil
    else
        return entry
    end
end

local preallocate_message_types = {}
local preallocate_threads = {}
local preallocate_worker_to_main

for message in range(
    "load",
    "load_success",
    "load_failure"
) do
    preallocate_message_types[message] = message
end

--- @brief preallocate sound data for entries
function rt.SoundManager:preallocate(id, ...)
    local ids
    if meta.is_table(id) then
        ids = id
    else
        ids = { id, ... }
    end

    -- use threading for preallocation, loading sound data and processing is "embarassingly parallel"
    local n_workers = math.ceil(love.system.getProcessorCount() / 2)
    if n_workers > 1 and #ids > 16 then
        if preallocate_worker_to_main == nil then
            preallocate_worker_to_main = love.thread.newChannel()
        end

        -- spin up threads
        while #preallocate_threads < n_workers do
            local entry = {
                thread = love.thread.newThread("common/sound_manager_preallocate_worker.lua"),
                main_to_worker = love.thread.newChannel()
            }

            table.insert(preallocate_threads, entry)
            entry.thread:start(
                entry.main_to_worker,
                preallocate_worker_to_main,
                preallocate_message_types
            )
        end

        -- round robin
        local thread_i = 1
        for entry_id in values(ids) do
            local entry = self:_get_entry(entry_id, "preallocate")
            local current_thread_i = math.wrap(thread_i, #preallocate_threads)
            local thread_entry = preallocate_threads[current_thread_i]
            thread_entry.main_to_worker:push({
                type = preallocate_message_types.load,
                id = entry_id,
                path = entry.sound_path
            })

            thread_i = thread_i + 1
        end

        -- wait for all threads to finish
        local n_messages_received = 0
        while n_messages_received < #ids do
            local message = preallocate_worker_to_main:demand()
            if message.type == preallocate_message_types.load_success then
                local entry = self._id_to_entry[message.id]
                entry.sound_data = message.data
                self:_process_entry(entry)
            elseif message.type == preallocate_message_types.load_failure then
                rt.critical("In rt.SoundManager.preallocate: " .. message.error)
            else
                rt.error("In rt.SoundManager:preallocate: unhandled main-side message `" .. tostring(message.type) .. "`")
            end

            n_messages_received = n_messages_received + 1
        end
    else
        for entry_id in values(ids) do
            local entry = self:_get_entry(entry_id, "preallocate")
            if entry.sound_data == nil then
                entry.sound_data = _import_audio(entry.sound_path)
                if entry.sound_data == nil then return false end
            end
            self:_process_entry(entry)
        end
    end
end

--- @brief
function rt.SoundManager:deallocate()
    -- mark all for deallocation in next update
    for entry in keys(self._active_entries) do
        for source in keys(entry.inactive_source_to_timestamp) do
            entry.inactive_source_to_timestamp[source] = -math.huge
        end
    end
end

-- game xy to OpenAL xyz
local _map_coordinates = function(x, y)
    return x, -y, 0
end

--- @brief
function rt.SoundManager:set_player_position(position_x, position_y)
    self._listener_x, self._listener_y = position_x, position_y
    love.audio.setPosition(_map_coordinates(self._listener_x, self._listener_y))
end

--- @brief
function rt.SoundManager:set_player_velocity(velocity_x, velocity_y)
    self._velocity_x, self._velocity_y = velocity_x, velocity_y
    love.audio.setVelocity(_map_coordinates(velocity_x, velocity_y))
end

local _config_valid_keys = {} -- Set<String, Boolean>
for key in range(
    "pitch",
    "position_x",
    "position_y",
    "effects",
    "should_loop"
) do
    _config_valid_keys[key] = true
end

local _handler_id_to_source_wrapper = meta.make_weak({})

--- @brief
--- @return Number handler id
function rt.SoundManager:play(id, config)
    if id == nil then return end -- rt.SoundIDs defaults to nil if id is missing

    if config == nil then config = {} end
    if config.pitch == nil then config.pitch = 1 end
    if config.position_x == nil then config.position_x = self._listener_x end
    if config.position_y == nil then config.position_y = self._listener_y end
    if config.should_loop == nil then config.should_loop = false end
    if config.effects == nil then config.effects = {} end

    for key in keys(config) do
        if _config_valid_keys[key] ~= true then
            rt.critical("In rt.SoundManager.player: unrecognized option `" .. key .. "`")
        end
    end

    local entry = self:_get_entry(id, "play")
    if entry == nil then return end

    config.handler_id = self._current_handler_id
    self._current_handler_id = self._current_handler_id + 1

    if entry.sound_data == nil then
        entry.sound_data = _import_audio(entry.sound_path)
        if entry.sound_data == nil then return end
    end

    self:_process_entry(entry)

    -- update rms volume on play
    entry.equalizer_volume = self._equalizer.average_root_mean_square / entry.equalizer_entry_rms
    entry.equalizer_volume = math.clamp(entry.equalizer_volume, 0.05, 3)

    -- check if inactive source available
    local source, elapsed = next(entry.inactive_source_to_timestamp)
    if source ~= nil then
        entry.inactive_source_to_timestamp[source] = nil
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
    source:setLooping(config.should_loop)

    for effect in values(config.effects) do
        source:setEffect(effect:get_native(), true)
    end

    source:play()

    local current = self._id_to_n_active_sources[id]
    if current == nil then current = 0 end
    self._id_to_n_active_sources[id] = current + 1

    self._active_entries[entry] = true

    local wrapper = rt.SoundSource(config.id, source)
    _handler_id_to_source_wrapper[config.handler_id] = wrapper
    return wrapper
end

--- @brief
function rt.SoundManager:stop(id, handler_id)
    if handler_id == nil then
        meta.assert(id, "String")
    else
        meta.assert(id, "String", handler_id, "Number")
    end

    local entry = self:_get_entry(id, "play")

    local to_stop = {}
    local add = function(entry, handler_id)
        assert(entry.handler_id_to_active_sources[handler_id] ~= nil)
        table.insert(to_stop, {
            entry = entry,
            handler_id = handler_id,
            elapsed = 0
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

-- sound manager is run at very high refresh rate for
-- smooth fading, but deallocation only need to check rarely
local _elapsed = 0
local _step = 1 / 60

--- @brief
function rt.SoundManager:update(delta)
    do -- fade out
        local duration = rt.settings.sound_manager.source_stop_decay_duration
        local to_remove = {}
        for i, stop_entry in ipairs(self._stop_entries) do
            -- sinusoid because it is smooth on both ends and actually reaches 0
            local t = rt.InterpolationFunctions.SINUSOID_EASE_OUT(1 - stop_entry.elapsed / duration)

            local source = stop_entry.entry.handler_id_to_active_sources[stop_entry.handler_id]
            if source ~= nil then source:setVolume(t) end
            if stop_entry.elapsed > duration then
                if source ~= nil then source:stop() end
                table.insert(to_remove, i)
            end

            stop_entry.elapsed = stop_entry.elapsed + delta
        end

        for i = #to_remove, 1, -1 do
            table.remove(self._stop_entries, to_remove[i])
        end
    end

    _elapsed = _elapsed + delta
    while _elapsed >= _step do
        _elapsed = _elapsed - _step

        do -- mark inactive
            local to_mark_inactive = {}
            for entry in keys(self._active_entries) do
                local to_move = {}
                for handler_id, source in pairs(entry.handler_id_to_active_sources) do
                    if not source:isPlaying() then
                        -- reset
                        source:stop()
                        source:setVolume(0)
                        source:setFilter()
                        for effect in values(source:getActiveEffects()) do
                            source:setEffect(effect, false)
                        end
                        table.insert(to_move, handler_id)
                    end
                end

                for handler_id in values(to_move) do
                    local source = entry.handler_id_to_active_sources[handler_id]
                    entry.handler_id_to_active_sources[handler_id] = nil
                    entry.inactive_source_to_timestamp[source] = love.timer.getTime()

                    local current = self._id_to_n_active_sources[entry.id]
                    assert(current ~= nil)
                    self._id_to_n_active_sources[entry.id] = current - 1

                    if table.sizeof(entry.handler_id_to_active_sources) == 0 then
                        table.insert(to_mark_inactive, entry)
                    end

                    -- disable wrapper
                    local wrapper = _handler_id_to_source_wrapper[handler_id]
                    wrapper._native = nil
                    _handler_id_to_source_wrapper[handler_id] = nil
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

rt.SoundManager = rt.SoundManager() -- singleton instance
