rt.settings.audio_processor = {
    window_size = 2^12, --2^13,
    export_prefix = "audio"
}

--- @brief efficiently compute fourier transform of bytedata
function rt.AudioProcessorTransform(ft, window_size)
    local out = {}
    out.ft = ft
    out.window_size = window_size
    out.fourier_normalize_factor = 1 / math.sqrt(window_size)

    out.fftw_real = ft._alloc_real(window_size)
    out.fftw_complex = ft._alloc_complex(window_size)
    out.plan_signal_to_spectrum = ft._plan_dft_r2c_1d(
        window_size,
        out.fftw_real,
        out.fftw_complex,
        ft._plan_mode
    )

    out.plan_spectrum_to_signal = ft._plan_dft_c2r_1d(
        window_size,
        out.fftw_complex,
        out.fftw_real,
        ft._plan_mode
    )

    --- @param data love.ByteData<double>
    --- @param offset Number
    --- @return love.ByteData<double>, love.ByteData<double>
    function out:signal_to_spectrum(data, offset)

        local data_ptr = ffi.cast(self.ft._real_data_t, data:getFFIPointer())
        local from = ffi.cast(self.ft._real_data_t, self.fftw_real)

        local i = 0
        local data_n = data:getSize() / ffi.sizeof("double")

        if offset + self.window_size <= data_n then
            ffi.copy(from, data_ptr + offset, self.window_size * ffi.sizeof("double"))
        else
            local n_pushed = 0
            while i < self.window_size and offset + i < data_n do
                ffi.cast("double*", from)[i] = ffi.cast("double*", data_ptr)[offset + i]
                i = i + 1
                n_pushed = n_pushed + 1
            end

            -- backfill with 0s
            while n_pushed < self.window_size do
                ffi.cast("double*", from)[i] = 0
                i = i + 1
                n_pushed = n_pushed + 1
            end
        end

        self.ft._execute(self.plan_signal_to_spectrum)

        -- convert complex to magnitude, also take first half only and flip
        local to = ffi.cast(self.ft._complex_data_t, self.fftw_complex)
        local half = math.floor(0.5 * self.window_size)
        local normalize_factor = self.fourier_normalize_factor

        local magnitude_out = {}
        local min = POSITIVE_INFINITY
        local max = NEGATIVE_INFINITY
        local sum = 0
        for i = 1, half do
            local complex = ffi.cast(self.ft._complex_t, to[half - i - 1 - 1])
            local magnitude = rt.magnitude(complex[0], complex[1])
            magnitude = magnitude * normalize_factor -- project into [0, 1]
            min = math.min(min, magnitude)
            max = math.max(max, magnitude)
            sum = sum + magnitude
            table.insert(magnitude_out, magnitude)
        end

        return magnitude_out, min, max, sum
    end

    --- @param magnitude love.ByteData<double>
    --- @param phase_angle love.ByteData<double>
    --- @return Table<Number>
    function out:spectrum_to_signal(magnitude, phase_angle)
        rt.error("UNTESTED")
        local from_magnitude = ffi.cast("double*", magnitude:getFFIPointer())
        local from_angle = ffi.cast("double*", phase_angle:getFFIPointer())

        local from = ffi.cast(self.ft._complex_data_t, self.fftw_complex)

        -- convert magnitude / phase angle to complex
        local half = math.floor(0.5 * self.window_size)
        local normalize_factor = 1 / self.fourier_normalize_factor
        for i = 1, half do
            local re, im = rt.to_polar(
                from_magnitude[i-1] * normalize_factor,
                from_angle[i-1]
            )

            for complex in range(
                ffi.cast(self.ft._complex_t, from[half - i - 1]),
                ffi.cast(self.ft._complex_t, from[self.window_size  - half - i - 1]))
            do
                complex[0] = re
                complex[1] = im
            end
        end

        self.ft._execute(self.plan_spectrum_to_signal)

        local to = ffi.cast(self.ft._real_data_t, self.fftw_real)
        local out = love.data.newByteData(window_size * ffi.sizeof("double"))
        ffi.copy(to, out, window_size * ffi.sizeof("double"))
        return out
    end

    return out
end

--- @class rt.AudioProcessor
--- @signal update (self, Table<Number>) -> nil
rt.AudioProcessor = meta.new_type("AudioProcessor", rt.SignalEmitter, function(id, path)
    local data = love.sound.newSoundData(path .. "/" .. id)
    local window_size = rt.settings.audio_processor.window_size
    local out = meta.new(rt.AudioProcessor, {
        _id = id,
        _data = data,
        _signal = {},   -- love.ByteData<double>
        _source = love.audio.newQueueableSource(
            data:getSampleRate(),
            data:getBitDepth(),
            data:getChannelCount(),
            3
        ),
        _playing = false,
        _buffer_offset = 0,     -- position of already queued buffers
        _playing_offset = 0,    -- position of currently playing sample
        _last_update = -1,
        _n_transformed = 0,       -- number of samples processing by fourier transform
        _window_size = window_size,
        _is_mono = data:getChannelCount() == 1,

        on_update = nil
    })

    if data:getChannelCount() > 2 then
        rt.error("In rt.AudioProcessor: audio file at `" .. path .. "` is neither mono nor stereo, more than 2 channels are not supported")
    end

    out:_initialize_data()

    out:signal_add("update")
    return out
end)

