require "common.random"
require "common.smoothed_motion_2d"
require "common.transform"

rt.settings.camera = {
    max_velocity = 500, -- px per second
    target_velocity = 100,

    max_scale_velocity = 5, -- fraction per second
    target_scale_velocity = 2,

    min_scale = 1 / 4,
    max_scale = 30,
    shake_max_frequency = 30,
    shake_max_offset = 6, -- px
    shake_speed = 100,

    shake_impulse = {
        envelope_attack = 0,
        envelope_decay = 0,
        default_duration = 0.05,
        default_intensity = 1,
        max_offset = 5,
        frequency = 35, -- nodes per second
    }
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
        _speed = 1, -- fraction

        _current_angle = 0,

        _current_scale = 1,
        _target_scale = 1,
        _scale_speed = 1, -- fraction

        _last_x = 0,
        _last_y = 0,

        _bounds = rt.AABB(
            -math.huge, -math.huge,
            math.huge, math.huge
        ),
        _apply_bounds = true,

        _is_shaking = false,
        _shake_intensity = 0,
        _shake_frequency = 1,
        _shake_offset_x = 0,
        _shake_offset_y = 0,

        _shake_elapsed = 0,
        _shake_from_x = 0,
        _shake_from_y = 0,
        _shake_to_x = 0,
        _shake_to_y = 1,
        _shake_current_x = 0,
        _shake_current_y = 0,

        _shake_impulse_sources = {}, -- cf. Camera.shake
        _shake_impulse_offset_x = 0,
        _shake_impulse_offset_y = 0,

        _world_bounds = rt.AABB(0, 0, 0, 0),
        _world_bounds_needs_update = true,

        _push_stack = {},
        _transform = rt.Transform()
    })

    self:_update_bounds()
    self:set_shake_frequency(1)
end

local _floor = function(x)
    return math.floor(x)
end

local _clamp = function(x)
    local limit = rt.settings.camera.shake_max_offset
    local sign = math.sign(x)
    if math.abs(x) > limit then
        return sign * limit
    else
        return x
    end
end

--- @brief
function rt.Camera:bind()
    love.graphics.push()
    love.graphics.replaceTransform(self._transform:get_native()) -- rounded

    if rt.GameState:get_is_screen_shake_enabled() then
        -- leave shake unrounded, subpixel precision
        love.graphics.translate(
            _clamp(self._shake_offset_x + self._shake_impulse_offset_x),
            _clamp(self._shake_offset_y + self._shake_impulse_offset_y)
        )
    end
end

--- @brief
function rt.Camera:unbind()
    love.graphics.pop()
end

--- @brief [internal]
function rt.Camera:_constrain(x, y)
    if self._apply_bounds ~= true then return x, y end

    local screen_w, screen_h = love.graphics.getDimensions()

    local half_w = screen_w / self._current_scale / 2
    local half_h = screen_h / self._current_scale / 2

    local min_x, max_x = self._bounds.x + half_w,
    self._bounds.x + self._bounds.width - half_w

    local min_y, max_y = self._bounds.y + half_h,
    self._bounds.y + self._bounds.height - half_h

    min_x, max_x = math.ceil(min_x), math.floor(max_x)
    min_y, max_y = math.ceil(min_y), math.floor(max_y)

    if x > max_x then x = max_x end
    if x < min_x then x = min_x end

    if y > max_y then y = max_y end
    if y < min_y then y = min_y end

    return x, y
end

local _distance_easing = function(x, delta, speed)
    local eps = 0.5
    local exponent = math.mix(1.5 - eps, 1.5 + eps, speed / 2)
    return math.sign(x) * math.abs(x)^exponent * delta
end

local _scale_easing = function(x, delta, speed)
    local duration = 0.5
    local eps = 0.2
    local exponent = math.mix(1.8 - eps, 1.8 + eps, speed / 2)
    return x * (1 - (1 - delta / duration)^exponent)
end

