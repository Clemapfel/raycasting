require "love.timer"
require "love.sound"
require "love.audio"

require "include"
require "common.common"
require "common.random"
require "common.smoothed_motion_1d"

local main_to_worker, worker_to_main, MessageType = ...

local state = {
    volume_motion = rt.SmoothedMotion1D(0),
    volume_eps = 0.01,
    is_playing = false,
    step = 1 / 240,
    last_update_timestamp = love.timer.getTime(),

    data = nil,
    source = nil,
    start_position = 0,
    end_position = math.huge,

    overlap = 2 / 3,
    density = 60,
    frequency_jitter_type = "uniform",
    frequency_jitter = 0,

    pitch_jitter_type = "uniform",
    pitch_jitter = 0,

    -- DSP state
    buffer_size = 1024,
    output_buffer = nil,
    active_grains = {},
    grain_pool = {},
    trigger_timer = 0
}

-- helper for random distribution
local function get_jitter_multiplier(jitter, dist_type)
    if jitter == 0 then return 1 end
    if dist_type == "gaussian" then
        return rt.random.gaussian(1 - jitter, 1 + jitter)
    else
        return rt.random.uniform(1 - jitter, 1 + jitter)
    end
end

function state:initialize(file)
    self.data = love.sound.newSoundData(file)
    self.sample_count = self.data:getSampleCount()
    self.sample_rate = self.data:getSampleRate()
    self.bit_depth = self.data:getBitDepth()

    self.source = love.audio.newQueueableSource(
        self.sample_rate,
        self.bit_depth,
        1,
        8
    )

    self.output_buffer = love.sound.newSoundData(
        self.buffer_size,
        self.sample_rate,
        self.bit_depth,
        1
    )

    -- Pre-allocate grain pool to prevent GC overhead
    for i = 1, 100 do
        table.insert(self.grain_pool, {
            pos = 0, pitch = 1, phase = 0, phase_inc = 0
        })
    end
end

function state:spawn_grain()
    if #self.grain_pool == 0 then return end

    local duration = self.overlap / self.density
    if duration <= 0 then return end

    local grain = table.remove(self.grain_pool)
    local max_start = math.max(0, math.min(self.end_position, self.sample_count) - (duration * self.sample_rate))

    grain.pos = rt.random.uniform(self.start_position, max_start)
    grain.pitch = get_jitter_multiplier(self.pitch_jitter, self.pitch_jitter_type)
    grain.phase = 0
    grain.phase_inc = 1.0 / (duration * self.sample_rate)

    table.insert(self.active_grains, grain)
end

function state:update(delta)
    for object in range(self.volume_motion) do
        object:update(delta)
    end

    if self.volume_motion:get_value() < self.volume_eps or not self.data then
        return
    end

    -- Process full buffers while the source demands them
    while self.source:getFreeBufferCount() > 0 do
        local current_vol = self.volume_motion:get_value()
        local base_period = 1.0 / self.density
        local max_idx = self.sample_count - 1

        -- Render frame-by-frame
        for i = 0, self.buffer_size - 1 do
            self.trigger_timer = self.trigger_timer - (1.0 / self.sample_rate)

            if self.trigger_timer <= 0 then
                self:spawn_grain()
                local freq_mult = get_jitter_multiplier(self.frequency_jitter, self.frequency_jitter_type)
                self.trigger_timer = base_period * freq_mult
            end

            local sum = 0

            -- Reverse loop for O(1) swap-and-pop removal
            for j = #self.active_grains, 1, -1 do
                local g = self.active_grains[j]

                -- Linear Interpolation
                local idx = math.floor(g.pos)
                local frac = g.pos - idx
                local s1 = self.data:getSample(math.min(idx, max_idx))
                local s2 = self.data:getSample(math.min(idx + 1, max_idx))
                local sample = s1 + frac * (s2 - s1)

                -- Hann Window
                local window = 0.5 * (1.0 - math.cos(2.0 * math.pi * g.phase))
                sum = sum + (sample * window)

                -- Advance state
                g.pos = g.pos + g.pitch
                g.phase = g.phase + g.phase_inc

                if g.phase >= 1.0 or g.pos >= self.sample_count then
                    -- O(1) Removal to avoid array shifts
                    self.active_grains[j] = self.active_grains[#self.active_grains]
                    self.active_grains[#self.active_grains] = nil
                    table.insert(self.grain_pool, g)
                end
            end

            -- Soft clipping via hyperbolic tangent and master gain
            local out = math.tanh(sum) * current_vol
            self.output_buffer:setSample(i, out)
        end

        dbg("queue")
        self.source:queue(self.output_buffer)
        self.source:play()
    end
end

local message_type_to_handler = {
    [MessageType.CONFIG] = function(message)
        for key, value in pairs(message) do
            if key ~= "type" then
                if state[key] == nil and key ~= "volume" then
                    worker_to_main:push({
                        type = MessageType.ERROR,
                        error = "Message of type `CONFIG` has unhandled parameter `" .. tostring(key) .. "`",
                        traceback = debug.traceback()
                    })
                elseif key == "volume" then
                    state.volume_motion:set_target_value(value)
                else
                    state[key] = value
                end
            end
        end
    end,
    [MessageType.INITIALIZE] = function(message)
        state:initialize(message.file)
        state.volume_motion:set_value(0)
    end,
    [MessageType.PLAY] = function(message)
        state.is_playing = true
        state.volume_motion:set_target_value(1)
        if state.source then state.source:play() end
    end,
    [MessageType.STOP] = function(message)
        state.is_playing = false
        state.volume_motion:set_target_value(0)
    end,
}

local success, error_maybe = pcall(function()
    local safe_call = function(f, ...)
        local res = { pcall(f, ...) }
        if res[1] == true then
            table.remove(res, 1)
            return table.unpack(res)
        else
            worker_to_main:push({
                type = MessageType.ERROR,
                error = tostring(res[2]),
                traceback = debug.traceback()
            })
        end
    end

    local shutdown_active = false
    while true do
        if shutdown_active == true and state.volume_motion:get_value() < state.volume_eps then
            return
        else
            while main_to_worker:getCount() > 0 do
                local message = main_to_worker:pop()
                if message.type == MessageType.SHUTDOWN then
                    shutdown_active = true
                else
                    local handler = message_type_to_handler[message.type]
                    if handler ~= nil then
                        safe_call(handler, message)
                    else
                        worker_to_main:push({
                            type = MessageType.ERROR,
                            error = "Unhandled message type `" .. tostring(message.type) .. "`",
                            traceback = debug.traceback(),
                        })
                    end
                end
            end
        end

        local delta = love.timer.getTime() - state.last_update_timestamp
        state:update(delta)
        state.last_update_timestamp = love.timer.getTime()
        love.timer.sleep(state.step)
    end
end)

worker_to_main:push({
    type = MessageType.SHUTDOWN_RESPONSE,
    success = success,
    error = error_maybe,
    traceback = debug.traceback()
})