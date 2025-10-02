--- @class rt.Transform
rt.Transform = meta.class("Transform")

--- @brief initialize as identity
function rt.Transform:instantiate()
    self._native = love.math.newTransform()
end

--- @brief apply another transform to this one
function rt.Transform:apply(other)
    meta.assert(other, rt.Transform)
    self._native:apply(other._native)
end

--- @brief get a copy of this transform
function rt.Transform:clone()
    local out = rt.Transform()
    out._native:setMatrix(self._native:getMatrix())
    return out
end

--- @brief replace the matrix values directly
function rt.Transform:_update(
    x11, x12, x13, x14,
    x21, x22, x23, x24,
    x31, x32, x33, x34,
    x41, x42, x43, x44
)
    self._native:setMatrix(
        x11, x12, x13, x14,
        x21, x22, x23, x24,
        x31, x32, x33, x34,
        x41, x42, x43, x44
    )
end

--- @brief
function rt.Transform:translate(...)
    if select("#", ...) == 2 then
        self._native:transform(select(1, ...), select(2, ...))
    else
        local x, y, z = select(1, ...), select(2, ...), select(3, ...)

        local x11, x12, x13, x14,
        x21, x22, x23, x24,
        x31, x32, x33, x34,
        x41, x42, x43, x44 = self._native:getMatrix()

        x14 = x14 + x11 * x + x12 * y + x13 * z
        x24 = x24 + x21 * x + x22 * y + x23 * z
        x34 = x34 + x31 * x + x32 * y + x33 * z

        self._native:setMatrix(
            x11, x12, x13, x14,
            x21, x22, x23, x24,
            x31, x32, x33, x34,
            x41, x42, x43, x44
        )
    end
end

--- @brief
function rt.Transform:scale(...)
    if select("#", ...) == 2 then
        self._native:scale(select(1, ...), select(2, ...))
    else
        local x, y, z = select(1, ...), select(2, ...), select(3, ...)

        local x11, x12, x13, x14,
        x21, x22, x23, x24,
        x31, x32, x33, x34,
        x41, x42, x43, x44 = self._native:getMatrix()

        x11 = x11 * x
        x12 = x12 * y
        x13 = x13 * z
        x21 = x21 * x
        x22 = x22 * y
        x23 = x23 * z
        x31 = x31 * x
        x32 = x32 * y
        x33 = x33 * z

        self._native:setMatrix(
            x11, x12, x13, x14,
            x21, x22, x23, x24,
            x31, x32, x33, x34,
            x41, x42, x43, x44
        )
    end
end

--- @brief inverse
function rt.Transform:inverse()
    local out = rt.Transform()
    out._native = self._native:inverse()
    return out
end

--- @brief
function rt.Transform:as_inverse()
    self._native = self._native:inverse()
    return self
end

--- @brief transpose
function rt.Transform:transpose()
    local x11, x12, x13, x14,
    x21, x22, x23, x24,
    x31, x32, x33, x34,
    x41, x42, x43, x44 = self._native:getMatrix()

    self._native:setMatrix(
        x11, x21, x31, x41,
        x12, x22, x32, x42,
        x13, x23, x33, x43,
        x14, x24, x34, x44
    )
end

--- @brief
function rt.Transform:override(
    x11, x12, x13, x14,
    x21, x22, x23, x24,
    x31, x32, x33, x34,
    x41, x42, x43, x44
)
    self._native:setMatrix(
        x11, x12, x13, x14,
        x21, x22, x23, x24,
        x31, x32, x33, x34,
        x41, x42, x43, x44
    )
end

local _reusable = love.math.newTransform()

--- @brief rotate around the X axis
function rt.Transform:rotate_x(angle)
    local c = math.cos(angle)
    local s = math.sin(angle)
    _reusable:setMatrix(
        1, 0, 0, 0,
        0, c, -s, 0,
        0, s, c, 0,
        0, 0, 0, 1
    )
    self._native:apply(_reusable)
end

--- @brief rotate around the Y axis
function rt.Transform:rotate_y(angle)
    local c = math.cos(angle)
    local s = math.sin(angle)
    _reusable:setMatrix(
        c, 0, s, 0,
        0, 1, 0, 0,
        -s, 0, c, 0,
        0, 0, 0, 1
    )
    self._native:apply(_reusable)
end

--- @brief rotate around the Z axis
function rt.Transform:rotate_z(angle)
    local c = math.cos(angle)
    local s = math.sin(angle)
    _reusable:setMatrix(
        c, -s, 0, 0,
        s, c, 0, 0,
        0, 0, 1, 0,
        0, 0, 0, 1
    )
    self._native:apply(_reusable)
end

--- @brief transform a point by this transform
function rt.Transform:transform_point(...)
    if select("#", ...) == 2 then
        return self._native:transformPoint(select(1, ...), select(2, ...))
    else
        local x, y, z = select(1, ...), select(2, ...), select(3, ...)
        local w = 1

        local x11, x12, x13, x14,
        x21, x22, x23, x24,
        x31, x32, x33, x34,
        x41, x42, x43, x44 = self._native:getMatrix()

        local rx = x * x11 + y * x12 + z * x13 + w * x14
        local ry = x * x21 + y * x22 + z * x23 + w * x24
        local rz = x * x31 + y * x32 + z * x33 + w * x34
        local rw = x * x41 + y * x42 + z * x43 + w * x44

        return rx, ry, rz, rw
    end
end