--- @brief
function rt.Camera:update(delta)
    local screen_w, screen_h = love.graphics.getDimensions()

    do -- scale
        -- work in log space, where relative scales are equidistant regardless of value
        local scale_eps = math.eps
        local current_scale = math.log(math.max(scale_eps, self._current_scale))
        local target_scale = math.log(math.max(scale_eps, self._target_scale))

        local delta_scale = _scale_easing(target_scale - current_scale, delta, self._scale_speed)

        -- convert limit to log space
        local max_scale_velocity = rt.settings.camera.max_scale_velocity
        local actual_scale_change = self._current_scale * (math.exp(delta_scale) - 1)
        local max_scale_change = self._current_scale * max_scale_velocity * delta

        if math.abs(actual_scale_change) > max_scale_change then
            delta_scale = math.sign(delta_scale) * math.log(1 + max_scale_change / self._current_scale)
        end

        self._current_scale = math.exp(current_scale + delta_scale)
        self._current_scale = math.clamp(self._current_scale, rt.settings.camera.min_scale, rt.settings.camera.max_scale)
    end

    if self._apply_bounds then
        self._target_x, self._target_y = self:_constrain(self._target_x, self._target_y)
    end

    do -- movement
        local dx = _distance_easing(self._target_x - self._current_x, delta, self._speed)
        local dy = _distance_easing(self._target_y - self._current_y, delta, self._speed)

        local max_displacement = rt.settings.player.max_velocity * delta
        dx = math.clamp(dx, -max_displacement, max_displacement)
        dy = math.clamp(dy, -max_displacement, max_displacement)

        self._last_x, self._last_y = self._current_x, self._current_y

        self._current_x = self._current_x + dx
        self._current_y = self._current_y + dy
    end

    -- continuous shaking
    if self._is_shaking then
        local max_frequency = rt.settings.camera.shake_max_frequency
        local offset = rt.settings.camera.shake_max_offset * self._shake_intensity

        local speed = self._shake_frequency * max_frequency
        local distance_traveled = speed * delta
        while distance_traveled > 0 do
            local dist = math.distance(self._shake_current_x, self._shake_current_y, self._shake_to_x, self._shake_to_y)
            if distance_traveled >= dist then
                self._shake_current_x = self._shake_to_x
                self._shake_current_y = self._shake_to_y
                self._shake_from_x = self._shake_to_x
                self._shake_from_y = self._shake_to_y
                self._shake_to_x = math.cos(rt.random.number(0, 2 * math.pi))
                self._shake_to_y = math.sin(rt.random.number(0, 2 * math.pi))
                distance_traveled = distance_traveled - dist
            else
                local sdx, sdy = math.normalize(self._shake_to_x - self._shake_from_x, self._shake_to_y - self._shake_from_y)
                self._shake_current_x = self._shake_current_x + sdx * distance_traveled
                self._shake_current_y = self._shake_current_y + sdy * distance_traveled
                self._shake_offset_x, self._shake_offset_y = self._shake_current_x * offset, self._shake_current_y * offset
                distance_traveled = 0
                break
            end
        end
    end

    -- impulse shaking
    do
        self._shake_impulse_offset_x = 0
        self._shake_impulse_offset_y = 0

        local settings = rt.settings.camera.shake_impulse

        local envelope = function(x)
            return rt.InterpolationFunctions.ENVELOPE(x,
                settings.envelope_attack,
                settings.envelope_decay
            )
        end

        local now = love.timer.getTime()
        local max_offset = settings.max_offset

        local to_remove = {}
        for i, entry in ipairs(self._shake_impulse_sources) do
            local t = math.min(1, (now - entry.start) / entry.duration)
            local intensity = envelope(t) * entry.intensity
            local x, y = entry.path:at(t)

            self._shake_impulse_offset_x = self._shake_impulse_offset_x + x * max_offset * intensity
            self._shake_impulse_offset_y = self._shake_impulse_offset_y + y * max_offset * intensity

            if t >= 1 then
                table.insert(to_remove, 1, i)
            end
        end

        for i in values(to_remove) do
            table.remove(self._shake_impulse_sources, i)
        end
    end

    -- update transform
    local t = self._transform:reset()
    t:translate(_floor(0.5 * screen_w), _floor(0.5 * screen_h), 0)
    t:scale(self._current_scale, self._current_scale, 1)
    t:scale(rt.get_pixel_scale())
    t:rotate_z(self._current_angle)
    -- Snap to integer pixels only at draw time to avoid blur; this also matches our conservative _constrain().
    t:translate(-_floor(self._current_x), -_floor(self._current_y), 0)

    self._world_bounds_needs_update = true
end

--- @brief
function rt.Camera:reset()
    self._current_x = self._target_x
    self._current_y = self._target_y
    self._current_angle = 0
    self._current_scale = 1

    self._world_bounds_needs_update = true
end

--- @brief
function rt.Camera:get_rotation()
    return self._current_angle
end

--- @brief
function rt.Camera:set_rotation(r)
    self._current_angle = r

    self._world_bounds_needs_update = true
end

--- @brief
function rt.Camera:get_position()
    return self._current_x, self._current_y
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

    self._world_bounds_needs_update = true
end

--- @brief
function rt.Camera:move_to(x, y, override_bounds)
    meta.assert(x, "Number", y, "Number")
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
    return (love.graphics.getHeight() / rt.settings.native_height)
end

--- @brief
function rt.Camera:set_scale(s, override_bounds)
    self._current_scale = s
    self._target_scale = s

    if override_bounds ~= true then
        -- Fix: assign both target X and Y after constraining.
        self._target_x, self._target_y = self:_constrain(self._target_x, self._target_y)
    end

    self._world_bounds_needs_update = true
end

--- @brief
function rt.Camera:scale_to(s)
    self._target_scale = s
end

