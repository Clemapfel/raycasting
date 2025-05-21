require "common.sprite_batch"

rt.settings.common.camera = {
    speed = 0.8, -- in [0, 1], where 0 slowest, 1 fastest
    max_velocity = 2000
}

--- @class rt.Camera
rt.Camera = meta.class("Camera")

--- @brief
function rt.Camera:instantiate()
    meta.install(self, {
        _current_x = 0,
        _current_y = 0,
        _target_x = 0,
        _target_y = 0,

        _velocity_x = 0,
        _velocity_y = 0,

        _current_angle = 0,
        _current_scale = 1,

        _timestamp = love.timer.getTime(),
        _last_x = 0,
        _last_y = 0,

        _bounds_x = -math.huge,
        _bounds_y = -math.huge,
        _bounds_width = math.huge,
        _bounds_height = math.huge,
        _apply_bounds = true
    })
end

local _floor
if rt.settings.sprite_batch.use_subpixel_filtering then
    _floor = function(x) return x end
else
    _floor = math.floor
end

--- @brief
function rt.Camera:bind()
    local w, h = love.graphics.getDimensions()
    love.graphics.push()
    love.graphics.origin()

    local origin_x, origin_y = _floor(0.5 * w), _floor(0.5 * h)
    love.graphics.translate(origin_x, origin_y)
    local scale = self:get_final_scale()
    love.graphics.scale(scale, scale)
    love.graphics.rotate(self._current_angle)
    love.graphics.translate(-origin_x, -origin_y)
    love.graphics.translate(-_floor(self._current_x) + 0.5 * w, -_floor(self._current_y) + 0.5 * h)
end

--- @brief
function rt.Camera:unbind()
    --love.graphics.rectangle("line", self._bounds_x, self._bounds_y, self._bounds_width, self._bounds_height)
    love.graphics.pop()
end

--- @brief [internal]
function rt.Camera:_constrain(x, y)
    if self._apply_bounds == true then
        local screen_w, screen_h = love.graphics.getDimensions()
        local w, h = screen_w / self._current_scale, screen_h / self._current_scale
        x = math.clamp(x,
            math.ceil(0.5 * w + self._bounds_x),
            math.floor(0.5 * w - w + self._bounds_x + self._bounds_width)
        )

        y = math.clamp(y,
            math.ceil(0.5 * h + self._bounds_y),
            math.floor(0.5 * h - h + self._bounds_y + self._bounds_height)
        )
    end
    return x, y
end

local _distance_f = function(x)
    local speed = rt.settings.common.camera.speed
    return math.sqrt(math.abs(x)) * math.abs(x)^(1 - (1 - speed)) * math.sign(x)
end

function rt.Camera:update(delta)
    local screen_w, screen_h = love.graphics.getDimensions()

    local dx = _distance_f(self._target_x - self._current_x)
    local dy = _distance_f(self._target_y - self._current_y)
    dx = dx / screen_w
    dy = dy / screen_h

    self._velocity_x = dx * rt.settings.common.camera.max_velocity
    self._velocity_y = dy * rt.settings.common.camera.max_velocity

    local final_delta_x = self._velocity_x * delta
    local final_delta_y = self._velocity_y * delta

    self._last_x, self._last_y = self._current_x, self._current_y
    self._current_x = math.round(self._current_x + final_delta_x)
    self._current_y = math.round(self._current_y + final_delta_y)
end

--- @brief
function rt.Camera:reset()
    self._current_x = self._target_x
    self._current_y = self._target_y
    self._velocity_x = 0
    self._velocity_y = 0
    self._current_angle = 0
    self._current_scale = 1
end

--- @brief
function rt.Camera:get_rotation()
    return self._current_angle
end

--- @brief
function rt.Camera:set_rotation(r)
    self._current_angle = r
end

--- @brief
function rt.Camera:get_position()
    return self._current_x, self._current_y
end

