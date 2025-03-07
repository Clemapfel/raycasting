require "common.input_subscriber"

local max_velocity = 1000
rt.settings.overworld.camera = {
    translation_speed = max_velocity, -- px / s
    acceleration = 1 / 10 * max_velocity,
    deceleration = 1 / 100 * max_velocity
}

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

        _velocity_x = 0,
        _velocity_y = 0,
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

--- @brief
function ow.Camera:update(delta)
    local cx, cy = self._current_x, self._current_y
    local tx, ty = self._target_x, self._target_y

    local dx, dy = tx - cx, ty - cy
    local distance = math.magnitude(dx, dy)

    if distance < 1 then
        self._velocity_x, self._velocity_y = 0, 0
        return
    end

    local direction_x, direction_y = dx / distance, dy / distance

    local acceleration = rt.settings.overworld.camera.acceleration
    local deceleration = rt.settings.overworld.camera.deceleration
    local max_speed = rt.settings.overworld.camera.translation_speed

    local speed = math.magnitude(self._velocity_x, self._velocity_y)
    if speed < max_speed then
        self._velocity_x = self._velocity_x + direction_x * acceleration * delta
        self._velocity_y = self._velocity_y + direction_y * acceleration * delta
    else
        self._velocity_x = self._velocity_x - direction_x * deceleration * delta
        self._velocity_y = self._velocity_y - direction_y * deceleration * delta
    end

    speed = math.magnitude(self._velocity_x, self._velocity_y)
    if speed > max_speed then
        self._velocity_x = self._velocity_x / speed * max_speed
        self._velocity_y = self._velocity_y / speed * max_speed
    end

    self._current_x = cx + self._velocity_x * delta
    self._current_y = cy + self._velocity_y * delta
end

--- @brief
function ow.Camera:reset()
    self._scale = 1
    self._offset_x = 0
    self._offset_y = 0
    self._angle = 0
end