--- @brief transform a point by the inverse of this transform
function rt.Transform:inverse_transform_point(...)
    if select("#", ...) == 2 then
        return self._native:inverseTransformPoint(select(1, ...), select(2, ...))
    else
        local x, y, z = select(1, ...), select(2, ...), select(3, ...)
        local w = 1

        local x11, x12, x13, x14,
        x21, x22, x23, x24,
        x31, x32, x33, x34,
        x41, x42, x43, x44 = self._native:inverse():getMatrix()

        local rx = x * x11 + y * x12 + z * x13 + w * x14
        local ry = x * x21 + y * x22 + z * x23 + w * x24
        local rz = x * x31 + y * x32 + z * x33 + w * x34
        local rw = x * x41 + y * x42 + z * x43 + w * x44

        return rx, ry, rz, rw
    end
end

function rt.Transform:as_perspective_projection(fov, aspect, near, far)
    local top = near * math.tan(fov / 2)
    local bottom = -top
    local right = top * aspect
    local left = -right

    self._native:setMatrix(
        2 * near / (right - left), 0, 0, 0,
        0, 2 * near / (bottom - top), 0, 0,
        0, 0, -1 * (far + near) / (far - near), -2 * far * near / (far - near),
        0, 0, -1, 1
    )

    return self
end

function rt.Transform:as_orthographic_projection(width, height, near, far)
    local aspect = width / height
    local top = -height / 2
    local bottom = -top
    local right = top * -aspect
    local left = -right
    self._native:setMatrix(
        2 / (right - left), 0, 0, -(right + left) / (right - left),
        0, 2 / (top - bottom), 0, -(top + bottom) / (top - bottom),
        0, 0, -2 / (far - near), -(far + near) / (far - near),
        0, 0, 0, 1
    )

    return self
end

--- @brief
function rt.Transform:look_at(
    eye_x, eye_y, eye_z, target_x,
    target_y, target_z,
    up_x, up_y, up_z
)
    local z1, z2, z3 = math.normalize(eye_x - target_x, eye_y - target_y, eye_z - target_z)
    local x1, x2, x3 = math.normalize(math.cross(up_x, up_y, up_z, z1, z2, z3))
    local y1, y2, y3 = math.cross(z1, z2, z3, x1, x2, x3)

    self._native:setMatrix(
        x1, x2, x3, -math.dot(x1, x2, x3, eye_x, eye_y, eye_z),
        y1, y2, y3, -math.dot(y1, y2, y3, eye_x, eye_y, eye_z),
        z1, z2, z3, -math.dot(z1, z2, z3, eye_x, eye_y, eye_z),
        0, 0, 0, 1
    )

    return self
end

--- @brief
function rt.Transform:set_target_to(
    eye_x, eye_y, eye_z,
    target_x, target_y, target_z,
    up_x, up_y, up_z
)
    local z1, z2, z3 = math.normalize(eye_x - target_x, eye_y - target_y, eye_z - target_z)
    local x1, x2, x3 = math.normalize(math.cross(up_x, up_y, up_z, z1, z2, z3))
    local y1, y2, y3 = math.cross(z1, z2, z3, x1, x2, x3)

    self._native:setMatrix(
        x1, y1, z1, eye_x,
        x2, y2, z2, eye_y,
        x3, y3, z3, eye_z,
        0, 0, 0, 1
    )
end

--- @brief
function rt.Transform:set_orientation(
    forward_x, forward_y, forward_z,
    right_x, right_y, right_z,
    up_x, up_y, up_z
)
    local _, _, _, x14,
    _, _, _, x24,
    _, _, _, x34,
    x41, x42, x43, x44 = self._native:getMatrix()

    forward_x, forward_y, forward_z = math.normalize(forward_x, forward_y, forward_z)
    right_x, right_y, right_z = math.normalize(right_x, right_y, right_z)
    up_x, up_y, up_z = math.normalize(up_x, up_y, up_z)

    self._native:setMatrix(
        right_x, right_y, right_z, x14,
        up_x, up_y, up_z, x24,
        forward_x, forward_y, forward_z, x34,
        x41, x42, x43, x44
    )
end

--- @brief Set the translation component of the transform
function rt.Transform:set_position(x, y, z)
    local x11, x12, x13, _,
    x21, x22, x23, _,
    x31, x32, x33, _,
    x41, x42, x43, x44 = self._native:getMatrix()

    self._native:setMatrix(
        x11, x12, x13, x,
        x21, x22, x23, y,
        x31, x32, x33, z,
        x41, x42, x43, x44
    )
end

--- @brief Set orientation from a quaternion (i, j, k, w)
function rt.Transform:set_to_orientation_from_quaternion(i, j, k, w)
    self._native:setMatrix(
        1 - 2 * j * j - 2 * k * k, 2 * i * j + 2 * w * k, 2 * i * k - 2 * w * j, 0,
        2 * i * j - 2 * w * k, 1 - 2 * i * i - 2 * k * k, 2 * j * k + 2 * w * i, 0,
        2 * i * k + 2 * w * j, 2 * j * k - 2 * w * i, 1 - 2 * i * i - 2 * j * j, 0,
        0, 0, 0, 1
    )
end

--- @brief Remove translation and scale, leaving only normalized rotation axes
function rt.Transform:set_to_orientation()
    local x11, x12, x13, _,
    x21, x22, x23, _,
    x31, x32, x33 = self._native:getMatrix()

    x11, x12, x13 = math.normalize(x11, x12, x13)
    x21, x22, x23 = math.normalize(x21, x22, x23)
    x31, x32, x33 = math.normalize(x31, x32, x33)

    self._native:setMatrix(
        x11, x12, x13, 0,
        x21, x22, x23, 0,
        x31, x32, x33, 0,
        0, 0, 0, 1
    )
end

--- @brief Get the underlying LÖVE transform for direct use
function rt.Transform:get_native()
    return self._native
end
