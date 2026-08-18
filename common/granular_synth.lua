rt.settings.granular_synth = {
    default_config = {
        density = 60,
        overlap = 2 / 3,
        frequency_jitter = 0.05,
        frequency_jitter_type = "uniform",
        pitch_jitter = 0.05,
        pitch_jitter_type = "uniform",
        start_position = 0,
        end_position = math.huge
    }
}

--- @class rt.GranularSynth
rt.GranularSynth = meta.class("GranularSynth")

local MessageType = {}
for id in range(
    "SHUTDOWN",
    "SHUTDOWN_RESPONSE",
    "ERROR",
    "INITIALIZE",
    "PLAY",
    "STOP",
    "CONFIG"
) do
    MessageType[id] = id
end

--- @brief
function rt.GranularSynth:instantiate(grain_file)
    if self._thread == nil or self._thread:get_is_running() == false then
        self._thread = rt.Thread("common/granular_synth_worker.lua")
        self._worker_to_main = rt.Channel()
        self._main_to_worker = rt.Channel()

        -- The worker unpacks: main_to_worker, worker_to_main, MessageType
        self._thread:start(
            self._main_to_worker,
            self._worker_to_main,
            MessageType
        )

        self._thread:signal_connect("shutdown", function(thread)
            self._main_to_worker:push({
                type = MessageType.SHUTDOWN
            })
        end)
    end

    self._config = table.deepcopy(rt.settings.granular_synth.default_config)
    self._config.volume = 1.0
    self._config.type = MessageType.CONFIG
    self._main_to_worker:push(self._config)

    if grain_file ~= nil then
        self:initialize(grain_file)
    end
end

--- @brief
function rt.GranularSynth:initialize(grain_file, start_t, end_t)
    meta.assert(grain_file, mt.String,
        start_t, mt.Optional(mt.Number),
        end_t, mt.Optional(mt.Number)
    )

    if not bd.exists(grain_file) then
        rt.error("In rt.GranularSynth.instantiate: file at `", grain_file, "` does not exist")
    end

    self._main_to_worker:push({
        type = MessageType.INITIALIZE,
        file = grain_file
    })

    if start_t then self:set_start_position(start_t) end
    if end_t then self:set_end_position(end_t) end
end

--- @brief
function rt.GranularSynth:play()
    self._main_to_worker:push({
        type = MessageType.PLAY
    })
end

--- @brief
function rt.GranularSynth:stop()
    self._main_to_worker:push({
        type = MessageType.STOP
    })
end

--- @brief
function rt.GranularSynth:set_density(density)
    meta.assert(density, mt.Number)
    self._config.density = density
    self._config.type = MessageType.CONFIG
    self._main_to_worker:push(self._config)
end

--- @brief
function rt.GranularSynth:get_density()
    return self._config.density
end

--- @brief
function rt.GranularSynth:set_overlap(overlap)
    meta.assert(overlap, mt.Number)
    if overlap < 0 then
        rt.error("In rt.GranularSynth:set_overlap: overlap `", overlap, "` cannot be negative")
    end
    self._config.overlap = overlap
    self._config.type = MessageType.CONFIG
    self._main_to_worker:push(self._config)
end

--- @brief
function rt.GranularSynth:get_overlap()
    return self._config.overlap
end

--- @brief
function rt.GranularSynth:set_frequency_jitter(jitter)
    meta.assert(jitter, mt.Number)
    self._config.frequency_jitter = jitter
    self._config.type = MessageType.CONFIG
    self._main_to_worker:push(self._config)
end

--- @brief
function rt.GranularSynth:set_pitch_jitter(jitter)
    meta.assert(jitter, mt.Number)
    self._config.pitch_jitter = jitter
    self._config.type = MessageType.CONFIG
    self._main_to_worker:push(self._config)
end

--- @brief
function rt.GranularSynth:set_start_position(start_position)
    meta.assert(start_position, mt.Number)
    self._config.start_position = start_position
    self._config.type = MessageType.CONFIG
    self._main_to_worker:push(self._config)
end

--- @brief
function rt.GranularSynth:get_start_position()
    return self._config.start_position
end

--- @brief
function rt.GranularSynth:set_end_position(end_position)
    meta.assert(end_position, mt.Number)
    self._config.end_position = end_position
    self._config.type = MessageType.CONFIG
    self._main_to_worker:push(self._config)
end

--- @brief
function rt.GranularSynth:get_end_position()
    return self._config.end_position
end

--- @brief
function rt.GranularSynth:set_volume(volume)
    meta.assert(volume, mt.Number)
    self._config.volume = volume
    self._config.type = MessageType.CONFIG
    self._main_to_worker:push(self._config)
end

--- @brief
function rt.GranularSynth:get_volume()
    return self._config.volume
end

--- @brief
function rt.GranularSynth:update(_)
    while self._worker_to_main:get_n_messages() > 0 do
        local message = self._worker_to_main:pop()
        if message.type == MessageType.ERROR then
            if message.fatal == true then
                rt.fatal(message.error, "\n", message.traceback)
            else
                rt.critical(message.error, "\n", message.traceback)
            end
        elseif message.type == MessageType.SHUTDOWN_RESPONSE then
            if message.success == false then
                rt.error(message.error, "\n", message.traceback)
            end
        else
            rt.error("In rt.GranularSynth.update: unhandled message type `", tostring(message.type), "`")
        end
    end
end