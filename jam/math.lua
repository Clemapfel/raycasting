math_pi = 3.141592653589793
math_tau = 6.283185307179586
math_eps = 1e-6

math_wrap = function(x, n)
    return (x - 1) % n + 1
end

math_cross = function(ax, ay, bx, by)
    return ax * by - ay * bx
end

math_dot = function(ax, ay, bx, by)
    return ax * bx + ay * by
end

local _g_sqrt = _G.math.sqrt
math_magnitude = function(ax, ay)
    return _g_sqrt(ax * ax + ay * ay)
end

math_distance = function(ax, ay, bx, by)
    return math_magnitude(bx - ax, by - ay)
end

math_normalize = function(x, y)
    local m = math_magnitude(x, y)
    if m == 0 then
        return 0, 0
    end
    return x / m, y / m
end

math_mix = function(a, b, t)
    return a * (1 - t) + b * t
end

math_clamp = function(x, lower, upper)
    if x < lower then
        return lower
    elseif x > upper then
        return upper
    else
        return x
    end
end

math_fract = function(x)
    return x % 1
end

math_linlin = function(from_a, from_b, to_a, to_b, t)
    if t <= from_a then return to_a end
    if t >= from_b then return to_b end
    return (t - from_a) / (from_b - from_a) * (to_b - to_a) + to_a
end

local _g_sin = _G.math.sin
math_sin = function(x)
    return _g_sin(x)
end

local _g_cos = _G.math.cos
math_cos = function(x)
    return _g_cos(x)
end

local _g_rad = _G.math.rad
math_degree_to_radians = function(x)
    return _g_rad(x)
end

local _g_deg = _G.math.deg
math_radians_to_degree = function(x)
    return _g_deg(x)
end

local _g_log = _G.math.log
math_log = function(x, base)
    return _g_log(x, base)
end

math_ln = function(x)
    return _g_log(x)
end

local _g_log10 = _G.math.log10
math_log10 = function(x)
    return _g_log10(x)
end

local _g_min = _G.math.min
math_min = function(...)
    return _g_min(...)
end

local _g_max = _G.math.max
math_max = function(...)
    return _g_max(...)
end

local _g_floor = _G.math.floor
math_floor = function(x)
    return _g_floor(x)
end

local _g_ceil = _G.math.ceil
math_ceil = function(x)
    return _g_ceil(x)
end

math_round = function(x)
    return x + 0.5 - (x + 0.5) % 1
end

local _g_abs = _G.math.abs
math_equals = function(a, b, eps)
    if eps == nil then eps = 0 end
    return _g_abs(a - b) <= eps
end

math_not_equals = function(a, b, eps)
    if eps == nil then eps = 0 end
    return _g_abs(a - b) > eps
end

math_less_than = function(a, b, eps)
    if eps == nil then eps = 0 end
    return a < b - eps
end

math_greater_than = function(a, b, eps)
    if eps == nil then eps = 0 end
    return a > b + eps
end

math_less_than_or_equal = function(a, b, eps)
    if eps == nil then eps = 0 end
    return a <= b + eps
end

math_greater_than_or_equal = function(a, b, eps)
    if eps == nil then eps = 0 end
    return a >= b - eps
end

math_is_nan = function(x)
    return x ~= x
end

math_sign = function(x)
    if x < 0 then
        return -1
    elseif x > 0 then
        return 1
    else
        return 0
    end
end

math_sqrt = math.sqrt

do
    local _g_atan2 = math.atan2
    local _g_atan = math.atan
    local _pi = math.pi

    local _atan2_available = _g_atan ~= nil and _g_atan(0, -1) == _pi

    if _g_atan2 ~= nil then
        math_angle = function(x, y)
            return _g_atan2(y, x)
        end
    elseif _atan2_available then
        math_angle = function(x, y)
            return _g_atan(y, x)
        end
    else
        math_angle = function(x, y)
            if x > 0 then
                return _g_atan(y / x)
            elseif x < 0 then
                if y >= 0 then
                    return _g_atan(y / x) + _pi
                else
                    return _g_atan(y / x) - _pi
                end
            else -- x == 0
                if y > 0 then
                    return _pi / 2
                elseif y < 0 then
                    return -_pi / 2
                else
                    return 0
                end
            end
        end
    end
end

math_divide_ints = function(x, y)
    local q = x / y
    if q >= 0 then
        return math_floor(q)
    else
        return math_ceil(q)
    end
end

local _g_huge = _G.math.huge
math_is_inf = function(x)
    return _g_abs(x) == _g_huge
end

math_inf = _g_huge
math_positive_inf = _g_huge
math_negative_inf = -1 * _g_huge