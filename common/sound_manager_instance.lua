require "love.audio"
require "love.sound"
require "love.timer"

require "include"
require "common.filesystem"
require "common.sound_effect"
require "common.envelope"
require "common.envelope_asr"
require "common.smoothed_motion_1d"
require "common.smoothed_motion_2d"

rt.settings.sound_manager = {
    assets_directory = "assets/sounds",
    update_step = 1 / 240, -- seconds

    import_attack = 5 / 60,
    import_release = 8 / 60,
    max_import_attack_fraction = 0.01,
    max_import_release_fraction = 0.01,

    max_valid_source = 64
}

--- @class rt.SoundManager
rt.SoundManager = meta.class("SoundManager")
meta.add_signals(rt.SoundManager,
    "sound_done" -- (rt.SoundManager, sound_id, handler_id) -> nil
)

local _active_sources = 0

--- @brief
function rt.SoundManager:instantiate()
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

    do -- generate resource entries
        local prefix = bd.normalize_path(rt.settings.sound_manager.assets_directory)
        if string.last(prefix) ~= "/" then prefix = prefix .. "/" end
        local id_to_path = bd.generate_resource_ids(prefix, bd.is_sound_file)

        self._id_to_entry = {} -- Table<String, String>, indexable like `self._id_to_entry["overworld.foo.effect"]`
        for id, path in pairs(id_to_path) do
            self._id_to_entry[id] = {
                id = id,
                sound_path = path,  -- String
                sound_data = nil -- love.SoundData
            }
        end
    end

    self._volume = 1

    -- active playback entries
    self._handler_id = 0
    self._handler_id_to_entry = {} -- handler id to active entry
end

--- @brief
function rt.SoundManager:_load_data(sound_path)
    local success, data_or_error = pcall(love.sound.newSoundData, sound_path)
    if not success then
        rt.critical("In rt.SoundManager.play: when trying to play sound at `", sound_path,  "`: ",  data_or_error)
        return nil
    end

    local data = data_or_error

    local n_samples = data:getSampleCount()
    local sample_rate = data:getSampleRate()
    local n_channels = data:getChannelCount()
    local bit_depth = data:getBitDepth()

    local duration = data:getDuration()
    local settings = rt.settings.sound_manager
    local attack = math.min(settings.import_attack, settings.max_import_attack_fraction * duration)
    local release = math.min(settings.import_release, settings.max_import_release_fraction * duration)
    local sustain = duration - math.min(attack + release, duration)

    local envelope = rt.Envelope(
        attack, sustain, release,
        rt.EnvelopeCurve.WELCH,
        rt.EnvelopeCurve.WELCH
    )

    if n_samples == 0 then
        return nil
    end

    -- apply envelope to all channels
    for sample_i = 1, n_samples, n_channels do
        local elapsed = sample_i / n_channels / sample_rate -- position to seconds
        local t = envelope:at(elapsed)
        for offset = 0, n_channels - 1 do
            data:setSample(sample_i + offset - 1, t * data:getSample(sample_i + offset - 1))
        end
    end

    return data
end

--- @brief
function rt.SoundManager:_set_source_position(source, position_x, position_y)
    if position_x == nil and position_y == nil then
        -- always 0 distance away from player
        source:setPosition(0, 0, 0)
        source:setRelative(true)
        return 0, 0
    else
        -- static position in world
        local x, y = position_x or self._listener_x,
            position_y or self._listener_y

        source:setPosition(x, y, 0)
        source:setRelative(false)
        return x, y
    end
end

--- @brief
function rt.SoundManager:_sync_sources(origin, ...)
    for i = 1, select("#", ...) do
        local source = select(i, ...)
        source:setVolume(origin:getVolume())
        source:setPitch(origin:getPitch())
        source:setLooping(origin:isLooping())

        source:setPosition(origin:getPosition())
        source:setVelocity(origin:getVelocity())
        source:setRelative(origin:isRelative())

        source:setRolloff(origin:getRolloff())
        source:setAttenuationDistances(origin:getAttenuationDistances())
    end
end

local _config_default = {
    pitch = 1,
    position_x = nil, -- relative
    position_y = nil,
    should_loop = false,
    loop_overlap = 0, -- seconds
    attack = 0,
    sustain = nil, -- seconds
    release = 0,
    effects = {}
}

