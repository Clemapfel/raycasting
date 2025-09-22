require "common.audio_time_unit"

rt.settings.music_manager_playback = {
    buffer_size = 2^11, -- bytes
    n_buffers = 16,
}

rt.MusicManagerPlayback = meta.class("MusicManagerPlayback")

--- @brief
function rt.MusicManagerPlayback:_seconds_to_sample(seconds)
    return math.floor(seconds * self._sample_rate + 0.5)
end

--- @brief
function rt.MusicManagerPlayback:_sample_to_seconds(sample)
    return sample / self._sample_rate
end

--- @brief
function rt.MusicManagerPlayback:instantiate(path_or_decoder)
    if meta.is_string(path_or_decoder) then
        self:create_form(love.sound.newDecoder(path_or_decoder, rt.settings.music_manager_playback))
    elseif path_or_decoder.typeOf ~= nil and path_or_decoder:typeOf("Decoder") then
        self:create_from(path_or_decoder)
    end
end

--- @brief
function rt.MusicManagerPlayback:create_from(decoder)
    self._decoder = decoder -- love.audio.Decoder
    self._decoder_offset = 0
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
            -- clamp in samples
            self._decoder_offset = math.clamp(self._decoder_offset, 0, self._loop_end)

            -- seek by sample
            self._decoder:seek(self:_sample_to_seconds(self._decoder_offset))
            local chunk = self._decoder:decode()
            local chunk_samples = chunk:getSampleCount()
            local chunk_length = chunk_samples / self._sample_rate

            local chunk_end_sample = self._decoder_offset + chunk_samples

            if chunk_end_sample > self._loop_end then
                -- split the chunk at the loop point
                local samples_before_loop = self._loop_end - self._decoder_offset
                local samples_after_loop = chunk_samples - samples_before_loop

                -- first part: from current offset to loop end
                local first_chunk = love.sound.newSoundData(samples_before_loop / self._channel_count, self._sample_rate, self._bit_depth, self._channel_count)
                ffi.copy(first_chunk:getFFIPointer(), chunk:getFFIPointer(), samples_before_loop * ffi.sizeof("int16_t"))
                self._native:queue(first_chunk)

                -- loop: seek to loop start and fill remaining samples
                self._decoder:seek(self:_sample_to_seconds(self._loop_start))
                local new_chunk = self._decoder:decode()
                local second_chunk = love.sound.newSoundData(samples_after_loop / self._channel_count, self._sample_rate, self._bit_depth, self._channel_count)
                ffi.copy(second_chunk:getFFIPointer(), new_chunk:getFFIPointer(), samples_after_loop * ffi.sizeof("int16_t"))
                self._native:queue(second_chunk)

                self._decoder_offset = self._loop_start + samples_after_loop
            else
                self._native:queue(chunk)
                self._decoder_offset = self._decoder_offset + chunk_samples
            end
        end

        self._native:play()
    end
end

--- @brief
function rt.MusicManagerPlayback:set_loop_bounds(loop_start, loop_end, unit)
    if unit == nil then unit = rt.AudioTimeUnit.SECONDS end
    if unit == rt.AudioTimeUnit.SECONDS then
        local start_sample = self:_seconds_to_sample(loop_start)
        local end_sample = self:_seconds_to_sample(loop_end)
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
