return {
    air_dash_duration = 5 / 60,
    air_dash_velocity = 1200,

    sdf = function(x, y, px, py, radius)

        if x < px then x = px - math.abs(px - x) end
        if y < py then y = py - math.abs(py - y) end

        local r = 4 * 12
        local dist = math.distance(x, y, px, py)
        local t = dist / r
        local t_scaled = t * 2
        local base_value = (1 - t_scaled * t_scaled) * math.exp(-t_scaled * t_scaled / 2) * 3

        -- Add 2D sine wave pattern based on absolute position
        local sine_start = r * 0.2
        local sine_peak = r * 1
        local sine_end = r * 3.0
        local offset = rt.SceneManager:get_elapsed() * 3

        local offset_envelope = math.min(t^2, 1)
        offset = offset * ternary(x < px, -1, 1)

        local value = base_value


        if dist > sine_start then
            local frequency = 1 / 5
            local sine_wave = math.sin(x * frequency + offset) * math.cos(y * frequency)

            local ramp_up = math.min(1, (dist - sine_start) / (sine_peak - sine_start))
            local decay = math.exp(-(dist - sine_peak) / (sine_end - sine_peak))
            local envelope = ramp_up * decay

            local sine_amplitude = envelope * (1 - 1 + offset_envelope)
            sine_wave = (sine_wave + 1) / 2

            local sine_r = 0.5 * radius
            local sine_t = math.clamp(math.min(math.abs(x - px) / sine_r, math.abs(y - py) / sine_r), 0, 1)
            value = 0.5 * (value + 1) + sine_wave * sine_amplitude * math.min(sine_t, offset_envelope) --value + (1 - value) * 0.5 * sine_wave * sine_amplitude
        end


        return value / 2
    end
}
