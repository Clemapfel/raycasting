math_pi = 3.141592653589793
math_tau = 6.283185307179586
math_eps = 1.1920928955078125e-07

math_wrap = function(x, n)
    log_assert(x, Number_t, n, Number_t)
    return x % n + 1
end

math_cross = function(ax, ay, bx, by)
    log_assert(ax, Number_t, ay, Number_t, bx, Number_t, by, Number_t)
    return ax * by - ay * bx
end

math_dot = function(ax, ay, bx, by)
    log_assert(ax, Number_t, ay, Number_t, bx, Number_t, by, Number_t)
    return ax * bx + ay * by
end

math_magnitude = function(ax, ay)
    log_assert(ax, Number_t, ay, Number_t)
    return math.sqrt(ax * ax + ay * ay)
end

math_distance = function(ax, ay, bx, by)
    log_assert(ax, Number_t, ay, Number_t, bx, Number_t, by, Number_t)
    return math_magnitude(bx - ax, by - ay)
end

math_normalize = function(x, y)
    log_assert(x, Number_t, y, Number_t)
    local m = math_magnitude(x, y)
    if m == 0 then
        return 0, 0
    end
    return x / m, y / m
end

math_mix = function(a, b, t)
    log_assert(a, Number_t, b, Number_t, t, Number_t)
    return a * (1 - t) + b * t
end

math_linlin = function(from_a, from_b, to_a, to_b, t)
    log_assert(from_a, Number_t, from_b, Number_t, to_a, Number_t, to_b, Number_t, t, Number_t)
    if t <= from_a then return to_a end
    if t >= from_b then return to_b end
    return (t - from_a) / (from_b - from_a) * (to_b - to_a) + to_a
end

math_sin = function(x)
    log_assert(x, Number_t)
    return math.sin(x)
end

math_cos = function(x)
    log_assert(x, Number_t)
    return math.cos(x)
end

math_degree_to_radians = function(x)
    log_assert(x, Number_t)
    return math.rad(x)
end

math_radians_to_degree = function(x)
    log_assert(x, Number_t)
    return math.deg(x)
end

math_log = math.log
math_ln = math.log
math_log10 = math.log10

math_min = math.min
math_max = math.max
math_floor = math.floor
math_ceil = math.ceil
math_round = function(x)
    return x + 0.5 - (x + 0.5) % 1
end