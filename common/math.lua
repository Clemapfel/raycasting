if table.unpack == nil then table.unpack = unpack end
assert(table.unpack ~= nil)

if debug.setfenv == nil then debug.setfenv = setfenv end
assert(debug.setfenv ~= nil)

--- @brief clamp
--- @param x number
--- @param lower_bound number
--- @param upper_bound number
--- @return number
function math.clamp(x, lower_bound, upper_bound)
    if type(lower_bound) == "nil" then lower_bound = -math.huge end
    if type(upper_bound) == "nil" then upper_bound = math.huge end

    if x < lower_bound then
        x = lower_bound
    end

    if x > upper_bound then
        x = upper_bound
    end

    return x
end

-- Calculate cosine similarity between two 2D vectors
-- Takes 4 numbers: x1, y1, x2, y2 representing vector1(x1, y1) and vector2(x2, y2)
-- Returns a value between -1 and 1, where 1 means same direction, -1 means opposite direction
function math.cosine_similarity(x1, y1, x2, y2)
    local magnitude_a = math.magnitude2(x1, y1)
    local magnitude_b = math.magnitude2(x2, y2)

    if magnitude_a == 0 or magnitude_b == 0 then
    end

    local dot_product = math.dot2(x1, y1, x2, y2)
    return dot_product / (magnitude_a * magnitude_b)
end

--- @brief
function math.project(x, target_range_lower, target_range_upper, original_range_lower, original_range_upper)
    if original_range_lower == nil then original_range_lower = 0 end
    if original_range_upper == nil then original_range_upper = 1 end
    return ((x - original_range_lower) / (original_range_upper - original_range_lower)) * (target_range_upper - target_range_lower) + target_range_lower
end

math.radians_to_degrees = math.deg
math.degrees_to_radians = math.rad

--- @brief linear interpolate between two values
--- @param lower number
--- @param upper number
--- @param ratio number in [0, 1]
--- @return number
function math.mix1(lower, upper, ratio)
    return lower * (1 - ratio) + upper * ratio
end

function math.mix2(x1, y1, x2, y2, ratio)
    return x1 * (1 - ratio) + x2 * ratio,
    y1 * (1 - ratio) + y2 * ratio
end

function math.mix3(x1, y1, z1, x2, y2, z2, ratio)
    return x1 * (1 - ratio) + x2 * ratio,
    y1 * (1 - ratio) + y2 * ratio,
    z1 * (1 - ratio) + z2 * ratio
end

function math.mix4(x1, y1, z1, w1, x2, y2, z2, w2, ratio)
    return x1 * (1 - ratio) + x2 * ratio,
    y1 * (1 - ratio) + y2 * ratio,
    z1 * (1 - ratio) + z2 * ratio,
    w1 * (1 - ratio) + w2 * ratio
end

--- @brief
function math.mix(...)
    local n = select("#", ...)
    if n == 3 then
        return math.mix1(...)
    elseif n == 5 then
        return math.mix2(...)
    elseif n == 7 then
        return math.mix3(...)
    elseif n == 9 then
        return math.mix4(...)
    end
end

--- @brief
function math.mean(a, b)
    return (a + b) / 2
end

--- @brief project any angle into [0, 2 * math.pi]
function math.normalize_angle(angle)
    return angle - (2 * math.pi) * math.floor(angle / (2 * math.pi))
end

function math.equals(a, b, eps)
    if eps == nil then eps = 0 end
    return math.abs(a - b) <= eps
end

--- @brief
function math.mix_angles(angle_a, angle_b, ratio)
    angle_a = math.normalize_angle(angle_a)
    angle_b = math.normalize_angle(angle_b)

    local difference = angle_b - angle_a

    if difference > math.pi then
        difference = difference - 2 * math.pi
    elseif difference < -math.pi then
        difference = difference + 2 * math.pi
    end

    return math.normalize_angle(angle_a + difference * ratio)
end

