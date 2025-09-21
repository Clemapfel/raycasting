rt.settings.music_manager_playback = {
    buffer_size = 2^11, -- bytes
    n_buffers = 16,
}

rt.MusicManagerPlayback = meta.class("MusicManagerPlayback")

--- @brief
function rt.MusicManagerPlayback:instantiate(path)
    local buffer_size = rt.settings.music_manager_playback.buffer_size
    local decoder = love.sound.newDecoder(path, buffer_size)
    local sample_rate = decoder:getSampleRate()
    local bit_depth = decoder:getBitDepth()
    local channel_count = decoder:getChannelCount()

    self._loop_start = 0 -- in seconds
    self._loop_end = decoder:getDuration()
    self._decoder = decoder -- love.audio.Decoder
    self._decoder_offset = 0 -- seconds
    self._buffer_size = buffer_size

    self._sample_rate = sample_rate
    self._bit_depth = bit_depth
    self._channel_count = channel_count
    self._native = love.audio.newQueueableSource(
        sample_rate,
        bit_depth,
        channel_count,
        rt.settings.music_manager_playback.n_buffers
    )
    self._is_player = false
end

--- @brief
function rt.MusicManagerPlayback._merge_sound_data(first_chunk, second_chunk, first_samples)
    assert(first_chunk:getSampleCount() == second_chunk:getSampleCount()
        and first_chunk:getSampleRate() == second_chunk:getSampleRate()
        and first_chunk:getBitDepth() == second_chunk:getBitDepth()
        and first_chunk:getChannelCount() == second_chunk:getChannelCount(),
        "in rt.QueueableSource._merge_sound_data: chunks are incompatible"
    )

    if first_samples >= first_chunk:getSampleCount() then return first_chunk end

    local total_samples = first_chunk:getSampleCount()
    local sample_rate = first_chunk:getSampleRate()
    local bit_depth = first_chunk:getBitDepth()
    local n_channels = first_chunk:getChannelCount()

    assert(bit_depth == 8 or bit_depth == 16, "Unsupported bit depth in _merge_sound_data")

    local samples_per_channel = total_samples / n_channels
    local merged_chunk = love.sound.newSoundData(samples_per_channel, sample_rate, bit_depth, n_channels)

    local sample_t = ternary(bit_depth == 16, "int16_t", "uint8_t")
    local sample_size = ffi.sizeof(sample_t)

    local first_ptr = ffi.cast(sample_t .. "*", first_chunk:getFFIPointer())
    local second_ptr = ffi.cast(sample_t .. "*", second_chunk:getFFIPointer())
    local merged_ptr = ffi.cast(sample_t .. "*", merged_chunk:getFFIPointer())

    if first_samples > 0 then
        ffi.copy(merged_ptr, first_ptr, first_samples * sample_size)
    end

    local second_samples = total_samples - first_samples
    if second_samples > 0 then
        ffi.copy(merged_ptr + first_samples, second_ptr, second_samples * sample_size)
    end

    return merged_chunk
end

--- @brief Updates the playback state and handles looping.
function rt.MusicManagerPlayback:update(_)
    assert(meta.is_nil(_), "In rt.MusicManagerPlayback.update: update should be called without time parameter")

    for i = 1, self._native:getFreeBufferCount() do
        self._decoder_offset = math.clamp(self._decoder_offset, 0, self._decoder:getDuration())

        self._decoder:seek(self._decoder_offset)
        local chunk = self._decoder:decode()
        local chunk_length = chunk:getSampleCount() / chunk:getSampleRate()

        if self._decoder_offset + chunk_length >= self._loop_end then
            local old_chunk = chunk

            -- get chunk at start of loop
            self._decoder:seek(self._loop_start)
            local new_chunk = self._decoder:decode()

            local old_chunk_section_length = (self._loop_end - self._decoder_offset)
            local new_chunk_section_length = chunk_length - old_chunk_section_length

            local old_chunk_samples_per_channel = math.floor(old_chunk_section_length * chunk:getSampleRate())
            local new_chunk_samples_per_channel = math.floor(new_chunk_section_length * chunk:getSampleRate())

            -- take samples from now until end of loop, merge with
            -- samples from start of loop until chunksize is filled
            local merged_chunk = self._merge_sound_data(
                old_chunk,
                new_chunk,
                old_chunk_samples_per_channel
            )

            self._native:queue(merged_chunk)
            self._decoder_offset = self._loop_start + new_chunk_section_length
        else
            self._native:queue(chunk)
            self._decoder_offset = self._decoder_offset + chunk_length
        end
    end

    if self._is_playing and not self._native:isPlaying() then
        self._native:play()
    end
end

--- @brief
function rt.MusicManagerPlayback:set_loop_bounds(start_time, end_time)
    meta.assert(start_time, "Number", start_time, "Number")

    start_time = math.max(start_time, 0)
    end_time = math.clamp(end_time, 0, self._decoder:getDuration())
    self._loop_start = start_time
    self._loop_end = end_time
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
function rt.MusicManagerPlayback:set_loop(from, to)
    self._loop_start = math.clamp(from, 0, self._decoder:getDuration())
    self._loop_end = math.clamp(to, 0, self._decoder:getDuration())
end

--- @brief
function rt.MusicManagerPlayback:play()
    self._is_playing = true
end

--- @brief
function rt.MusicManagerPlayback:pause()
    self._is_playing = false
end
