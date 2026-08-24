math.complex = {}

--- @brief
function math.complex.zero()
    return 0, 0
end

--- @brief
function math.complex.identity()
    return 1, 0
end

--- @brief
function math.complex.i()
    return 0, 1
end

--- @brief
function math.complex.from_angle(angle, magnitude)
    if magnitude == nil then magnitude = 1 end
    return magnitude * math.cos(angle), magnitude * math.sin(angle)
end

--- @brief
function math.complex.to_angle(x, y)
    return math.atan2(y, x)
end

--- @brief
function math.complex.add(x1, y1, x2, y2)
    return x1 + x2, y1 + y2
end

--- @brief
function math.complex.subtract(x1, y1, x2, y2)
    return x1 - x2, y1 - y2
end

--- @brief
function math.complex.multiply(x1, y1, x2, y2)
    return x1 * x2 - y1 * y2,
    x1 * y2 + y1 * x2
end

--- @brief
function math.complex.divide(x1, y1, x2, y2)
    local denominator = x2 * x2 + y2 * y2
    return (x1 * x2 + y1 * y2) / denominator,
    (y1 * x2 - x1 * y2) / denominator
end

--- @brief
function math.complex.negate(x, y)
    return -x, -y
end

--- @brief
function math.complex.conjugate(x, y)
    return x, -y
end

--- @brief
math.complex.magnitude = math.magnitude

--- @brief
math.complex.abs = math.complex.magnitude

--- @brief
function math.complex.normalize(x, y)
    local mag = math.complex.magnitude(x, y)
    if mag <= math.eps then
        return math.complex.identity()
    end
    return x / mag, y / mag
end

--- @brief
function math.complex.inverse(x, y)
    local magnitude_squared = x * x + y * y
    return x / magnitude_squared, -y / magnitude_squared
end

--- @brief treat vector (vx, vy) as a complex number and multiply by (x + iy), if (x, y) is normalized, this is a rotation
function math.complex.apply(x, y, vx, vy)
    return x * vx - y * vy,
        x * vy + y * vx
end

--- @brief
function math.complex.inverse_apply(x, y, vx, vy)
    local ix, iy = math.complex.inverse(x, y)
    return math.complex.apply(ix, iy, vx, vy)
end

--- @brief
function math.complex.mix(x1, y1, x2, y2, t)
    return x1 + t * (x2 - x1),
        y1 + t * (y2 - y1)
end

--- @brief generate uniform complex number with magnitude <= magnitude
function math.complex.random(magnitude)
    require "common.random"
    local u = rt.random.number(0, 1)
    local v = rt.random.number(0, 1)

    local r = magnitude * math.sqrt(u)
    local theta = 2 * math.pi * v
    return r * math.cos(theta), r * math.sin(theta)
end