local _config_keys = {}
for x in range(
    "pitch",
    "position_x",
    "position_y",
    "should_loop",
    "loop_overlap",
    "attack",
    "sustain",
    "release",
    "effects"
) do
    _config_keys[x] = true
end

--- @brief
function rt.SoundManager:play(id, config)
    local handler_id = self._handler_id
    self._handler_id = self._handler_id + 1
    self:_play_internal(id, config, handler_id)
end

--- @brief
function rt.SoundManager:_play_internal(id, config, handler_id)
    meta.assert(id, mt.String, config, mt.Optional(mt.Table))

    local resource_entry = self._id_to_entry[id]
    if resource_entry == nil then
        rt.error("In rt.SoundManager.play: no sound with id `", id, "`")
        return nil
    end

    if config == nil then config = {} end

    for key, value in pairs(_config_default) do
        if config[key] == nil then
            config[key] = value
        end
    end

    for key, value in pairs(config) do
        if _config_keys[key] == nil then
            rt.critical("In rt.SoundManager.play: invalid config key `", key, "`, it will be ignored.")
        end
    end

    local failed = false
    local _verify = function(key, expected, is_optional)
        if is_optional and config[key] == nil then return end
        local got = meta.typeof(config[key])
        if got ~= expected then
            rt.error("In rt.SoundManager.play: invalid type for config key `", key, "`: expected `", expected, "`, got `", got, "`")
            failed = true
        end
    end

    for i, effect in ipairs(config.effects) do
        if not meta.isa(effect, rt.SoundEffect) then
            rt.error("In rt.SoundManager.play: effect at position `", i, "`: expected `rt.SoundEffect`, got `", meta.typeof(effect), "`")
        end
    end

    _verify("pitch", mt.Number, false)
    _verify("position_x", mt.Number, true)
    _verify("position_y", mt.Number, true)
    _verify("should_loop", mt.Boolean, true)
    _verify("loop_overlap", mt.Number, false)
    _verify("attack", mt.Number, false)
    _verify("sustain", mt.Number, true)
    _verify("release", mt.Number, false)
    _verify("effects", mt.Table, false)
    if failed then return nil end

    local error_prefix = string.paste("In rt.SoundManager.play: config for sound `", id, "`:")
    if (config.loop_overlap < 0 or config.loop_overlap > 1) then
        rt.critical(error_prefix, "loop_overlap `", config.loop_overlap, "` is outside [0, 1]")
        config.loop_overlap = math.clamp(config.loop_overlap, 0, 1)
    end

    if config.loop_overlap > 0 and config.should_loop == false then
        rt.critical(error_prefix, "`loop_overlap` is set, but `should_loop` is false")
    end

    if config.pitch <= 0 then
        rt.critical(error_prefix, "pitch `", config.pitch, "` is outside (0, 1]")
        config.pitch = 1
    end

    if config.attack < 0 then
        rt.critical(error_prefix, "attack `", config.attack, "` is negative")
        config.attack = 0
    end

    if config.release < 0 then
        rt.critical(error_prefix, "release `", config.sustain, "` is negative")
        config.release = 0
    end

    if resource_entry.sound_data == nil then
        resource_entry.sound_data = self:_load_data(resource_entry.sound_path)
    end

    local entry = {
        id = handler_id,
        resource_entry = resource_entry,

        source = love.audio.newSource(resource_entry.sound_data),
        duration = resource_entry.sound_data:getDuration(),
        elapsed = 0,

        envelope = nil, -- rt.Envelope
        position_motion = nil, -- Optional<rt.SmoothedMotion2D>,
        volume_motion = nil, -- rt.SmoothedMotion1D
        is_stopping = false,

        swap_source = nil, -- love.Source
        swap_period = nil,  -- seconds
        swap_envelope = nil -- rt.Envelope
    }

    if entry.source ~= nil then
        _active_sources = _active_sources + 1
    else
        -- out of OpenAL sources
        rt.critical("In rt.SoundManager: number of active sources reached maximum of `", _active_sources, "`. No more sources can be allocated")
        return nil
    end

    -- position
    entry.source:setRolloff(1)
    entry.source:setAttenuationDistances(
        self._reference_distance,
        self._reference_distance
    )
    entry.source:setVelocity(0, 0, 0)
    entry.position_motion = rt.SmoothedMotion2D(
        self:_set_source_position(entry.source, config.position_x, config.position_y)
    )

    -- loop
    entry.source:setLooping(config.should_loop)

    -- volume
    entry.source:setVolume(0) -- set next update
    entry.volume_motion = rt.SmoothedMotion1D(1)

    local max_sustain = entry.duration - (config.attack + config.release)
    if config.sustain == nil then
        config.sustain = max_sustain
    else
        config.sustain = math.min(config.sustain, max_sustain)
    end

    if config.sustain < 0 then
        rt.critical(error_prefix, "sustain `", config.release, "` is negative")
        config.sustain = entry.duration - (config.attack + config.release)
    end

    if not config.should_loop and (config.attack + config.sustain + config.release > entry.duration) then
        rt.warning(error_prefix, "envelope config duration exceeds audio length")
    end

    if config.should_loop then
        entry.envelope = rt.EnvelopeASR(
            config.attack,
            config.release,
            rt.EnvelopeCurve.WELCH,
            rt.EnvelopeCurve.WELCH
        )
    else
        entry.envelope = rt.Envelope(
            config.attack,
            config.sustain,
            config.release,
            rt.EnvelopeCurve.WELCH,
            rt.EnvelopeCurve.WELCH
        )
    end

    -- pitch
    local pitch = config.pitch or 1
    entry.source:setPitch(pitch)
    entry.pitch_motion = rt.SmoothedMotion1D(pitch)

    -- start source, return handler id
    entry.source:play()

    -- second swap source for cross fading loop
    if config.should_loop == true and config.loop_overlap > 0 then
        entry.swap_source = love.audio.newSource(resource_entry.sound_data)
        local overlap = config.loop_overlap * entry.duration
        local period = entry.duration - overlap

        entry.swap_period = period
        entry.swap_envelope = rt.Envelope(overlap, period - overlap, overlap)

        self:_sync_sources(entry.source, entry.swap_source)
    end

    self._handler_id_to_entry[handler_id] = entry

    for effect in values(config.effects) do
        self:add_effect(handler_id, effect)
    end

    return handler_id