--- @brief
function math.angle_distance(a, b)
    local delta = (b - a) % (2 * math.pi)
    if delta > math.pi then
        delta = delta - 2 * math.pi
    end
    return delta
end

--- @brief
function math.smoothstep(lower, upper, ratio)
    local t = math.clamp((ratio - lower) / (upper - lower), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
end

do
    math.eps = 1.0
    local n = 0
    while (1.0 + math.eps / 2.0) > 1.0 do
        math.eps = math.eps / 2.0
        n = n + 1
    end
end

math.pi2 = 2 * math.pi

--- @brief
function math.fract(x)
    return x - math.floor(x)
end

--- @brief wrap an index to always be inside 1, n
function math.wrap(index, n_elements)
    return ((index - 1) % n_elements) + 1
end

--- @brief round to nearest integer
--- @param i number
--- @return number
function math.round(x)
    return x + 0.5 - (x + 0.5) % 1
end

local function _gcd(a, b)
    if a == 0 then return b end
    if b == 0 then return a end

    local shift = 0
    while ((bit.band(a, 1) == 0) and (bit.band(b, 1) == 0)) do
        a = bit.rshift(a, 1)
        b = bit.rshift(b, 1)
        shift = shift + 1
    end

    while (bit.band(a, 1) == 0) do
        a = bit.rshift(a, 1)
    end

    repeat
        while (bit.band(b, 1) == 0) do
            b = bit.rshift(b, 1)
        end
        if a > b then
            a, b = b, a
        end
        b = b - a
    until b == 0

    return bit.lshift(a, shift)
end

--- @brief greatest common divisor
--- @param ... Number positive integers
function math.gcd(...)
    local result = math.abs(select(1, ...))
    for i = 2, select("#", ...) do
        result = _gcd(result, math.abs(select(i, ...)))
        if result == 1 then break end
    end
    return result
end

--- @brief least common multiple
function math.lcm(...)
    local n = select('#', ...)

    local result = math.abs(select(1, ...))
    if result == 0 then return 0 end

    for i = 2, n do
        local x = math.abs(select(i, ...))
        if x == 0 then
            return 0
        end
        result = math.floor((result * x) / math.gcd(result, x))
    end

    return result
end

--- @brief non-short-circuiting and
--- @param ... Boolean
function math.nand(...)
    local out = select(1, ...)
    if out == false then return false end

    for i = 2, select("#", ...) do
        if select(i, ...) == false then return false end
    end
    return out
end

--- @brief non-short-circuiting or
--- @param ... Boolean
function math.nor(...)
    local out = select(1, ...)
    for i = 2, select("#", ...) do
        out = out or select(i, ...)
    end
    return out
end

--- @brief
function math.sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

--- @brief
function math.is_nan(x)
    return x ~= x
end

--- @brief evaluate erf integral
--- @param x number
--- @return number
function math.erf(x)
    local a1 =  0.254829592
    local a2 = -0.284496736
    local a3 =  1.421413741
    local a4 = -1.453152027
    local a5 =  1.061405429
    local p  =  0.3275911

    local sign = 1
    if x < 0 then
        sign = -1
    end
    x = math.abs(x)

    local t = 1.0 / (1.0 + p * x)
    local y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x)
    return sign * y
end

--- @brief hyperbolic tangent
--- @param x number
--- @return number
function math.tanh(x)
    if x == 0 then return 0.0 end
    local neg = false
    if x < 0 then x = -x; neg = true end
    if x < 0.54930614433405 then
        local y = x * x
        x = x + x * y *
            ((-0.96437492777225469787e0 * y +
                -0.99225929672236083313e2) * y +
                -0.16134119023996228053e4) /
            (((0.10000000000000000000e1 * y +
                0.11274474380534949335e3) * y +
                0.22337720718962312926e4) * y +
                0.48402357071988688686e4)
    else
        x = math.exp(x)
        x = 1.0 - 2.0 / (x * x + 1.0)
    end
    if neg then x = -x end
    return x
end