rt.AudioProcessor.ft = rt.FourierTransform()
rt.AudioProcessor.transform = rt.AudioProcessorTransform(rt.AudioProcessor.ft, rt.settings.audio_processor.window_size)
rt.AudioProcessor._log_once = true

--- @brief [internal] pre-compute mono version of signal as C-doubles, to be used with fftw
function rt.AudioProcessor:_initialize_data()

    -- store computed version on disk to avoid doing the work every time
    local prefix = rt.settings.audio_processor.export_prefix
    if love.filesystem.getInfo(prefix) == nil then
        love.filesystem.createDirectory(prefix)
    end

    local export_path = prefix .. "/" .. self._id .. ""
    local info = love.filesystem.getInfo(export_path)

    if not meta.is_nil(info) then
        self._signal = love.data.newByteData(love.filesystem.read(export_path))
        self._signal_size = self._signal:getSize() / ffi.sizeof("double")
        return
    end

    if self._log_once then
        rt.log("[rt][INFO] In rt.AudioProcessor:_initialize_data: Exporting `" .. self._id .. "` to `" .. export_path .. "`")
    end

    -- cf. https://github.com/love2d/love/blob/main/src/modules/sound/wrap_SoundData.lua#L41
    local n_channels = self._data:getChannelCount()
    local n_samples = self._data:getSampleCount() / n_channels
    local bit_depth = self._data:getBitDepth()
    local sample_t = ternary(bit_depth == 16, "int16_t", "uint8_t")

    -- project into [-1, 1]
    local normalize = function(x)
        if bit_depth == 8 then
            return (x - 2^8) / (2^8 - 1)
        elseif bit_depth == 16 then
            return x / (2^16 / 2 - 1)
        end
    end

    if n_channels == 2 then
        self._signal = love.data.newByteData(n_samples / 2 * ffi.sizeof("double"))
        local data_in = ffi.cast(sample_t .. "*", self._data:getFFIPointer())
        local data_out = ffi.cast("double*", self._signal:getFFIPointer())
        for i = 0, n_samples - 2, 2 do
            local left = normalize(data_in[i + 0])
            local right = normalize(data_in[i + 1])
            data_out[i / 2] = ffi.cast("double", (left + right) / 2)
        end
    else
        self._signal = love.data.newByteData(n_samples * ffi.sizeof("double"))
        local data_in = ffi.cast(sample_t .. "*", self._data:getFFIPointer())
        local data_out = ffi.cast("double*", self._signal:getFFIPointer())
        for i = 0, n_samples - 1, 1 do
            data_out[i] = ffi.cast("double", normalize(data_in[i]))
        end
    end
    self._signal_size = self._signal:getSize() / ffi.sizeof("double")

    -- export
    local res = love.filesystem.write(export_path, self._signal:getString())
end

--- @brief
function rt.AudioProcessor:start()
    self._playing = true
end

--- @brief
function rt.AudioProcessor:stop()
    self._playing = false
end

local once = false

--- @brief
function rt.AudioProcessor:update()
    if self._source:getFreeBufferCount() > 0 then
        local sample_t = ternary(self._data:getBitDepth() == 16, "int16_t", "uint8_t")
        local data_n = self._data:getSize() / ffi.sizeof(sample_t)
        local n_samples_to_push = math.min(self._window_size, math.abs(data_n - self._buffer_offset))
        assert(self._source:queue(
            self._data:getPointer(),
            self._buffer_offset,
            n_samples_to_push,
            self._data:getSampleRate(),
            self._data:getBitDepth(),
            self._data:getChannelCount()
        ))

        self._source:play()
        self._playing = true
        self._last_update = love.timer.getDelta()
        self._buffer_offset = self._buffer_offset + n_samples_to_push
    end

    if self._playing then
        local previous = self._last_update
        self._last_update = love.timer.getDelta()
        local delta = self._last_update - previous
        self._playing_offset = self._playing_offset + self._last_update * self._data:getSampleRate()

        while self._n_transformed <= self._playing_offset do
            if self.on_update ~= nil then
                self.on_update(self.transform:signal_to_spectrum(self._signal, self._n_transformed))
            end
            self._n_transformed = self._n_transformed + self._window_size
        end
    end
    self._last_update = love.timer.getTime()
end