end

--- @brief
function rt.SoundManager:update(delta)
    meta.assert(delta, mt.Number)

    local to_free = {}
    for handler_id, entry in pairs(self._handler_id_to_entry) do
        entry.volume_motion:update(delta)
        entry.position_motion:update(delta)
        entry.pitch_motion:update(delta)
        entry.envelope:update(delta)

        entry.elapsed = entry.elapsed + delta

        local master_amp = self._volume
            * entry.volume_motion:get_value()
            * entry.envelope:get_value()

        local px, py = entry.position_motion:get_position()
        local pitch = entry.pitch_motion:get_value()

        local is_looping = entry.source:isLooping()
        if entry.swap_source then
            -- both sources play continously, envelopes staggered for seamless loop
            --   _ _ _ _         _ _ _ _
            --  /   A   \       /   A   \
            --           _ _ _ _
            --          /   B   \

            if entry.swap_source:isPlaying() == false
                and entry.elapsed > entry.swap_period
            then
                -- delay second source by period
                entry.swap_source:play()
            end

            local amp_a = entry.swap_envelope:at(entry.elapsed % (2 * entry.swap_period))
            local amp_b = 1 - amp_a

            entry.source:setVolume(master_amp * amp_a)
            self:_set_source_position(entry.source, px, py)
            entry.source:setPitch(pitch)

            entry.swap_source:setVolume(master_amp * amp_b)
            self:_set_source_position(entry.swap_source, px, py)
            entry.swap_source:setPitch(pitch)
        else
            entry.source:setVolume(master_amp)
            self:_set_source_position(entry.source, px, py)
            entry.source:setPitch(pitch)
        end

        -- mark to free
        local x, y = entry.source:getPosition()
        if entry.is_stopping and math.less_than_or_equal(master_amp, 0, 0.01)
            or entry.envelope:get_is_done()
            or math.distance(x, y, self._listener_x, self._listener_y) > self._reference_distance
        then
            table.insert(to_free, handler_id)
        end
    end

    -- free entry
    for id in values(to_free) do
        local entry = self._handler_id_to_entry[id]
        entry.source:release()

        if entry.swap_source then
            entry.swap_source:release()
        end

        _active_sources = _active_sources - 1
        self._handler_id_to_entry[id] = nil
    end
