rt.settings.overworld.camera = {

}

--- @class ow.Camera
ow.Camera = meta.class("Camera")

--- @brief
function ow.Camera:instantiate()
    meta.install(self, {
        _current_x = 0,
        _current_y = 0,
        _target_x = 0,
        _target_y = 0,

        _velocity_x = 0,
        _velocity_y = 0,

        _current_angle = 0,
        _current_zoom = 1,
    })
end

--- @brief
function ow.Camera:bind()
    local w, h = love.graphics.getDimensions()
    love.graphics.push()
    love.graphics.origin()

    local origin_x, origin_y = 0.5 * w, 0.5 * h
    love.graphics.translate(origin_x, origin_y)
    love.graphics.scale(self._current_zoom, self._current_zoom)
    love.graphics.rotate(self._current_angle)
    love.graphics.translate(-origin_x, -origin_y)

    love.graphics.translate(-self._current_x + 0.5 * w, -self._current_y + 0.5 * h)
end

--- @brief
function ow.Camera:unbind()
    love.graphics.pop()
end

function ow.Camera:update(delta)
    if self._to_follow ~= nil then self:move_to(self._to_follow:get_position()) end

    local screen_w, screen_h = love.graphics.getDimensions()

    local exp = 1.3
    local dx = self._target_x - self._current_x
    local dy = self._target_y - self._current_y
    dx = math.abs(dx)^exp * math.sign(dx)
    dy = math.abs(dy)^exp * math.sign(dy)
    dx = dx / screen_w
    dy = dy / screen_h

    local velocity = rt.settings.overworld.player.velocity * 2
    local max_velocity = rt.settings.overworld.player.velocity * 4
    self._velocity_x = math.min(dx * velocity, max_velocity)
    self._velocity_y = math.min(dy * velocity, max_velocity)

    local target_x = self._current_x + self._velocity_x * delta
    local target_y = self._current_y + self._velocity_y * delta
    self._current_x = math.round(target_x)
    self._current_y = math.round(target_y)
end

--- @brief
function ow.Camera:reset()
    self._current_x = self._target_x
    self._current_y = self._target_y
    self._velocity_x = 0
    self._velocity_y = 0
    self._current_angle = 0
    self._current_zoom = 1
end

--- @brief
function ow.Camera:get_rotation()
    return self._current_angle
end

--- @brief
function ow.Camera:set_rotation(r)
    self._current_angle = r
end

--- @brief
function ow.Camera:get_position()
    return self._current_x, self._current_y
end

--- @brief
function ow.Camera:set_position(x, y)
    self._target_x = x
    self._target_y = y
    self._current_x = x
    self._current_y = y
end

--- @brief
function ow.Camera:move_to(x, y)
    self._target_x, self._target_y = x, y
end

--- @brief
function ow.Camera:get_zoom()
    return self._current_zoom
end

--- @brief
function ow.Camera:set_zoom(s)
    self._current_zoom = s
end

--- @brief
function ow.Camera:screen_xy_to_world_xy(screen_x, screen_y)
    local screen_w, screen_h = love.graphics.getDimensions()
    local origin_x, origin_y = 0.5 * screen_w, 0.5 * screen_h

    local x = screen_x - origin_x
    local y = screen_y - origin_y

    x = x / self._current_zoom
    y = y / self._current_zoom

    local cos_angle = math.cos(-self._current_angle)
    local sin_angle = math.sin(-self._current_angle)
    local world_x = x * cos_angle - y * sin_angle
    local world_y = x * sin_angle + y * cos_angle

    world_x = world_x + self._current_x
    world_y = world_y + self._current_y

    return world_x, world_y
end

--- @brief
function ow.Camera:world_xy_to_screen_xy(world_x, world_y)
    local screen_w, screen_h = love.graphics.getDimensions()
    local origin_x, origin_y = 0.5 * screen_w, 0.5 * screen_h

    local x = world_x - self._current_x
    local y = world_y - self._current_y

    local cos_angle = math.cos(self._current_angle)
    local sin_angle = math.sin(self._current_angle)
    local screen_x = x * cos_angle - y * sin_angle
    local screen_y = x * sin_angle + y * cos_angle

    screen_x = screen_x * self._current_zoom
    screen_y = screen_y * self._current_zoom

    screen_x = screen_x + origin_x
    screen_y = screen_y + origin_y

    return screen_x, screen_y
end



