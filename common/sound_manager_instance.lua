require "love.audio"
require "love.sound"
require "love.timer"

require "include"
require "common.filesystem"
require "common.sound_effect"
require "common.envelope"
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
            data:setSample(sample_i + offset, t * data:getSample(sample_i + offset))
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
        local x, y, z = self:_map_coordinates(
            position_x or self._listener_x,
            position_y or self._listener_y
        )
        source:setPosition(x, y, z)
        source:setRelative(false)
        return x, y
    end
end

local _config_default = {
    pitch = 1,
    position_x = nil, -- relative
    position_y = nil,
    should_loop = false,
    attack = 0,
    sustain = nil, -- duration
    release = 0,
    effects = {}
}

local _config_keys = {
    pitch = true,
    position_x = true,
    position_y = true,
    should_loop = true,
    attack = true,
    sustain = true,
    release = true,
    effects = true
}

--- @brief
function rt.SoundManager:play(id, config)
    meta.assert(id, mt.String, config, mt.Optional(mt.Table))

    local handler_id = self._handler_id
    self._handler_id = self._handler_id + 1

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
    _verify("should_loop", mt.Boolean, false)
    _verify("attack", mt.Number, false)
    _verify("sustain", mt.Number, true)
    _verify("release", mt.Number, false)
    _verify("effects", mt.Table, false)
    if failed then return nil end

    if resource_entry.sound_data == nil then
        resource_entry.sound_data = self:_load_data(resource_entry.sound_path)
    end

    local entry = {
        id = handler_id,
        resource_entry = resource_entry,
        source = love.audio.newSource(resource_entry.sound_data),
        envelope = nil, -- rt.Envelope
        position_motion = nil, -- Optional<rt.SmoothedMotion2D>,
        volume_motion = nil, -- rt.SmoothedMotion1D
        is_stopping = false
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

    -- volume
    entry.source:setVolume(0) -- set next update
    entry.volume_motion = rt.SmoothedMotion1D(0)

    local sustain = resource_entry.sound_data:getDuration() - (config.attack + config.release)
    if config.sustain ~= nil then
        sustain = math.min(config.sustain, sustain)
    end

    entry.envelope = rt.Envelope(
        config.attack,
        sustain,
        config.release,
        rt.EnvelopeCurve.WELCH,
        rt.EnvelopeCurve.WELCH
    )

    -- pitch
    local pitch = config.pitch or 1
    entry.source:setPitch(pitch)
    entry.pitch_motion = rt.SmoothedMotion1D(pitch)

    -- others
    entry.source:setLooping(config.should_loop)

    -- start source, return handler id
    entry.source:play()
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

        local volume = self._volume
            * entry.envelope:get_value()
            * entry.volume_motion:get_value()

        entry.source:setVolume(volume)
        self:_set_source_position(entry.source, entry.position_motion:get_position())
        entry.source:setPitch(entry.pitch_motion:get_value())

        local x, y = entry.source:getPosition()
        if (entry.is_stopping and math.equals(volume, 0, 0.01))
            or entry.envelope:get_is_done()
            or math.distance(x, y, self._listener_x, self._listener_y) > self._reference_distance
        then
            table.insert(to_free, handler_id)
        end
    end

    -- free entry
    for id in values(to_free) do
        local entry = self._handler_id_to_entry
        entry.source:release()
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