--- @brief
function rt.Camera:get_velocity()
    local now = love.timer.getTime()
    local dt = now - self._timestamp
    local dx = self._current_x - self._last_x
    local dy = self._current_y - self._last_y
    return dx / dt, dy / dt
end

--- @brief
function rt.Camera:get_size()
    local w, h = love.graphics.getDimensions()
    return w * self._current_scale, h * self._current_scale
end

--- @brief
function rt.Camera:set_position(x, y, override_bounds)
    if override_bounds ~= true then
        x, y = self:_constrain(x, y)
    end

    self._target_x = x
    self._target_y = y
    self._current_x = x
    self._current_y = y
end

--- @brief
function rt.Camera:move_to(x, y, override_bounds)
    if override_bounds ~= true then
        self._target_x, self._target_y = self:_constrain(x, y)
    else
        self._target_x, self._target_y = x, y
    end
end

--- @brief
function rt.Camera:get_scale()
    return self._current_scale
end

--- @brief
function rt.Camera:get_final_scale()
    return self._current_scale * self:get_scale_delta()
end

--- @brief
function rt.Camera:get_scale_delta()
    return 1 --(love.graphics.getHeight() / 600)
end

--- @brief
function rt.Camera:set_scale(s, override_bounds)
    self._current_scale = s

    if override_bounds ~= true then
        self._target_x, self._target_x = self:_constrain(self._target_x, self._target_y)
    end
end

--- @brief
function rt.Camera:set_bounds(bounds)
    if bounds ~= nil then
        meta.assert(bounds, "AABB")
        self._bounds_x = bounds.x
        self._bounds_y = bounds.y
        self._bounds_width = bounds.width
        self._bounds_height = bounds.height
    else
        self._bounds_x = -math.huge
        self._bounds_y = -math.huge
        self._bounds_width = math.huge
        self._bounds_height = math.huge
    end
end

--- @brief
function rt.Camera:get_bounds()
    return rt.AABB(self._bounds_x, self._bounds_y, self._bounds_width, self._bounds_height)
end

--- @brief
function rt.Camera:set_apply_bounds(b)
    self._apply_bounds = b
end

--- @brief
function rt.Camera:get_apply_bounds()
    return self._apply_bounds
end

--- @brief
function rt.Camera:screen_xy_to_world_xy(screen_x, screen_y)
    local screen_w, screen_h = love.graphics.getDimensions()
    local origin_x, origin_y = 0.5 * screen_w, 0.5 * screen_h

    local x = screen_x - origin_x
    local y = screen_y - origin_y

    x = x / self._current_scale
    y = y / self._current_scale

    local cos_angle = math.cos(-self._current_angle)
    local sin_angle = math.sin(-self._current_angle)
    local world_x = x * cos_angle - y * sin_angle
    local world_y = x * sin_angle + y * cos_angle

    world_x = world_x + self._current_x
    world_y = world_y + self._current_y

    return world_x, world_y
end

--- @brief
function rt.Camera:world_xy_to_screen_xy(world_x, world_y)
    local screen_w, screen_h = love.graphics.getDimensions()
    local origin_x, origin_y = 0.5 * screen_w, 0.5 * screen_h

    local x = world_x - self._current_x
    local y = world_y - self._current_y

    local cos_angle = math.cos(self._current_angle)
    local sin_angle = math.sin(self._current_angle)
    local screen_x = x * cos_angle - y * sin_angle
    local screen_y = x * sin_angle + y * cos_angle

    screen_x = screen_x * self._current_scale
    screen_y = screen_y * self._current_scale

    screen_x = screen_x + origin_x
    screen_y = screen_y + origin_y

    return screen_x, screen_y
end

--- @brief
function rt.Camera:get_offset()
    local w, h = love.graphics.getDimensions()
    return -_floor(self._current_x) + 0.5 * w, -_floor(self._current_y) + 0.5 * h
end