function rt.Camera:fit_to(bounds, center_x, center_y)
    meta.assert(bounds, "AABB")

    local screen_w, screen_h = love.graphics.getDimensions()
    local pixel_scale = self:get_scale_delta()

    local bw = math.max(math.eps, bounds.width)
    local bh = math.max(math.eps, bounds.height)

    local scale_x = screen_w / (pixel_scale * bw)
    local scale_y = screen_h / (pixel_scale * bh)
    local target_scale = math.min(scale_x, scale_y)
    target_scale = math.clamp(target_scale, rt.settings.camera.min_scale, rt.settings.camera.max_scale)

    local cx = center_x or (bounds.x + 0.5 * bounds.width)
    local cy = center_y or (bounds.y + 0.5 * bounds.height)

    self:scale_to(target_scale)
    self:move_to(cx, cy, true)
end

--- @brief
function rt.Camera:set_bounds(bounds)
    if bounds ~= nil then
        meta.assert(bounds, "AABB")
        self._bounds:reformat(bounds:unpack())
    else
        self._bounds:reformat(
            -math.huge, -math.huge,
            math.huge, math.huge
        )
    end

    self._world_bounds_needs_update = true
end

--- @brief
function rt.Camera:get_bounds()
    return self._bounds:clone()
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
    local x, y, _ = self._transform:inverse_transform_point(screen_x, screen_y, 0)
    return x, y
end

--- @brief
function rt.Camera:world_xy_to_screen_xy(world_x, world_y)
    local x, y, _ = self._transform:transform_point(world_x, world_y, 0)
    return x, y
end

--- @brief
function rt.Camera:get_world_bounds()
    if self._world_bounds_needs_update then self:_update_bounds() end
    return self._world_bounds:clone()
end

--- @brief
--- @param intensity Number in [0, 1]
function rt.Camera:set_is_shaking(b)
    self._is_shaking = b
    if b == false then
        self._shake_offset_x = 0
        self._shake_offset_y = 0
    end
end

--- @brief
function rt.Camera:set_shake_intensity(i)
    self._shake_intensity = math.clamp(i, 0, 1)
end

--- @brief
function rt.Camera:set_shake_intensity_in_pixels(n)
    self:set_shake_intensity(n / rt.settings.camera.shake_max_offset)
end

--- @brief
function rt.Camera:set_shake_frequency(i)
    self._shake_frequency = math.clamp(i, 0, 1)
end

--- @brief
function rt.Camera:shake(intensity, duration)
    local settings = rt.settings.camera.shake_impulse

    duration = duration or settings.default_duration
    local n_nodes = math.ceil(settings.frequency * duration)

    -- pre-generate random walk on unit circle with opposing directions
    local path = { 0, 0 }
    local current_angle = rt.random.number(0, 2 * math.pi)

    for i = 1, n_nodes do
        local angle_offset = rt.random.number(-math.pi / 4, math.pi / 4)
        -- always make it so the new point is on the opposite half plane
        current_angle = current_angle + math.pi + angle_offset

        table.insert(path, math.cos(current_angle))
        table.insert(path, math.sin(current_angle))
    end

    table.insert(path, 0)
    table.insert(path, 0)

    table.insert(self._shake_impulse_sources, {
        start = love.timer.getTime(),
        intensity = intensity or settings.default_intensity,
        duration = duration,
        path = rt.Path(path)
    })
end

--- @brief
function rt.Camera:get_offset()
    local w, h = love.graphics.getDimensions()
    local x_offset = -_floor(self._current_x + 0.5 * w)
    local y_offset = -_floor(self._current_y + 0.5 * h)

    if rt.GameState:get_is_screen_shake_enabled() then
        x_offset = x_offset + _clamp(self._shake_offset_x + self._shake_impulse_offset_x)
        y_offset = y_offset + _clamp(self._shake_offset_y + self._shake_impulse_offset_y)
    end

    return x_offset, y_offset
end

--- @brief
function rt.Camera:_update_bounds()
    local w, h = love.graphics.getDimensions()
    local screen_corners = {
        0, 0,
        w, 0,
        w, h,
        0, h
    }

    local world_corners = {}
    for i = 1, #screen_corners, 2 do
        local wx, wy, _ = self._transform:inverse_transform_point(screen_corners[i+0], screen_corners[i+1], 0)
        table.insert(world_corners, wx)
        table.insert(world_corners, wy)
    end

    local min_x = math.huge
    local min_y = math.huge
    local max_x = -math.huge
    local max_y = -math.huge

    for i = 1, #world_corners, 2 do
        local wx, wy = world_corners[i+0], world_corners[i+1]
        min_x = math.min(min_x, wx)
        min_y = math.min(min_y, wy)
        max_x = math.max(max_x, wx)
        max_y = math.max(max_y, wy)
    end

    self._world_bounds:reformat(
        min_x,
        min_y,
        max_x - min_x,
        max_y - min_y
    )

    self._world_bounds_needs_update = false
end

--- @brief
function rt.Camera:get_transform()
    return self._transform:clone()
end

--- @brief
function rt.Camera:set_scale_speed(fraction)
    self._scale_speed = fraction or 1
end

--- @brief
function rt.Camera:get_scale_speed()
    return self._scale_speed
end

--- @brief
function rt.Camera:set_speed(fraction)
    self._speed = fraction or 1
end

--- @brief
function rt.Camera:get_speed()
    return self._speed
end