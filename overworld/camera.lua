rt.settings.overworld.camera = {
    acceleration = 10,
    mass = 1,
    damping = 0.9,

    angular_acceleration = 2 * math.pi / 2,
    angular_mass = 1,
    angular_damping = 1,
}

--- @class ow.Camera
ow.Camera = meta.class("Camera")

--- @brief
function ow.Camera:instantiate()
    meta.install(self, {
        _scale = 1,
        _offset_x = 0,
        _offset_y = 0,

        _current_x = 0,
        _current_y = 0,
        _target_x = 0,
        _target_y = 0,

        _velocity_x = 0,
        _velocity_y = 0,
        _angular_velocity = 0,

        _current_angle = 0,
        _target_angle = 0
    })
end

--- @brief
function ow.Camera:bind()
    local w, h = love.graphics.getDimensions()
    love.graphics.push()
    love.graphics.origin()
    love.graphics.translate(-self._current_x + 0.5 * w, -self._current_y + 0.5 * h)

    love.graphics.translate(0.5 * w, 0.5 * h)
    love.graphics.scale(self._scale, self._scale)
    love.graphics.translate(-0.5 * w, -0.5 * h)

    local camera_origin_x, camera_origin_y = self._offset_x + 0.5 * w, self._offset_y + 0.5 * h
    love.graphics.translate(camera_origin_x, camera_origin_y)
    love.graphics.rotate(self._current_angle)
    love.graphics.translate(-camera_origin_x, -camera_origin_y)
end

--- @brief
function ow.Camera:unbind()
    love.graphics.pop()
end

--- @brief
function ow.Camera:move_to(x, y)
    self._target_x, self._target_y = x, y
end

function ow.Camera:update(delta)
    local dx = self._target_x - self._current_x
    local dy = self._target_y - self._current_y

    -- Calculate acceleration
    local ax = (dx / rt.settings.overworld.camera.mass) * rt.settings.overworld.camera.acceleration
    local ay = (dy / rt.settings.overworld.camera.mass) * rt.settings.overworld.camera.acceleration

    local function smoothstep(edge0, edge1, x)
        x = math.max(0, math.min(1, (x - edge0) / (edge1 - edge0)))
        return x * x * (3 - 2 * x) ^ 3
    end

    -- multiply velocity if target is outside the frame
    local target_w = 0.5 * love.graphics.getWidth()
    local catchup_factor_x = smoothstep(0, target_w, math.abs(dx))

    local target_h = 0.5 * love.graphics.getWidth()
    local catchup_factor_y = smoothstep(0, target_h, math.abs(dy))

    self._velocity_x = self._velocity_x + ax * delta * catchup_factor_x
    self._velocity_y = self._velocity_y + ay * delta * catchup_factor_y

    self._velocity_x = self._velocity_x * rt.settings.overworld.camera.damping
    self._velocity_y = self._velocity_y * rt.settings.overworld.camera.damping

    local new_x = self._current_x + self._velocity_x * delta
    local new_y = self._current_y + self._velocity_y * delta

    -- prevent overshooting
    if math.abs(new_x - self._target_x) < math.abs(self._current_x - self._target_x) then
        self._current_x = new_x
    else
        self._current_x = self._target_x
        self._velocity_x = 0
    end

    if math.abs(new_y - self._target_y) < math.abs(self._current_y - self._target_y) then
        self._current_y = new_y
    else
        self._current_y = self._target_y
        self._velocity_y = 0
    end

    -- Calculate the shortest path on the circle
    local angle_diff = (self._target_angle - self._current_angle + math.pi) % (2 * math.pi) - math.pi

    -- Calculate angular acceleration
    local angular_acceleration = (angle_diff / rt.settings.overworld.camera.angular_mass) * rt.settings.overworld.camera.angular_acceleration

    -- Update angular velocity
    self._angular_velocity = self._angular_velocity + angular_acceleration * delta
    self._angular_velocity = self._angular_velocity * rt.settings.overworld.camera.angular_damping

    -- Calculate new angle
    local new_angle = self._current_angle + self._angular_velocity * delta * (1 + angle_diff)
    local new_angle_diff = (self._target_angle - new_angle + math.pi) % (2 * math.pi) - math.pi
    if math.abs(new_angle_diff) < math.abs(angle_diff) then
        self._current_angle = new_angle
    end

    self._current_angle = (self._current_angle + 2 * math.pi) % (2 * math.pi)
end

--- @brief
function ow.Camera:reset()
    self._scale = 1
    self._offset_x = 0
    self._offset_y = 0
    self._current_angle = 0
    self._velocity_x = 0
    self._velocity_y = 0
    self._angular_velocity = 0
end

--- @brief
function ow.Camera:rotate_to(angle)
    self._target_angle = angle
end

--- @brief
function ow.Camera:get_rotation()
    return self._current_angle
end