--- @brief gamma function
function math.gamma(x)
    local p = {
        676.5203681218851, -1259.1392167224028, 771.32342877765313,
        -176.61502916214059, 12.507343278686905, -0.13857109526572012,
        9.9843695780195716e-6, 1.5056327351493116e-7
    }

    local g = 7
    if x < 0.5 then
        return math.pi / (math.sin(math.pi * x) * math.gamma(1 - x))
    end

    x = x - 1
    local a = 0.99999999999980993
    local t = x + g + 0.5
    for i = 1, #p do
        a = a + p[i] / (x + i)
    end

    return math.sqrt(2 * math.pi) * math.pow(t, x + 0.5) * math.exp(-t) * a
end

--- @brief
function math.add2(x, y, scalar_a, scalar_b)
    if scalar_b == nil then scalar_b = scalar_a end
    return x + scalar_a, y + scalar_b
end

--- @brief
function math.subtract2(x, y, scalar_a, scalar_b)
    if scalar_b == nil then scalar_b = scalar_a end
    return x - scalar_a, y - scalar_b
end

--- @brief
function math.reverse_subtract2(x, y, scalar_a, scalar_b)
    if scalar_b == nil then scalar_b = scalar_a end
    return scalar_a - x, scalar_b - y
end

--- @brief
function math.multiply2(x, y, scalar_a, scalar_b)
    if scalar_b == nil then scalar_b = scalar_a end
    return x * scalar_a, y * scalar_b
end

--- @brief
function math.divide2(x, y, scalar_a, scalar_b)
    if scalar_b == nil then scalar_b = scalar_a end
    return x / scalar_a, y / scalar_b
end

--- @brief
function math.add3(x, y, z, scalar_a, scalar_b, scalar_c)
    if scalar_b == nil then scalar_b = scalar_a end
    if scalar_c == nil then scalar_c = scalar_a end
    return x + scalar_a, y + scalar_b, z + scalar_c
end

--- @brief
function math.subtract3(x, y, z, scalar_a, scalar_b, scalar_c)
    if scalar_b == nil then scalar_b = scalar_a end
    if scalar_c == nil then scalar_c = scalar_a end
    return x - scalar_a, y - scalar_b, z - scalar_c
end

--- @brief
function math.reverse_subtract3(x, y, z, scalar_a, scalar_b, scalar_c)
    if scalar_b == nil then scalar_b = scalar_a end
    if scalar_c == nil then scalar_c = scalar_a end
    return scalar_a - x, scalar_b - y, scalar_c - z
end

--- @brief
function math.multiply3(x, y, z, scalar_a, scalar_b, scalar_c)
    if scalar_b == nil then scalar_b = scalar_a end
    if scalar_c == nil then scalar_c = scalar_a end
    return x * scalar_a, y * scalar_b, z * scalar_c
end

--- @brief
function math.divide3(x, y, z, scalar_a, scalar_b, scalar_c)
    if scalar_b == nil then scalar_b = scalar_a end
    if scalar_c == nil then scalar_c = scalar_a end
    return x / scalar_a, y / scalar_b, z / scalar_c
end

--- @brief
function math.add4(x, y, z, w, scalar_a, scalar_b, scalar_c, scalar_d)
    if scalar_b == nil then scalar_b = scalar_a end
    if scalar_c == nil then scalar_c = scalar_a end
    if scalar_d == nil then scalar_d = scalar_a end
    return x + scalar_a, y + scalar_b, z + scalar_c, w + scalar_d
end

--- @brief
function math.subtract4(x, y, z, w, scalar_a, scalar_b, scalar_c, scalar_d)
    if scalar_b == nil then scalar_b = scalar_a end
    if scalar_c == nil then scalar_c = scalar_a end
    if scalar_d == nil then scalar_d = scalar_a end
    return x - scalar_a, y - scalar_b, z - scalar_c, w - scalar_d
end

