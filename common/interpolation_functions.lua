--- @class rt.InterpolationFunction
rt.InterpolationFunctions = meta.enum("InterpolationFunction", {
    CONSTANT_ZERO = function(x)
        return 0
    end,

    CONSTANT = function(x)
        return 1
    end,

    LINEAR = function(x, slope)
        -- ax
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        if slope == nil then slope = 1 end
        return slope * x
    end,

    LINEAR_BANDPASS = function(x)
        -- 1\ -\operatorname{abs}\left(2\left(x-0.5\right)\right)
        if x >= 1 then return 0 elseif x <= 0 then return 0 end
        return 1 - math.abs(2 * (x - 0.5))
    end,

    SINUSOID_EASE_IN = function(x)
        -- -1\ \cdot\ \cos\left(x\ \cdot\left(\frac{\pi}{2}\right)\right)+1
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        return -1.0 * math.cos(x * (math.pi / 2)) + 1.0;
    end,

    SINUSOID_EASE_OUT = function(x)
        -- \sin\left(x\cdot\left(\frac{\pi}{2}\right)\right)
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        return math.sin(x * (math.pi / 2))
    end,

    SINUSOID_EASE_IN_OUT = function(x)
        -- -0.5\ \cdot\cos\left(\pi\ \cdot x\right)+0.5
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        return -0.5 * math.cos(math.pi * x) + 0.5
    end,

    EXPONENTIAL_ACCELERATION = function(x)
        -- 0.045\cdot e^{\ln\left(\frac{1}{0.045}+1\right)x}-0.045
        -- if x <= 0 then return 0 end
        return 0.045 * math.exp(math.log(1 / 0.045 + 1) * x) - 0.045
    end,

    EXPONENTIAL_DECELERATION = function(x)
        -- 0.045\cdot e^{\ln\left(\frac{1}{0.045}+1\right)\left(-x+1\right)}-0.045
        if x >= 1 then return 0 end
        return 0.045 * math.exp(math.log(1 / 0.045 + 1) * (-1 * x + 1)) - 0.045
    end,

    SQUARE_ACCELERATION = function(x, n)
        -- x^{2}
        if x <= 0 then return 0 end
        if n == nil then n = 2 end
        return x^n
    end,

    SQUARE_DECELERATION = function(x, n)
        -- \left(x-1\right)^{2}
        if x >= 1 then return 0 end
        if n == nil then n = 2 end
        return (x - 1)^n
    end,

    SIGMOID = function(x, k)
        -- \frac{\tanh\left(k\left(x-0.5\right)\right)}{2}+0.5
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        if k == nil then k = 9 end
        return math.tanh(k * (x - 0.5)) / 2 + 0.5
    end,

    SIGMOID_HOLD = function(x)
        -- 4\left(x-0.5\right)^{3}+0.5
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        return 4 * (x - 0.5)^3 + 0.5
    end,

    HANN = function(x)
        -- \frac{-\cos\left(-2\pi x\right)}{2}+0.5
        if x >= 1 then return 0 elseif x <= 0 then return 0 end
        return (-1 * math.cos(-2 * math.pi * x) + 1) / 2
    end,

    HANN_HIGHPASS = function(x)
        -- \frac{-\cos\left(-\pi x\right)}{2}+0.5
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        return -1 * math.cos(-math.pi * x) / 2 + 0.5
    end,

    HANN_LOWPASS = function(x)
        -- \frac{\cos\left(-\pi x\right)}{2}+0.5
        if x >= 1 then return 0 elseif x <= 0 then return 1 end
        return math.cos(-math.pi * x) / 2 + 0.5
    end,

    GAUSSIAN = function(x)
        -- e^{-\left(4.4\cdot\frac{\pi}{3}\right)\left(2x-1\right)^{2}}
        if x >= 1 then return 0 elseif x <= 0 then return 0 end
        return math.exp(-1 * ((4.4 * math.pi / 3) * (2 * x - 1))^2)
    end,

    GAUSSIAN_HIGHPASS = function(x)
        -- e^{-4.4\frac{\pi}{3}\left(x-1\right)^{2}}
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        return math.exp(-1 * ((4.4 * math.pi / 3) * (x - 1))^2)
    end,

    GAUSSIAN_LOWPASS = function(x)
        -- e^{-4.4\frac{\pi}{3}\left(-x\right)^{2}}
        if x >= 1 then return 0 elseif x <= 0 then return 1 end
        return math.exp(-4.4 * math.pi / 3 * (-1 * x)^2)
    end,

    DISCONTINUOUS_DIRAC = function(x)
        local a = 0.045 * math.exp(math.log(1 / 0.045 + 1) * x) - 0.045
        local b = 0.045 * math.exp(math.log(1 / 0.045 + 1) * (1 - x)) - 0.045
        local t = 5.81894409826698685315796808094
        return t * math.min(a, b)
    end,

    BUTTERWORTH = function(x, order)
        if x >= 1 then return 0 elseif x <= 0 then return 0 end
        if order == nil then order = 6 end
        if order % 2 ~= 0 then order = order + 1 end
        -- \frac{1}{\left(1+\left(4\left(x-0.5\right)\right)^{6}\right)}
        return 1 / (1 + (4 * (x - 0.5))^order)
    end,

    BUTTERWORTH_LOWPASS = function(x, order)
        if x >= 1 then return 0 elseif x <= 0 then return 1 end
        if order == nil then order = 6 end
        if order % 2 ~= 0 then order = order + 1 end
        -- \frac{1}{\left(1+\left(3x\right)^{n}\right)}
        return 1 / (1 + (3 * x)^order)
    end,

    BUTTERWORTH_HIGHPASS = function(x, order)
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        if order == nil then order = 6 end
        if order % 2 ~= 0 then order = order + 1 end
        -- \frac{1}{\left(1+\left(3(x-1)\right)^{n}\right)}
        return 1 / (1 + (3 * (x - 1))^order)
    end,

    STEPS = function(x, n_steps)
        -- \frac{\operatorname{floor}\left(4\cdot x+0.5\right)}{4}
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        if n_steps == nil then n_steps = 3 end
        return math.floor(n_steps * x + 0.5) / n_steps
    end,

    DERIVATIVE_OF_GAUSSIAN_EASE_OUT = function(x)
        if x >= 1 then return 0 elseif x <= 0 then return 0 end
        -- \left(\left(e^{-\frac{x}{n}^{2}}\cdot\sin\left(\frac{x}{n}\right)\right)2\pi\cdot n\right)
        local n = 0.4
        return math.exp(-((x / n) ^ 2)) * math.sin(x / n) * 2 * math.pi * n
    end,

    DERIVATIVE_OF_GAUSSIAN_EASE_IN = function(x)
        if x >= 1 then return 0 elseif x <= 0 then return 0 end
        -- 1-\left(\left(e^{-\frac{\left(x-1\right)}{n}^{2}}\cdot\sin\left(\frac{\left(x-1\right)}{n}\right)\right)2\pi\cdot n\right)-1
        return 1 - rt.InterpolationFunctions.DERIVATIVE_OF_GAUSSIAN_EASE_OUT(x - 1) - 1
    end,

    CONTINUOUS_STEP = function(x, n_steps, smoothness)
        -- https://www.desmos.com/calculator/ggoaqtlh7c
        if n_steps == nil then n_steps = 3 end
        if smoothness == nil then smoothness = 11.5 end
        local a, h = smoothness, ternary(n_steps > 0, 1 / n_steps, 2)
        return h * ((math.tanh((a * x / h) - a * math.floor(x / h) - a / 2) / (2 * math.tanh(a / 2)) + 0.5 + math.floor(x / h)))
    end,

    SHELF = function(x, shelf_width, order)
        -- https://www.desmos.com/calculator/zxo1os3qen
        if x >= 1 then return 0 elseif x <= 0 then return 0 end
        if shelf_width == nil then shelf_width = 0.5 end
        shelf_width = clamp(shelf_width, 0, 1)
        if order == nil then order = 6 end
        if order % 2 ~= 0 then order = order + 1 end
        return 1 - math.tanh(math.pow(2 * ((x - 0.5) / shelf_width), order))
    end,

    SHELF_EASE_OUT = function(x, k)
        -- \tanh\left(k\left(x-1\right)\right)^{2}
        if x <= 0 then return 1 elseif x >= 1 then return 0 end
        if k == nil then k = 6.5 end
        return math.tanh(k * (x - 1))^2
    end,

    SHELF_EASE_IN = function(x, k)
        -- \tanh\left(k\left(x\right)\right)^{2}
        if x <= 0 then return 0 elseif x >= 1 then return 1 end
        if k == nil then k = 6.5 end
        return math.tanh(k * (x - 1))^2
    end,

    SINE_WAVE = function(x, frequency)
        -- \frac{\cos\left(3\pi\left(bx-1\right)\right)}{2}+0.5
        if frequency == nil then frequency = 2 end
        return (math.cos(frequency * math.pi * (2 * x + 1)) + 1) / 2
    end,

    INVERTED_SINE_WAVE = function(x, frequency)
        return 1 - rt.InterpolationFunctions.SINE_WAVE(x, frequency)
    end,

    TRIANGLE_WAVE = function(x, frequency)
        -- 2\cdot\left|\frac{x}{f}-\operatorname{floor}\left(\frac{x}{f}+0.5\right)\right|
        if frequency == nil then frequency = 2 end
        return 2 * math.abs(frequency * x - math.floor(frequency * x + 0.5))
    end,

    SQUARE_WAVE = function(x, frequency)
        -- \frac{\operatorname{sign}\left(\sin\left(\pi fx\right)\right)}{2}+0.5
        if frequency == nil then frequency = 2 end
        return math.sign(math.sin(math.pi * frequency * x)) / 2 + 0.5
    end,

    CUBE_EASE_OUT = function(x, order)
        -- \left(x-1\right)^{3}+1
        if x >= 1 then return 1 elseif x <= 0 then return 0 end
        if order == nil then order = 1 end
        return (x - 1)^(2 * order + 1) + 1
    end,

    SQUARE_ROOT_INFLECTION = function(x)
        if x <= 0 then return 0 elseif x >= 1 then return 1 end
        if x < 0.5 then
            -- -\sqrt{-0.5\left(x-0.5\right)}+0.5
            return -1 * math.sqrt(-0.5 * (x - 0.5)) + 0.5
        else
            -- \sqrt{\left(0.5\left(x-0.5\right)\right)}+0.5
            return math.sqrt(0.5 * (x - 0.5)) + 0.5
        end
    end,

    FRACTIONAL_ROOT_ACCELERATION = function(x, fraction)
        if x <= 0 then return 0 elseif x >= 1 then return 1 end

        -- x^{t}
        if fraction == nil then
            fraction = 0.5
        else
            if fraction <= 0 then
                fraction = math.eps
            elseif fraction > 1 then
                fraction = 1
            end
        end

        if fraction == 0.5 then return math.sqrt(x) else return x^fraction end
    end,

    FRACTIONAL_ROOT_DELECERATION = function(x, fraction)
        if x <= 0 then return 1 elseif x >= 1 then return 0 end

        -- \left(1-x\right)^{t}
        if fraction == nil then
            fraction = 0.5
        else
            if fraction <= 0 then
                fraction = math.eps
            elseif fraction > 1 then
                fraction = 1
            end
        end

        if fraction == 0.5 then return math.sqrt(1 - x) else return (1 - x)^fraction end
    end,

    PARABOLA_BANDPASS = function(x)
        -- 1-\left(2\left(x-0.5\right)\right)^{2}
        if x < 0 then return 0 elseif x > 1 then return 0 end
        return 1 - (2 * (x - 0.5))^2
    end,

    ENVELOPE = function(x, attack_fraction, sustain_fraction)
        -- piecewise gaussian with optional sustain, peak at 1
        if attack_fraction == nil then attack_fraction = 0.5 end
        if sustain_fraction == nil then sustain_fraction = 0 end
        if x < 0 or x > 1 then return 0 end

        local total_non_decay = attack_fraction + sustain_fraction
        if total_non_decay > 1 then
            local scale = 1 / total_non_decay
            attack_fraction = attack_fraction * scale
            sustain_fraction = sustain_fraction * scale
        end

        local function gaussian(x, center)
            return math.exp(-4.4 * math.pi / 3 * ((x - center)^2))
        end

        local decay_start = attack_fraction + sustain_fraction

        if x < attack_fraction then -- attack
            return gaussian(x / attack_fraction, 1)
        elseif x < decay_start then -- sustain
            return 1
        else -- decay
            return gaussian((x - decay_start) / (1 - decay_start), 0)
        end
    end
})