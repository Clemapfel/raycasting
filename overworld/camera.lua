require "common.sprite_batch"

rt.settings.overworld.camera = {
    speed = 0.8, -- in [0, 1], where 0 slowest, 1 fastest
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
        _current_scale = 1,

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
function ow.Camera:bind()
    local w, h = love.graphics.getDimensions()
    love.graphics.push()
    love.graphics.origin()

    local origin_x, origin_y = _floor(0.5 * w), _floor(0.5 * h)
    love.graphics.translate(origin_x, origin_y)
    love.graphics.scale(self._current_scale, self._current_scale)
    love.graphics.rotate(self._current_angle)
    love.graphics.translate(-origin_x, -origin_y)
    love.graphics.translate(-_floor(self._current_x) + 0.5 * w, -_floor(self._current_y) + 0.5 * h)
end

--- @brief
function ow.Camera:unbind()
    --love.graphics.rectangle("line", self._bounds_x, self._bounds_y, self._bounds_width, self._bounds_height)
    love.graphics.pop()
end

--- @brief [internal]
function ow.Camera:_constrain(x, y)
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
    local speed = rt.settings.overworld.camera.speed
    return math.sqrt(math.abs(x)) * math.abs(x)^(1 - (1 - speed)) * math.sign(x)
end

function ow.Camera:update(delta)
    local screen_w, screen_h = love.graphics.getDimensions()

    local dx = _distance_f(self._target_x - self._current_x)
    local dy = _distance_f(self._target_y - self._current_y)
    dx = dx / screen_w
    dy = dy / screen_h

    local velocity = rt.settings.overworld.player.velocity * 2
    local max_velocity = rt.settings.overworld.player.velocity * 4
    self._velocity_x = dx * velocity
    self._velocity_y = dy * velocity

    local final_delta_x = self._velocity_x * delta
    local final_delta_y = self._velocity_y * delta

    self._current_x = math.round(self._current_x + final_delta_x)
    self._current_y = math.round(self._current_y + final_delta_y)
end

--- @brief
function ow.Camera:reset()
    self._current_x = self._target_x
    self._current_y = self._target_y
    self._velocity_x = 0
    self._velocity_y = 0
    self._current_angle = 0
    self._current_scale = 1
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
    x, y = self:_constrain(x, y)
    self._target_x = x
    self._target_y = y
    self._current_x = x
    self._current_y = y
end

--- @brief
function ow.Camera:move_to(x, y)
    local before_x, before_y = x, y
    self._target_x, self._target_y = self:_constrain(x, y)
end

--- @brief
function ow.Camera:get_scale()
    return self._current_scale
end

--- @brief
function ow.Camera:set_scale(s)
    self._current_scale = s
    self._target_x, self._target_x = self:_constrain(self._target_x, self._target_y)
end

--- @brief
function ow.Camera:set_bounds(bounds)
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
function ow.Camera:get_bounds()
    return rt.AABB(self._bounds_x, self._bounds_y, self._bounds_width, self._bounds_height)
end

--- @brief
function ow.Camera:set_apply_bounds(b)
    self._apply_bounds = b
end

--- @brief
function ow.Camera:get_apply_bounds()
    return self._apply_bounds
end

--- @brief
function ow.Camera:screen_xy_to_world_xy(screen_x, screen_y)
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
function ow.Camera:world_xy_to_screen_xy(world_x, world_y)
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