--- @brief
function math.reverse_subtract4(x, y, z, w, scalar_a, scalar_b, scalar_c, scalar_d)
    if scalar_b == nil then scalar_b = scalar_a end
    if scalar_c == nil then scalar_c = scalar_a end
    if scalar_d == nil then scalar_d = scalar_a end
    return scalar_a - x, scalar_b - y, scalar_c - z, scalar_d - w
end

--- @brief
function math.multiply4(x, y, z, w, scalar_a, scalar_b, scalar_c, scalar_d)
    if scalar_b == nil then scalar_b = scalar_a end
    if scalar_c == nil then scalar_c = scalar_a end
    if scalar_d == nil then scalar_d = scalar_a end
    return x * scalar_a, y * scalar_b, z * scalar_c, w * scalar_d
end

--- @brief
function math.divide4(x, y, z, w, scalar_a, scalar_b, scalar_c, scalar_d)
    if scalar_b == nil then scalar_b = scalar_a end
    if scalar_c == nil then scalar_c = scalar_a end
    if scalar_d == nil then scalar_d = scalar_a end
    return x / scalar_a, y / scalar_b, z / scalar_c, w / scalar_d
end

--- @brief Normalize a 2D vector.
function math.normalize2(x, y)
    local magnitude = math.sqrt(x * x + y * y)
    if magnitude == 0 then
        return 0, 0
    else
        return x / magnitude, y / magnitude
    end
end

--- @brief Get the magnitude of a 2D vector.
function math.magnitude2(x, y)
    return math.sqrt(x * x + y * y)
end

--- @brief Reflect a 2D vector off a surface with a given normal.
function math.reflect(vx, vy, normal_x, normal_y)
    local dot_product = vx * normal_x + vy * normal_y
    return vx - 2 * dot_product * normal_x,  vy - 2 * dot_product * normal_y
end

--- @brief Normalize a 3D vector.
function math.normalize3(x, y, z)
    local magnitude = math.sqrt(x * x + y * y + z * z)
    if magnitude == 0 then
        return 0, 0, 0
    else
        return x / magnitude, y / magnitude, z / magnitude
    end
end

--- @brief Get the magnitude of a 3D vector.
function math.magnitude3(x, y, z)
    return math.sqrt(x * x + y * y + z * z)
end

--- @brief Rotate a 2D vector by an angle.
function math.rotate2(x, y, angle)
    local cos_angle = math.cos(angle)
    local sin_angle = math.sin(angle)
    return x * cos_angle - y * sin_angle,
    x * sin_angle + y * cos_angle
end

--- @brief Rotate a 3D vector around the Z axis.
function math.rotate3(x, y, z, angle)
    local cos_a = math.cos(angle)
    local sin_a = math.sin(angle)
    return x * cos_a - y * sin_a, x * sin_a + y * cos_a, z
end

--- @brief Get the angle of a 2D vector from the positive X axis.
function math.angle(x, y)
    return math.atan2(y, x)
end

