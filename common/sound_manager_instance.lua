require "love.audio"
require "love.sound"
require "love.timer"

require "include"
require "common.filesystem"
require "common.sound_effect"
require "common.cache"
require "common.envelope"
require "common.envelope_asr"
require "common.smoothed_motion_1d"
require "common.smoothed_motion_2d"
require "common.random"

rt.settings.sound_manager = {
    assets_directory = "assets/sounds",
    update_step = 1 / 240, -- seconds
    n_priority_queue_sub_steps = 4,

    import_attack = 1 / 60,
    import_release = 1 / 60,
    import_should_normalize = true,
    
    envelope_shape = rt.EnvelopeCurve.WELCH,
    
    max_import_attack_fraction = 0.01,
    max_import_release_fraction = 0.01,

    degree_separation_char = "_",
    volume_motion_velocity = 4, -- factor

    max_cache_size = 512 -- mb
}

--- @class rt.SoundManager
rt.SoundManager = meta.class("SoundManager")
meta.add_signals(rt.SoundManager,
    "sound_done" -- (rt.SoundManager, sound_id, handler_id) -> nil
)

local _active_sources = 0

local _skip_next_delta = false
local _cache = rt.Cache(rt.CachePolicy.FIRST_IN_FIRST_OUT)
local _cache_size = 0 -- size in mb

local _PAUSE_STATE_IDLE = "IDLE"
local _PAUSE_STATE_PAUSING = "PAUSING"
local _PAUSE_STATE_PAUSED = "PAUSED"
local _PAUSE_STATE_UNPAUSING = "UNPAUSING"

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

    self:reset() -- generate resource entries

    self._volume_motion = rt.SmoothedMotion1D(1, rt.settings.sound_manager.volume_motion_velocity)
    self._pause_volume_motion = rt.SmoothedMotion1D(1, rt.settings.sound_manager.volume_motion_velocity)
    self._pause_state = _PAUSE_STATE_IDLE

    -- active playback entries
    self._handler_id = 0
    self._handler_id_to_entry = {} -- handler id to active entry
end

--- @brief
function rt.SoundManager:_get_resource_entry(id, degree)
    if degree ~= nil then id = id .. rt.settings.sound_manager.degree_separation_char .. degree end
    return self._id_to_resource_entry[id]
end

--- @brief
function rt.SoundManager:_load_data(path)
    local success, data_or_error = pcall(love.sound.newSoundData, path)
    if not success then
        rt.critical("In rt.SoundManager.play: when trying to play sound at `", path,  "`: ",  data_or_error)
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
        rt.settings.sound_manager.envelope_shape,
        rt.settings.sound_manager.envelope_shape
    )

    if n_samples == 0 then
        return nil, 0
    end

    local buffer = {}
    local max_sample = 0

    for sample_i = 1, n_samples, n_channels do
        local elapsed = sample_i / n_channels / sample_rate -- position to seconds
        local t = envelope:at(elapsed)

        for channel_i = 1, n_channels do
            local value = t * data:getSample(sample_i - 1, channel_i)
            buffer[sample_i + channel_i - 1] = value
            local magnitude = value < 0 and -value or value
            if magnitude > max_sample then
                max_sample = magnitude
            end
        end
    end

    if rt.settings.sound_manager.import_should_normalize then
        for i = 1, n_samples do
            buffer[i] = buffer[i] / max_sample
        end
    end

    -- flush the buffer into the sound data.
    for sample_i = 1, n_samples, n_channels do
        for channel_i = 1, n_channels do
            data:setSample(
                sample_i - 1,
                channel_i,
                buffer[sample_i + channel_i - 1]
            )
        end
    end

    _skip_next_delta = true -- prevent lag spike
    return data, duration
end

--- @brief
function rt.SoundManager:_set_source_position(source, x, y)
    if x == nil and y == nil then
        -- always 0 distance away from player
        source:setPosition(0, 0, 0)
        source:setRelative(true)
        return 0, 0
    else
        -- static position in world
        local x, y = x or self._listener_x,
            y or self._listener_y

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
    volume = 1,
    delay = 0,
    pitch = 1,
    x = nil, -- relative
    y = nil,
    should_loop = false,
    loop_overlap = 0, -- seconds
    attack = 0,
    sustain = nil, -- seconds
    release = 0,
    effects = nil,
    degree = nil,
    stop = {}
}

