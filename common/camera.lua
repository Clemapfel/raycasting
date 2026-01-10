require "common.random"
require "common.smoothed_motion_2d"
require "common.transform"

rt.settings.camera = {
    speed = 0.8, -- in [0, 1], where 0 slowest, 1 fastest
    max_velocity = 1800,
    max_scale_velocity = 5, -- per second
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

        _velocity_x = 0,
        _velocity_y = 0,

        _current_angle = 0,
        _current_scale = 1,
        _target_scale = 1,

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

local _floor = math.floor --function(x) return x end

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
    love.graphics.replaceTransform(self._transform:get_native())

    if rt.GameState:get_is_screen_shake_enabled() then
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

--- @brief
function rt.Camera:push()
    table.insert(self._push_stack, {
        _current_x = self._current_x,
        _current_y = self._current_y,
        _target_x = self._target_x,
        _target_y = self._target_y,
        _velocity_x = self._velocity_x,
        _velocity_y = self._velocity_y,
        _current_angle = self._current_angle,
        _current_scale = self._current_scale,
        _shake_offset_x = self._shake_offset_x,
        _shake_offset_y = self._shake_offset_y,
        _shake_impulse_offset_x = self._shake_impulse_offset_x,
        _shake_impulse_offset_y = self._shake_impulse_offset_y
    })
end

--- @brief
function rt.Camera:pop()
    local state = table.remove(self._push_stack)
    if state == nil then
        rt.warning("rt.Camera:pop: pop called but push stack is empty")
        return
    end

    for k, v in pairs(state) do
        self[k] = v
    end

    self._world_bounds_needs_update = true
end

--- @brief [internal]
--- @brief [internal]
function rt.Camera:_constrain(x, y)
    if self._apply_bounds == true then
        local screen_w, screen_h = love.graphics.getDimensions()

        local visible_w = screen_w / self._current_scale / 2
        local visible_h = screen_h / self._current_scale / 2

        if visible_w >= self._bounds.width then
            x = self._bounds.x + self._bounds.width / 2
        else
            local min_x = self._bounds.x + visible_w
            local max_x = self._bounds.x + self._bounds.width - visible_w
            x = math.clamp(x, min_x, max_x)
        end

        if visible_h >= self._bounds.height then
            y = self._bounds.y + self._bounds.height / 2
        else
            local min_y = self._bounds.y + visible_h
            local max_y = self._bounds.y + self._bounds.height - visible_h
            y = math.clamp(y, min_y, max_y)
        end
    end

    return x, y
end

local _distance_f = function(x)
    local speed = rt.settings.camera.speed
    return math.sqrt(math.abs(x)) * math.abs(x)^(1 - (1 - speed)) * math.sign(x)
end

local _round = function(x)
    return math.floor(x)
end

--- @brief
function rt.Camera:update(delta)
    local screen_w, screen_h = love.graphics.getDimensions()

    do -- scale
        local ds = math.log(math.max(math.eps, self._target_scale))
            - math.log(math.max(math.eps, self._current_scale))

        local scale_velocity = math.sign(ds) * math.min(math.abs(ds), rt.settings.camera.max_scale_velocity)

        self._current_scale = self._current_scale * math.exp(scale_velocity * delta)
        self._current_scale = math.clamp(self._current_scale, rt.settings.camera.min_scale, rt.settings.camera.max_scale)
    end

    -- Constrain target position based on current scale and bounds
    if self._apply_bounds then
        self._target_x, self._target_y = self:_constrain(self._target_x, self._target_y)
    end

    do -- movement
        local dx = _distance_f(self._target_x - self._current_x)
        local dy = _distance_f(self._target_y - self._current_y)
        dx = dx / screen_w
        dy = dy / screen_h

        self._velocity_x = dx * rt.settings.camera.max_velocity
        self._velocity_y = dy * rt.settings.camera.max_velocity

        local final_delta_x = self._velocity_x * delta
        local final_delta_y = self._velocity_y * delta

        self._last_x, self._last_y = self._current_x, self._current_y
        self._current_x = _round(self._current_x + final_delta_x)
        self._current_y = _round(self._current_y + final_delta_y)
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
    t:translate(0.5 * screen_w, 0.5 * screen_h, 0)
    t:scale(self._current_scale, self._current_scale, 1)
    t:scale(rt.get_pixel_scale())
    t:rotate_z(self._current_angle)
    t:translate(-self._current_x, -self._current_y, 0)

    self._world_bounds_needs_update = true
end

--- @brief
function rt.Camera:reset()
    self._current_x = self._target_x
    self._current_y = self._target_y
    self._velocity_x = 0
    self._velocity_y = 0
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
        self._target_x, self._target_x = self:_constrain(self._target_x, self._target_y)
    end

    self._world_bounds_needs_update = true
end

--- @brief
function rt.Camera:scale_to(s)
    self._target_scale = s
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
    local x_offset = -_floor(self._current_x) + _floor(0.5 * w)
    local y_offset = -_floor(self._current_y) + _floor(0.5 * h)

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