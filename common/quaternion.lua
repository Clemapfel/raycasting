require "common.transform"

math.quaternion = {}

function math.quaternion.identity()
    return 0, 0, 0, 1
end

function math.quaternion.from_axis_angle(axis_x, axis_y, axis_z, angle)
    local half_angle = angle * 0.5
    local s = math.sin(half_angle)
    return axis_x * s, axis_y * s, axis_z * s, math.cos(half_angle)
end

function math.quaternion.from_euler_angle(roll, pitch, yaw)
    local cr = math.cos(roll * 0.5)
    local sr = math.sin(roll * 0.5)
    local cp = math.cos(pitch * 0.5)
    local sp = math.sin(pitch * 0.5)
    local cy = math.cos(yaw * 0.5)
    local sy = math.sin(yaw * 0.5)

    return sr * cp * cy - cr * sp * sy,
        cr * sp * cy + sr * cp * sy,
        cr * cp * sy - sr * sp * cy,
        cr * cp * cy + sr * sp * sy
end

function math.quaternion.multiply(x1, y1, z1, w1, x2, y2, z2, w2)
    return w1 * x2 + x1 * w2 + y1 * z2 - z1 * y2,
    w1 * y2 - x1 * z2 + y1 * w2 + z1 * x2,
    w1 * z2 + x1 * y2 - y1 * x2 + z1 * w2,
    w1 * w2 - x1 * x2 - y1 * y2 - z1 * z2
end

function math.quaternion.apply(qx, qy, qz, qw, vx, vy, vz)
    -- v' = q * v * q^-1
    -- Optimized version using: v' = v + 2 * cross(q.xyz, cross(q.xyz, v) + q.w * v)
    local uvx = qy * vz - qz * vy
    local uvy = qz * vx - qx * vz
    local uvz = qx * vy - qy * vx

    local uuvx = qy * uvz - qz * uvy
    local uuvy = qz * uvx - qx * uvz
    local uuvz = qx * uvy - qy * uvx

    uvx = uvx * qw
    uvy = uvy * qw
    uvz = uvz * qw

    return vx + 2 * (uvx + uuvx),
    vy + 2 * (uvy + uuvy),
    vz + 2 * (uvz + uuvz)
end

function math.quaternion.inverse(x, y, z, w)
    local magnitude_squared = x*x + y*y + z*z + w*w
    return -x / magnitude_squared,
        -y / magnitude_squared,
        -z / magnitude_squared,
         w / magnitude_squared
end

function math.quaternion.magnitude(x, y, z, w)
    return math.sqrt(x*x + y*y + z*z + w*w)
end

function math.quaternion.normalize(x, y, z, w)
    local mag = math.quaternion.magnitude(x, y, z, w)
    if mag <= math.eps then
        return math.quaternion.identity()
    end
    return x / mag, y / mag, z / mag, w / mag
end


function math.quaternion.dot(x1, y1, z1, w1, x2, y2, z2, w2)
    return x1 * x2 + y1 * y2 + z1 * z2 + w1 * w2
end

function math.quaternion.mix(x1, y1, z1, w1, x2, y2, z2, w2, t)
    local dot = x1 * x2 + y1 * y2 + z1 * z2 + w1 * w2

    -- if dot < 0, negate one quaternion to take shorter path
    if dot < 0 then
        x2, y2, z2, w2 = -x2, -y2, -z2, -w2
        dot = -dot
    end

    -- if quaternions are very close, use linear interpolation
    if dot > 1 - 1e-4 then
        local x = x1 + t * (x2 - x1)
        local y = y1 + t * (y2 - y1)
        local z = z1 + t * (z2 - z1)
        local w = w1 + t * (w2 - w1)
        return math.quaternion.normalize(x, y, z, w)
    end

    local theta_0 = math.acos(dot)
    local theta = theta_0 * t
    local sin_theta = math.sin(theta)
    local sin_theta_0 = math.sin(theta_0)

    local s1 = math.cos(theta) - dot * sin_theta / sin_theta_0
    local s2 = sin_theta / sin_theta_0

    return x1 * s1 + x2 * s2,
        y1 * s1 + y2 * s2,
        z1 * s1 + z2 * s2,
        w1 * s1 + w2 * s2
end

function math.quaternion.to_axis_angle(x, y, z, w)
    x, y, z, w = math.quaternion.normalize(x, y, z, w)

    local angle = 2 * math.acos(w)
    local s = math.sqrt(1 - w*w)

    if s <= math.eps then
        return 1, 0, 0, 0
    end

    return x / s, y / s, z / s, angle
end

function math.quaternion.as_transform(x, y, z, w)
    x, y, z, w = math.quaternion.normalize(x, y, z, w)

    local xx = x * x
    local yy = y * y
    local zz = z * z
    local xy = x * y
    local xz = x * z
    local yz = y * z
    local wx = w * x
    local wy = w * y
    local wz = w * z

    return rt.Transform(
        1 - 2 * (yy + zz),  2 * (xy - wz),      2 * (xz + wy),      0,
        2 * (xy + wz),      1 - 2 * (xx + zz),  2 * (yz - wx),      0,
        2 * (xz - wy),      2 * (yz + wx),      1 - 2 * (xx + yy),  0,
        0,                  0,                  0,                  1
    )
end

function math.quaternion.random()
    -- shoemake method
    require "common.random"
    local u1 = rt.random.number(0, 1)
    local u2 = rt.random.number(0, 1)
    local u3 = rt.random.number(0, 1)

    local a = math.sqrt(1 - u1)
    local b = math.sqrt(u1)

    local theta1 = 2 * math.pi * u2
    local theta2 = 2 * math.pi * u3

    local x = a * math.sin(theta1)
    local y = a * math.cos(theta1)
    local z = b * math.sin(theta2)
    local w = b * math.cos(theta2)

    return math.quaternion.normalize(x, y, z, w)
end

