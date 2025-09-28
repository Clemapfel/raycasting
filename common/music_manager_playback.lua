require "common.audio_time_unit"

rt.settings.music_manager_playback = {
    n_samples_per_chunk = 2^12,
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

    self._data = love.sound.newSoundData(path)
    self._offset = 1 -- in samples per channel

    self._buffer_size = rt.settings.music_manager_playback.buffer_size
    self._sample_rate = self._data:getSampleRate()
    self._bit_depth = self._data:getBitDepth()
    self._sample_t = ternary(self._bit_depth == 8, "uint8_t", "int16_t")
    self._channel_count = self._data:getChannelCount()

    if self._loop_start == nil then
        self._loop_start = 0
    end

    if self._loop_end == nil then
        self._loop_end = self._data:getSampleCount()
    end

    self._native = love.audio.newQueueableSource(
        self._sample_rate,
        self._bit_depth,
        self._channel_count,
        rt.settings.music_manager_playback.n_buffers
    )

    -- reusable chunk
    self._chunk = love.sound.newSoundData(
        rt.settings.music_manager_playback.n_samples_per_chunk,
        self._sample_rate,
        self._bit_depth,
        self._channel_count
    )

    self._is_playing = false
end

--- @brief
function rt.MusicManagerPlayback:_copy_to_chunk(from_data, to_chunk, data_start_i, data_end_i)

--- @brief Updates the playback state and handles looping.
function rt.MusicManagerPlayback:update(_)
    local n_samples_per_chunk = rt.settings.music_manager_playback.n_samples_per_chunk
    if self._is_playing then
        for _ = 1, self._native:getFreeBufferCount() do

            -- seek by sample - convert total samples to seconds
            if self._offset + n_samples_per_chunk > self._loop_end then
                local n_samples_until_loop_end = self._loop_end - self._offset
                -- start chunk with current until end of loop
                for offset = 0, n_samples_until_loop_end do
                    for channel_i = 1, self._channel_count do
                        self._chunk:setSample(
                            offset, channel_i,
                            self._data:getSample(self._offset + offset, channel_i)
                        )
                    end
                end

                -- jump to loop start
                self._offset = self._loop_start

                -- finish chunk with samples from start of loop
                for offset = n_samples_until_loop_end, n_samples_per_chunk do
                    for channel_i = 1, self._channel_count do
                        self._chunk:setSample(
                            offset, channel_i,
                            self._data:getSample(self._offset + offset, channel_i)
                        )
                    end
                end

                -- jump to end of chunk
                self._offset = self._loop_start + (n_samples_per_chunk - n_samples_until_loop_end)
            else
                -- file chunk from sound data
                for offset = 0, n_samples_per_chunk - 1 do
                    for channel_i = 1, self._channel_count do
                        self._chunk:setSample(
                            offset, channel_i,
                            self._data:getSample(self._offset + offset, channel_i)
                        )
                    end
                end

                self._native:queue(self._chunk)
                self._offset = self._offset + self._chunk:getSampleCount()
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
    self._offset = 0
end