local _config_keys = {}
for v in range(
    "volume",
    "delay",
    "pitch",
    "x",
    "y",
    "should_loop",
    "loop_overlap",
    "attack",
    "sustain",
    "release",
    "effects",
    "degree",
    "stop"
) do
    _config_keys[v] = true
end

local _get_data_size_mb = function(data)
    return (data:getSampleCount() * data:getBitDepth() * data:getChannelCount()) / (8 * 1024 ^ 2)
end

--- @brief
function rt.SoundManager:play(id, config)
    local handler_id = self._handler_id
    self._handler_id = self._handler_id + 1
    return self:_play_internal(id, config, handler_id)
end

--- @brief
function rt.SoundManager:queue(after_handler_id, id, config)
    meta.assert(after_handler_id, mt.Number, id, mt.String, config, mt.Optional(mt.Table))

    local handler_id = self._handler_id
    self._handler_id = self._handler_id + 1

    if self._handler_id_to_entry[after_handler_id] == nil then
        after_handler_id = nil
    end

    return self:_play_internal(id, config, handler_id, after_handler_id)
end

--- @brief
function rt.SoundManager:_play_internal(id, config, handler_id, after_handler_id)
    meta.assert(id, mt.String, config, mt.Optional(mt.Table), after_handler_id, mt.Optional(mt.Number))

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

    if config.effects ~= nil then
        for i, effect in ipairs(config.effects) do
            if not meta.isa(effect, rt.SoundEffect) then
                rt.error("In rt.SoundManager.play: effect at position `", i, "`: expected `rt.SoundEffect`, got `", meta.typeof(effect), "`")
            end
        end
    end

    _verify("volume", mt.Number, false)
    _verify("delay", mt.Number, false)
    _verify("pitch", mt.Number, false)
    _verify("x", mt.Number, true)
    _verify("y", mt.Number, true)
    _verify("should_loop", mt.Boolean, true)
    _verify("loop_overlap", mt.Number, false)
    _verify("attack", mt.Number, false)
    _verify("sustain", mt.Number, true)
    _verify("release", mt.Number, false)
    _verify("effects", mt.Table, true)

    if config.stop ~= nil and not meta.is_table(config.stop) then
        config.stop = { config.stop }
    end
    _verify("stop", mt.Table, true)

    for x in values(config.stop) do
        if not meta.is_number(x) then
            rt.error("In rt.SoundManager.play: value `", x, "` in `stop` is not a valid handler id")
        end
    end

    -- degree is mt.Any
    if failed then return nil end

    local error_prefix = string.paste("In rt.SoundManager.play: config for sound `", id, "`:")
    if (config.loop_overlap < 0 or config.loop_overlap > 1) then
        rt.critical(error_prefix, "loop_overlap `", config.loop_overlap, "` is outside [0, 1]")
        config.loop_overlap = math.clamp(config.loop_overlap, 0, 1)
    end

    if config.loop_overlap > 0 and config.should_loop == false then
        rt.critical(error_prefix, "`loop_overlap` is set, but `should_loop` is false")
    end

    if config.volume < 0 then
        rt.critical(error_prefix, "volume `", config.pitch, "` cannot be negative")
    end

    if config.delay < 0 then
        rt.critical(error_prefix, "delay `", config.delay, "` cannot be negative")
    end

    if config.pitch <= 0 then
        rt.critical(error_prefix, "pitch `", config.pitch, "` cannot be zero or negative")
        config.pitch = 1
    end

    if config.attack < 0 then
        rt.critical(error_prefix, "attack `", config.attack, "` is negative")
        config.attack = 0
    end

    if config.release < 0 then
        rt.critical(error_prefix, "release `", config.release, "` is negative")
        config.release = 0
    end

    local degrees = self._id_to_degrees[id]
    if degrees ~= nil and not table.is_empty(degrees) then
        if config.degree ~= nil then config.degree = tostring(config.degree) end

        -- if not present or misconfigured, choose at random
        if config.degree == nil or degrees[config.degree] ~= true then
            if config.degree ~= nil then
                rt.warning("In rt.SoundManager.play: degree `", config.degree, "` is invalid for sound `", id, "`")
            end

            local to_choose = {}
            for k in keys(degrees) do
                table.insert(to_choose, k)
            end

            config.degree = rt.random.choose(to_choose)
        end
    end

    local resource_entry = self:_get_resource_entry(id, config.degree)
    if resource_entry == nil then
        rt.error("In rt.SoundManager.play: no sound with id `", id, "`")
        return nil
    end

    if resource_entry.data == nil then
        resource_entry.data, resource_entry.duration = self:_load_data(resource_entry.path)

        -- notify cache, if RAM usage too high, evict oldest used and deallocate
        _cache:push(resource_entry.path, resource_entry) -- use path as hash
        _cache_size = _cache_size + _get_data_size_mb(resource_entry.data)

        if _cache_size > rt.settings.sound_manager.max_cache_size then
            local last_node, last_hash = _cache:get_back()
            while last_hash ~= nil and last_node ~= resource_entry and _cache:get_size() > 1 do
                _cache_size = _cache_size - _get_data_size_mb(last_node.data)
                _cache:pop(last_hash)
                last_node.data:release()
                last_node.data = nil
                last_node, last_hash = _cache:get_back()
            end
        end
    else
        -- mark as recently used
        _cache:bump(resource_entry.path)
    end

    local entry = {
        id = handler_id,
        resource_entry = resource_entry,

        source = love.audio.newSource(resource_entry.data),
        source_is_playing = false,
        volume = config.volume,
        delay = config.delay,
        delay_elapsed = 0,

        elapsed = 0,

        waiting_for = after_handler_id,

        envelope = nil, -- Union<rt.Envelope, rt.EnvelopeASR>
        position_motion = nil, -- rt.SmoothedMotion2D
        volume_motion = nil, -- rt.SmoothedMotion1D
        pitch_motion = nil, -- rt.SmoothedMotion1D

        flush_volume_motion = nil, -- rt.SmoothedMotion1D
        is_flushing = false,
        is_stopping = false,

        swap_source = nil, -- love.Source
        swap_source_is_playing = false,
        swap_period = nil, -- seconds
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
        self:_set_source_position(entry.source, config.x, config.y)
    )

    -- loop
    entry.source:setLooping(config.should_loop)

    -- volume
    entry.source:setVolume(1) -- set next update
    entry.volume_motion = rt.SmoothedMotion1D(1, rt.settings.sound_manager.volume_motion_velocity)
    entry.flush_volume_motion = rt.SmoothedMotion1D(1, rt.settings.sound_manager.volume_motion_velocity)

    local duration = entry.resource_entry.duration

    local max_sustain = duration - (config.attack + config.release)
    if config.sustain == nil then
        config.sustain = max_sustain
    else
        config.sustain = math.min(config.sustain, max_sustain)
    end

    if config.sustain < 0 then
        rt.critical(error_prefix, "sustain `", config.sustain, "` is negative")
        config.sustain = duration - (config.attack + config.release)
    end

    if not config.should_loop and (config.attack + config.sustain + config.release > duration) then
        rt.warning(error_prefix, "envelope config duration exceeds audio length")
    end

    if config.should_loop then
        entry.envelope = rt.EnvelopeASR(
            config.attack,
            config.release,
             rt.settings.sound_manager.envelope_shape,
             rt.settings.sound_manager.envelope_shape
        )
    else
        entry.envelope = rt.Envelope(
            config.attack,
            config.sustain,
            config.release,
             rt.settings.sound_manager.envelope_shape,
             rt.settings.sound_manager.envelope_shape
        )
    end

    -- pitch
    local pitch = config.pitch or 1
    entry.source:setPitch(pitch)
    entry.pitch_motion = rt.SmoothedMotion1D(pitch)

    -- second swap source for cross fading loop
    if config.should_loop == true and config.loop_overlap > 0 then
        entry.swap_source = love.audio.newSource(resource_entry.data)

        if entry.swap_source ~= nil then
            _active_sources = _active_sources + 1
        else
            rt.critical("In rt.SoundManager: number of active sources reached maximum of `", _active_sources, "`. No more sources can be allocated")
            return nil
        end

        local overlap = config.loop_overlap * duration
        local period = duration - overlap

        entry.swap_period = period
        entry.swap_envelope = rt.Envelope(overlap, period - overlap, overlap)

        self:_sync_sources(entry.source, entry.swap_source)
    end

    self._handler_id_to_entry[handler_id] = entry

    if config.effects ~= nil then
        for effect in values(config.effects) do
            self:add_effect(handler_id, effect)
        end
    end

    if config.stop ~= nil then
        for to_stop in values(config.stop) do
            self:stop(to_stop)
        end
    end

    return handler_id
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
function rt.SoundManager:set_player_position(x, y)
    if x == nil then x = 0 end
    if y == nil then y = 0 end

    meta.assert(x, mt.Number, y, mt.Number)

    self._listener_x, self._listener_y = x, y
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
function rt.SoundManager:pause()
    if self._PAUSE_STATE_PAUSED then return end
    self._pause_state = _PAUSE_STATE_PAUSING
    self._pause_volume_motion:set_target_value(0)