end

--- @brief
function rt.SoundManager:set_global_volume(value)
    meta.assert(value, mt.Number)
    self._volume = value
    -- applied next update
end

--- @brief
function rt.SoundManager:list_active_handler_ids(sound_id)
    meta.assert(sound_id, mt.Optional(mt.String))

    local result = {}
    for handler_id, entry in pairs(self._handler_id_to_entry) do
        if sound_id == nil or entry.resource_entry.id == sound_id then
            table.insert(result, handler_id)
        end
    end

    return result
end

--- @brief
function rt.SoundManager:has_handler_id(handler_id)
    meta.assert(handler_id, mt.Number)

    return self._handler_id_to_entry[handler_id] ~= nil
end

--- @brief
function rt.SoundManager:set_player_position(position_x, position_y)
    if position_x == nil then position_x = 0 end
    if position_y == nil then position_y = 0 end

    meta.assert(position_x, mt.Number, position_y, mt.Number)

    self._listener_x, self._listener_y = position_x, position_y
    love.audio.setPosition(
        self._listener_x,
        self._listener_y,
        0 + self._z_height
    )
end

--- @brief
function rt.SoundManager:_get_entry(handler_id)
    return self._handler_id_to_entry[handler_id]
end

--- @brief
function rt.SoundManager:set_position(handler_id, position_x, position_y)
    meta.assert(
        handler_id, mt.Number,
        position_x, mt.Optional(mt.Number),
        position_y, mt.Optional(mt.Number)
    )

    local entry = self:_get_entry(handler_id)
    if entry == nil then return false end

    entry.position_motion:set_target_position(
        self:_set_source_position(entry.source, position_x, position_y)
    )

    return true
end

--- @brief
function rt.SoundManager:set_volume(handler_id, volume)
    meta.assert(handler_id, mt.Number, volume, mt.Number)

    local entry = self:_get_entry(handler_id)
    if entry == nil then return false end

    entry.volume_motion:set_target_value(math.clamp(volume, 0, 1))
    return true
end

--- @brief
function rt.SoundManager:set_filter(handler_id, t)
    meta.assert(handler_id, mt.Number, t, mt.Number)

    local entry = self:_get_entry(handler_id)
    if entry == nil then return false end

    t = math.clamp(t, 0, 1)
    entry.source:setFilter({
        type = "bandpass",
        highgain = t,
        lowgain = 1 - t
    })
    return true
end

--- @brief
function rt.SoundManager:remove_filter(handler_id)
    meta.assert(handler_id, mt.Number)

    local entry = self:_get_entry(handler_id)
    if entry == nil then return false end

    entry.source:setFilter(nil)
    return true
end

--- @brief
function rt.SoundManager:add_effect(handler_id, effect)
    meta.assert(handler_id, mt.Number, effect, mt.Union(mt.String, rt.SoundEffect))

    local entry = self:_get_entry(handler_id)
    if entry == nil then return false end

    local native
    if meta.is_string(effect) then
        native = effect
    else
        native = effect:get_native()
    end

    entry.source:setEffect(native, true)
    return true
end

--- @brief
function rt.SoundManager:remove_effect(handler_id, effect)
    meta.assert(handler_id, mt.Number, effect, mt.Union(mt.String, rt.SoundEffect))

    local entry = self:_get_entry(handler_id)
    if entry == nil then return false end

    local native
    if meta.is_string(effect) then
        native = effect
    else
        native = effect:get_native()
    end

    entry.source:setEffect(native, false) -- disable
    return true
end

--- @brief
function rt.SoundManager:stop(handler_id)
    meta.assert(handler_id, mt.Number)

    local entry = self:_get_entry(handler_id)
    if entry == nil then return false end

    entry.volume_motion:set_target_value(0)
    entry.envelope:release()
    entry.is_stopping = true

    return true
end

--- @brief
function rt.SoundManager:_get_state()
    local sound_id_to_active_handlers = {}
    for id, entry in pairs(self._handler_id_to_entry) do
        local sound_id = entry.resource_entry.id

        local list = sound_id_to_active_handlers[sound_id]
        if list == nil then
            list = {}
            sound_id_to_active_handlers[sound_id] = list
        end

        table.insert(list, id)
    end

    return sound_id_to_active_handlers
end