--- @brief Get the distance between two 2D points.
function math.distance2(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--- @brief Get the distance between two 3D points.
function math.distance3(x1, y1, z1, x2, y2, z2)
    local dx = x2 - x1
    local dy = y2 - y1
    local dz = z2 - z1
    return math.sqrt(dx * dx + dy * dy + dz * dz)
end

function math.signed_distance(x1, y1, x2, y2)
    return x1 * y2 - y1 * x2
end

--- @brief Get the dot product of two 2D vectors.
function math.dot2(x1, y1, x2, y2)
    return x1 * x2 + y1 * y2
end

--- @brief Get the dot product of two 3D vectors.
function math.dot3(x1, y1, z1, x2, y2, z2)
    return x1 * x2 + y1 * y2 + z1 * z2
end

--- @brief Get the 2D cross product (a scalar).
function math.cross2(x1, y1, x2, y2)
    return x1 * y2 - y1 * x2
end

--- @brief Get the 3D cross product (a vector).
function math.cross3(x1, y1, z1, x2, y2, z2)
    return y1 * z2 - z1 * y2,
    z1 * x2 - x1 * z2,
    x1 * y2 - y1 * x2
end

--- @brief Normalize a 2D or 3D vector.
function math.normalize(...)
    if select("#", ...) == 2 then
        return math.normalize2(...)
    else
        return math.normalize3(...)
    end
end

--- @brief Get the magnitude of a 2D or 3D vector.
function math.magnitude(...)
    if select("#", ...) == 2 then
        return math.magnitude2(...)
    else
        return math.magnitude3(...)
    end
end

--- @brief Rotate a 2D vector, or a 3D vector around the Z axis.
function math.rotate(...)
    if select("#", ...) == 3 then
        return math.rotate2(...)
    else
        return math.rotate3(...)
    end
end

--- @brief Dot product of two 2D or 3D vectors.
function math.dot(...)
    if select("#", ...) == 4 then
        return math.dot2(...)
    else
        return math.dot3(...)
    end
end

--- @brief Cross product of two 2D (scalar) or 3D (vector) vectors.
function math.cross(...)
    if select("#", ...) == 4 then
        return math.cross2(...)
    else
        return math.cross3(...)
    end
end

--- @brief Get the distance between two 2D or 3D points.
function math.distance(...)
    if select("#", ...) == 4 then
        return math.distance2(...)
    else
        return math.distance3(...)
    end
end

--- @brief
function math.add(...)
    local n = select("#", ...)
    if n == 4 then
        return math.add2(...)
    elseif n == 6 then
        return math.add3(...)
    elseif n == 8 then
        return math.add4(...)
    else
        rt.error("In math.add: wrong number of arguments, expected 4, 6, or 8, got `", select("#", ...))
    end
end

--- @brief
function math.subtract(...)
    local n = select("#", ...)
    if n == 4 then
        return math.subtract2(...)
    elseif n == 6 then
        return math.subtract3(...)
    elseif n == 8 then
        return math.subtract4(...)
    else
        rt.error("In math.subtract: wrong number of arguments, expected 4, 6, or 8, got `", select("#", ...))
    end
end

--- @brief
function math.reverse_subtract(...)
    local n = select("#", ...)
    if n == 4 then
        return math.reverse_subtract2(...)
    elseif n == 6 then
        return math.reverse_subtract3(...)
    elseif n == 8 then
        return math.reverse_subtract4(...)
    else
        rt.error("In math.reverse_subtract: wrong number of arguments, expected 4, 6, or 8, got `", select("#", ...))
    end
end

--- @brief
function math.multiply(...)
    local n = select("#", ...)
    if n == 4 then
        return math.multiply2(...)
    elseif n == 6 then
        return math.multiply3(...)
    elseif n == 8 then
        return math.multiply4(...)
    else
        rt.error("In math.multiply: wrong number of arguments, expected 4, 6, or 8, got `", select("#", ...))
    end
end

--- @brief
function math.divide(...)
    local n = select("#", ...)
    if n == 4 then
        return math.divide2(...)
    elseif n == 6 then
        return math.divide3(...)
    elseif n == 8 then
        return math.divide4(...)
    else
        rt.error("In math.divide: wrong number of arguments, expected 4, 6, or 8, got `", select("#", ...))
    end
end


--- @brief
function math.turn(x, y, left_or_right)
    if left_or_right == nil then left_or_right = true end
    if left_or_right then
        return y, -x
    else
        return -y, x
    end
end

--- @brief
function math.turn_left(x, y)
    return math.turn(x, y, true)
end

--- @brief
function math.turn_right(x, y)
    return math.turn(x, y, false)
end

--- @brief
function math.flip(x, y)
    return -x, -y
end

function math.gaussian(x, ramp)
    return math.exp(((-4 * math.pi) / 3) * (ramp * x) * (ramp * x))
end

function math.to_number(any)
    if any == true then
        return 1
    elseif any == false then
        return 0
    elseif any == nil then
        return 0
    else
        return tonumber(any)
    end
end