end

--- @brief
function rt.SoundManager:unpause()
    self._pause_state = _PAUSE_STATE_UNPAUSING
    self._pause_volume_motion:set_target_value(1)

    for entry in values(self._handler_id_to_entry) do
        if entry.source_is_playing == true then
            entry.source:play()
        end

        if entry.swap_source ~= nil and entry.swap_source_is_playing then
            entry.swap_source:play()
        end
    end
end

--- @brief
function rt.SoundManager:flush()
    for entry in values(self._handler_id_to_entry) do
        entry.is_flushing = true
        entry.flush_volume_motion:set_target_value(0)
    end
end

--- @brief
function rt.SoundManager:set_position(handler_id, x, y)
    meta.assert(
        handler_id, mt.Number,
        x, mt.Optional(mt.Number),
        y, mt.Optional(mt.Number)
    )

    local entry = self:_get_entry(handler_id)
    if entry == nil then return false end

    entry.position_motion:set_target_position(
        self:_set_source_position(entry.source, x, y)
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
    if entry == nil then return false end -- not an error

    entry.volume_motion:set_target_value(0)
    entry.envelope:release()
    entry.is_stopping = true

    return true
end

--- @brief
function rt.SoundManager:get_duration(id, degree)
    meta.assert(id, mt.String, degree, mt.Optional(mt.Any))

    local degrees = self._id_to_degrees[id]
    if degree == nil and degrees ~= nil and not table.is_empty(degrees) then
        local in_order = {}
        for x in keys(degrees) do table.insert(in_order, x) end
        table.sort(in_order)
        id = id .. rt.settings.sound_manager.degree_separation_char .. in_order[1]
    end

    local entry = self:_get_resource_entry(id, degree)
    if entry == nil then
        rt.error("In rt.SoundManager.get_duration: no sound with id `", id, "`")
        return 0
    else
        if entry.duration == nil then
            -- entry not yet initialized
            -- load source as stream to query duration with minimal allocation
            local source = love.audio.newSource(entry.path, "stream")
            if source == nil then
                rt.error("In rt.SoundManager.get_duration: source count allocation limit reached")
                return 0
            end

            entry.duration = source:getDuration("seconds")
            source:release()
        end

        return entry.duration
    end
end

local _degree_comparator = function(a, b)
    local a_maybe = tonumber(a)
    local b_maybe = tonumber(b)
    return (a_maybe or a) < (b_maybe or b)
end

--- @brief
function rt.SoundManager:get_degrees(id)
    local degrees = self._id_to_degrees[id]
    if degrees == nil then
        return {}
    else
        local res = {}
        for x in keys(degrees) do
            table.insert(res, x)
        end

        table.sort(res, _degree_comparator)
        return res
    end
end

--- @brief
function rt.SoundManager:choose_degree(id)
    if self._id_to_degrees[id] == nil then
        rt.error("In rt.SoundManager.choose_degree: no sound with id `", id, "`")
        return nil
    end

    local degrees = self:get_degrees(id)
    local i = self._id_to_degree_i[id]
    self._id_to_degree_i[id] = i + 1
    return degrees[math.wrap(i, #degrees)]
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

--- @brief
function rt.SoundManager:_get_cache()
    local cache = {}
    cache.id_to_entry = {}

    for id, entry in pairs(self._id_to_resource_entry) do
        cache.id_to_entry[id] = {
            path = entry.path,
            duration = nil
        }
    end

    cache.id_to_degrees = self._id_to_degrees
    cache.id_to_degree_i = self._id_to_degree_i
    return cache
end

local _motion_eps = 0.01

--- @brief
function rt.SoundManager:reset()
    local prefix = bd.normalize_path(rt.settings.sound_manager.assets_directory)
    if string.last(prefix) ~= "/" then prefix = prefix .. "/" end
    local id_to_path = bd.generate_resource_ids(prefix, bd.is_sound_file)

    self._id_to_resource_entry = {} -- Table<String, String>, indexable like `self._id_to_resource_entry["overworld.foo.effect"]`
    self._id_to_degrees = {}
    self._id_to_degree_i = {}

    for id, path in pairs(id_to_path) do
        self._id_to_resource_entry[id] = {
            id = id,
            path = path,  -- String
            data = nil, -- love.SoundData
            duration = nil
        }

        local id_without_degree = string.match(id, "^(.*)_[^_]*$") -- everything before last occurence of `_`
        if id_without_degree == nil then id_without_degree = id end

        local name = string.match(id, ".*%.([^.]*)_[^_.]*$") -- everything between last `.` and `_`
        local degree = string.match(id, "_([^_]*)$") -- everything after last `_`

        local degrees = self._id_to_degrees[id_without_degree]
        if degrees == nil then
            degrees = {}
            self._id_to_degrees[id_without_degree] = degrees
            self._id_to_degree_i[id_without_degree] = 1 -- for choose_degree
        end

        if degree ~= nil then
            degrees[degree] = true
        end
    end

    if self._handler_id_to_entry ~= nil then
        for id, entry in pairs(self._handler_id_to_entry) do
            self:stop(id)
        end
    end
end

--- @brief
function rt.SoundManager:update(delta)
    meta.assert(delta, mt.Number)

    if _skip_next_delta == true then
        _skip_next_delta = false
        return
    end

    self._pause_volume_motion:update(delta)
    self._volume_motion:update(delta)

    local to_free = {}
    for handler_id, entry in pairs(self._handler_id_to_entry) do
        local should_continue = true
        if entry.waiting_for ~= nil then
            local before = self._handler_id_to_entry[entry.waiting_for]
            should_continue = before == nil or before.is_stopping == true
            if should_continue == true then entry.waiting_for = nil end
        end

        if should_continue then
            entry.delay_elapsed = entry.delay_elapsed + delta
            should_continue = entry.delay_elapsed >= entry.delay
        end

        if should_continue then
            if self._pause_state ~= _PAUSE_STATE_PAUSED then
                if entry.source:isPlaying() == false then
                    entry.source:play()
                    entry.source_is_playing = true
                end

                entry.volume_motion:update(delta)
                entry.position_motion:update(delta)
                entry.pitch_motion:update(delta)
                entry.envelope:update(delta)

                entry.elapsed = entry.elapsed + delta
            end

            entry.flush_volume_motion:update(delta)

            local master_amp = self._volume_motion:get_value()
                * self._pause_volume_motion:get_value()
                * entry.volume
                * entry.volume_motion:get_value()
                * entry.envelope:get_value()
                * entry.flush_volume_motion:get_value()

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
                    entry.swap_source_is_playing = true
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

            if self._pause_state == _PAUSE_STATE_PAUSED then
                if entry.source_is_playing == true then
                    entry.source:pause()
                end

                if entry.swap_source ~= nil and entry.swap_source_is_playing then
                    entry.swap_source:pause()
                end
            end

            local should_free = entry.is_flushing and math.equals(entry.flush_volume_motion:get_value(), 0, _motion_eps)
            if self._pause_state ~= _PAUSE_STATE_PAUSED then
                should_free = should_free or (entry.is_stopping and (
                    math.equals(master_amp, 0, _motion_eps)
                    or entry.envelope:get_is_done()
                    or math.distance(self._listener_x, self._listener_y, entry.source:getPosition()) > self._reference_distance ^ 2
                ))
            end

            -- mark to free
            if should_free then
                entry.source:stop()
                if entry.swap_source ~= nil then entry.swap_source:stop() end
                table.insert(to_free, handler_id)
            end
        end
    end

    -- free entry
    for id in values(to_free) do
        local entry = self._handler_id_to_entry[id]
        entry.source:release()
        _active_sources = _active_sources - 1

        if entry.swap_source then
            entry.swap_source:release()
            _active_sources = _active_sources - 1
        end

        self._handler_id_to_entry[id] = nil
    end

    if self._pause_state == _PAUSE_STATE_PAUSING
        and math.equals(self._pause_volume_motion:get_value(), 0, _motion_eps)
    then
        self._pause_state = _PAUSE_STATE_PAUSED
    elseif self._pause_state == _PAUSE_STATE_UNPAUSING
        and math.equals(self._pause_volume_motion:get_value(), 1, _motion_eps)
    then
        self._pause_state = _PAUSE_STATE_IDLE
    end
end


