require "common.audio_time_unit"

rt.settings.music_manager_playback = {
    buffer_size = 2^12, -- bytes
    n_buffers = 8,
}

rt.MusicManagerPlayback = meta.class("MusicManagerPlayback")

--- @brief
function rt.MusicManagerPlayback:_seconds_to_sample(seconds)
    return math.ceil(seconds * self._sample_rate)
end

--- @brief
function rt.MusicManagerPlayback:_sample_to_seconds(sample)
    return sample / self._sample_rate
end

--- @brief
function rt.MusicManagerPlayback:instantiate(path)
    meta.assert(path, "String")
    self:create_from(path)
end

--- @brief
function rt.MusicManagerPlayback:create_from(path)
    local decoder = love.sound.newDecoder(
        path,
        rt.settings.music_manager_playback.buffer_size
    )

    self._decoder = decoder
    self._decoder_offset = 0 -- in samples
    self._buffer_size = rt.settings.music_manager_playback.buffer_size
    self._sample_rate = decoder:getSampleRate()
    self._bit_depth = decoder:getBitDepth()
    self._channel_count = decoder:getChannelCount()

    if self._loop_start == nil then
        self._loop_start = 0
    end

    local duration = self:_seconds_to_sample(decoder:getDuration())
    if self._loop_end == nil then
        self._loop_end = duration
    else
        self._loop_end = math.min(self._loop_end, duration)
    end

    self._native = love.audio.newQueueableSource(
        self._sample_rate,
        self._bit_depth,
        self._channel_count,
        rt.settings.music_manager_playback.n_buffers
    )

    self._is_playing = false
end

--- @brief Updates the playback state and handles looping.
function rt.MusicManagerPlayback:update(_)
    if self._is_playing then
        for i = 1, self._native:getFreeBufferCount() do
            -- seek by sample - convert total samples to seconds
            self._decoder:seek(self:_total_samples_to_seconds(self._decoder_offset))
            local chunk = self._decoder:decode()

            -- `getSampleCount` returns samples *per channel*
            local chunk_samples_per_channel = chunk:getSampleCount()
            local chunk_total_samples = chunk_samples_per_channel * self._channel_count

            if self._decoder_offset + chunk_total_samples > self._loop_end then
                -- replace samples in chunk that would go past loop with samples from the start of the loop
                local loop_end_chunk = chunk

                -- get samples from start of loop - convert loop_start to seconds
                self._decoder:seek(self:_total_samples_to_seconds(self._loop_start))
                local loop_start_chunk = self._decoder:decode()

                local sample_t = ternary(chunk:getBitDepth() == 8, "uint8_t", "int16_t")
                local n_samples_before_loop_end = self._loop_end - self._decoder_offset

                -- calculate how many samples per channel to replace
                local samples_to_replace_per_channel = chunk_samples_per_channel - (n_samples_before_loop_end / self._channel_count)
                samples_to_replace_per_channel = math.min(samples_to_replace_per_channel, loop_start_chunk:getSampleCount())

                -- replace the samples that would go past loop_end with samples from loop_start
                local loop_end_ptr = ffi.cast(sample_t .. "*", loop_end_chunk:getFFIPointer())
                local loop_start_ptr = ffi.cast(sample_t .. "*", loop_start_chunk:getFFIPointer())
                local n_bytes_to_copy = samples_to_replace_per_channel * self._channel_count * ffi.sizeof(sample_t)
                ffi.copy(loop_end_ptr + n_samples_before_loop_end, loop_start_ptr, n_bytes_to_copy)

                self._native:queue(loop_end_chunk)
                self._decoder_offset = self._loop_start + samples_to_replace_per_channel
            else
                self._native:queue(chunk)
                self._decoder_offset = self._decoder_offset + self:_seconds_to_sample(chunk:getDuration()) * self._channel_count
            end
        end

        self._native:play()
    end
end

-- Also need to fix the conversion functions to be clear about units
function rt.MusicManagerPlayback:_seconds_to_total_samples(seconds)
    return math.ceil(seconds * self._sample_rate * self._channel_count)
end

function rt.MusicManagerPlayback:_total_samples_to_seconds(total_samples)
    return total_samples / (self._sample_rate * self._channel_count)
end

function rt.MusicManagerPlayback:set_loop_bounds(loop_start, loop_end, unit)
    if unit == nil then unit = rt.AudioTimeUnit.SECONDS end
    if unit == rt.AudioTimeUnit.SECONDS then
        local start_sample = self:_seconds_to_total_samples(loop_start)
        local end_sample = self:_seconds_to_total_samples(loop_end)
        self._loop_start = start_sample
        self._loop_end = end_sample
    elseif unit == rt.AudioTimeUnit.SAMPLES then
        self._loop_start = loop_start
        self._loop_end = loop_end
    else
        rt.error("In rt.MusicManagerPlayback:set_loop_bounds: unknown unit `" .. unit .. "`, expected rt.AudioTimeUnit")
    end
end

--- @brief
function rt.MusicManagerPlayback:is_compatible(decoder)
    return self._sample_rate == decoder:getSampleRate()
        and self._bit_depth == decoder:getBitDepth()
        and self._channel_count == decoder:getChannelCount()
end

--- @brief
function rt.MusicManagerPlayback:set_volume(v)
    self._native:setVolume(v)
end

--- @brief
function rt.MusicManagerPlayback:play()
    self._is_playing = true
end

--- @brief
function rt.MusicManagerPlayback:pause()
    self._is_playing = false
    self._native:pause()
end

--- @brief
function rt.MusicManagerPlayback:stop()
    self._is_playing = false
    self._native:stop()
    self._decoder_offset = 0
end
