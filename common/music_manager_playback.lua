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
    self._offset = 1 -- in samples per channel (1 based)

    local size_mb = (self._data:getSampleCount() * self._data:getChannelCount()) * (self._data:getBitDepth() / 8) / (1024 * 1024)
    size_mb = math.ceil(size_mb * 1000) / 1000
    rt.log("In rt.MusicManager: allocating " .. size_mb .. " mb for music at `" .. path .. "`")

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
function rt.MusicManagerPlayback:_copy_to_chunk(data_start_i, chunk_start_i, n_samples)
    --[[
    n_samples = math.min(n_samples, self._chunk:getSampleCount() - chunk_start_i)
    for offset = 0, n_samples - 1 do
        for channel_i = 1, self._chunk:getChannelCount() do
            self._chunk:setSample(
                chunk_start_i + offset,
                channel_i,
                self._data:getSample(data_start_i + offset, channel_i)
            )
        end
    end
    ]]--

    n_samples = math.min(n_samples,
        self._chunk:getSampleCount() - chunk_start_i,
        self._data:getSampleCount() - data_start_i
    )

    local sample_size = self._bit_depth / 8  -- bytes per sample
    local channel_count = self._channel_count

    local data_typed = ffi.cast(self._sample_t .. "*", self._data:getFFIPointer())
    local chunk_typed = ffi.cast(self._sample_t .. "*", self._chunk:getFFIPointer())

    local source_offset = data_start_i * channel_count
    local destination_offset = chunk_start_i * channel_count
    local n_bytes = n_samples * channel_count

    ffi.copy(
        chunk_typed + destination_offset, -- destination
        data_typed + source_offset, -- source
        n_bytes * sample_size -- n bytes to copy
    )
end

--- @brief
function rt.MusicManagerPlayback:update(_)
    local n_samples_per_chunk = self._chunk:getSampleCount()
    if self._is_playing then
        for _ = 1, self._native:getFreeBufferCount() do

            if self._offset > self._loop_end then
                -- sanity check, this should never be able to trigger, cut to loop end
                rt.critical("In rt.MusicManager: unreachable reached")
                self._offset = self._loop_end - n_samples_per_chunk + 2
            end

            if self._offset + n_samples_per_chunk > self._loop_end then
                self._offset = math.min(self._offset, self._loop_end)
                local n_samples_until_loop_end = self._loop_end - self._offset

                -- fill chunk with current data until end of loop
                if n_samples_until_loop_end > 0 then
                    self:_copy_to_chunk(
                        self._offset,
                        0,
                        n_samples_until_loop_end
                    )
                end

                -- fill remaining chunk with samples from start of loop
                local n_samples_from_loop_start = n_samples_per_chunk - n_samples_until_loop_end
                if n_samples_from_loop_start > 0 then
                    self:_copy_to_chunk(
                        self._loop_start,
                        n_samples_until_loop_end,
                        n_samples_from_loop_start
                    )
                end

                self._native:queue(self._chunk)
                self._offset = self._loop_start + n_samples_from_loop_start
            else
                self:_copy_to_chunk(self._offset, 0, n_samples_per_chunk)
                self._native:queue(self._chunk)
                self._offset = self._offset + n_samples_per_chunk
            end
        end

        self._native:play()
    end
end

function rt.MusicManagerPlayback:_seconds_to_total_samples(seconds)
    return math.floor(seconds * self._sample_rate)
end

function rt.MusicManagerPlayback:_total_samples_to_seconds(total_samples)
    return total_samples / self._sample_rate
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
    self._offset = 1
end
