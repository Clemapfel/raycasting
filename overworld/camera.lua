require "common.input_subscriber"
require "common.timed_animation"

do
    local max_velocity = 5000
    local acceleration = 500 -- New acceleration parameter
    rt.settings.overworld.camera = {
        translation_speed = max_velocity, -- px / s
        acceleration = 2 * max_velocity, -- px / s^2
        angular_acceleration = 2 * math.pi,
        damping_factor = 0.95 -- New damping factor for inertia
    }
end

--- @class ow.Camera
ow.Camera = meta.class("Camera")

--- @brief
function ow.Camera:instantiate()
    meta.install(self, {
        _scale = 1,
        _offset_x = 0,
        _offset_y = 0,
        _angle = 0,

        _current_x = 0,
        _current_y = 0,
        _target_x = 0,
        _target_y = 0,

        _velocity_magnitude = 0,
        _velocity_angle = 0
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
    love.graphics.rotate(self._angle)
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
    local cx, cy = self._current_x, self._current_y
    local tx, ty = self._target_x, self._target_y

    local angle = math.angle(tx - cx, ty - cy)
    local angular_acceleration = rt.settings.overworld.camera.angular_acceleration
    local angle_difference = (angle - self._velocity_angle + math.pi) % (2 * math.pi) - math.pi

    if angle_difference > 0 then
        self._velocity_angle = self._velocity_angle + math.min(angle_difference, angular_acceleration * delta)
    else
        self._velocity_angle = self._velocity_angle + math.max(angle_difference, -angular_acceleration * delta)
    end
    self._velocity_angle = angle --math.clamp(self._velocity_angle, angle - angular_acceleration * delta, angle + angular_acceleration * delta)

    local distance = math.distance(cx, cy, tx, ty)
    self._velocity_magnitude = distance ^ 1.2

    local magnitude = self._velocity_magnitude
    self._current_x = self._current_x + math.cos(self._velocity_angle) * magnitude * delta
    self._current_y = self._current_y + math.sin(self._velocity_angle) * magnitude * delta
end

--- @brief
function ow.Camera:reset()
    self._scale = 1
    self._offset_x = 0
    self._offset_y = 0
    self._angle = 0
end