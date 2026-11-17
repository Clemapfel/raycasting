require "common.random"
require "common.smoothed_motion_2d"
require "common.transform"
require "common.envelope"
require "common.request_handler"

rt.settings.camera = {
    max_velocity = 500, -- px per second
    target_velocity = 50,

    max_scale_velocity = 5, -- fraction per second
    target_scale_velocity = 2,

    min_scale = 1 / 4,
    max_scale = 30,

    shake_max_frequency = 30,
    shake_max_offset = 6, -- px
    shake_impulse = {
        envelope_attack = 0,
        envelope_decay = 0,
        default_duration = 0.05,
        default_intensity = 2,
        max_offset = 5,
        frequency = 20, -- nodes per second
    }
}

--- @class rt.Camera
rt.Camera = meta.class("Camera")

--- @brief
function rt.Camera:instantiate()
    local default_speed = 4
    meta.install(self, {
        _position_requests = rt.RequestHandler(0, 0), -- x, y
        _position_motion = rt.SmoothedMotion2D(0, 0),
        
        _angle_requests = rt.RequestHandler(0), -- radians
        _angle_motion = rt.SmoothedMotion1D(0),

        _scale_requests = rt.RequestHandler(0), -- radians
        _scale_motion = rt.SmoothedMotion1D(0),
        
        _speed_request = rt.RequestHandler(default_speed),  -- factor
        _speed_motion = rt.SmoothedMotion1D(default_speed),
        
        _bounds_requests = rt.RequestHandler( -- aabbs
            rt.AABB(-math.huge, -math.huge, math.huge, math.huge)
        ),
        
        _fit_requests = rt.RequestHandler(nil), -- aabbs
        
        _is_enabled_requests = rt.RequestHandler(true), -- booleans
        _use_pixel_scale_requests = rt.RequestHandler(true), -- booleans

        _shake_impulse_sources = {}, -- Table<Duration>
        _transform = rt.Transform(),
        _is_bound = false,
        
        _resolve_needed = true
    })
    
    self._angle_motion:set_is_periodic(true, 0, math.tau)
    self:_update_transform()
end

local _floor = function(x)
    if x == nil then print(debug.traceback()) end
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
    if self._is_bound then return end
    
    love.graphics.push()
    love.graphics.replaceTransform(self._transform:get_native()) -- rounded

    if self._is_enabled == true and rt.GameState:get_is_screen_shake_enabled() then
        love.graphics.translate(
            _clamp(self._shake_offset_x + self._shake_impulse_offset_x),
            _clamp(self._shake_offset_y + self._shake_impulse_offset_y)
        )
    end

    self._is_bound = true
end

--- @brief
function rt.Camera:unbind()
    if self._is_bound == true then
        love.graphics.pop()
        self._is_bound = false
    end
end

--- @brief
function rt.Camera:update(delta)
    meta.assert(delta, mt.Number)
    if self._resolve_needed then self:_resolve() end
    
    -- TODO
end

--- @brief
function rt.Camera:request_position(id, x, y)
    meta.assert(id, mt.Any, x, mt.Number, y, mt.Number)
    self._position_requests:request(id, x, y)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_scale(id, t)
    meta.assert(id, mt.Any, mt.Number, y, mt.Number)
    self._scale_requests:request(id, t)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_fit(id, bounds_or_x, y, w, h)
    meta.assert(id, mt.Any)
    self._fit_requests:request(id, rt.AABB(bounds_or_x, y, w, h))
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_bounds(id, bounds_or_x, y, w, h)
    meta.assert(id, mt.Any)
    self._bounds_requests:request(id, rt.AABB(bounds_or_x, y, w, h))
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_is_enabled(id, b)
    meta.assert(id, mt.Any)
    self._is_enabled_requests:request(id, b)
end

--- @brief
function rt.Camera:get_is_enabled()
    return not self._is_enabled_requests:reduce(rt.RequestReduceMode.AT_LEAST_ONE_FALSE)
end

--- @brief
function rt.Camera:request_use_pixel_scale(id, b)
    meta.assert(id, mt.Any)
    self._use_pixel_scale_requests:request(id, b)
end

--- @brief
function rt.Camera:get_use_pixel_scale()
    return self._use_pixel_scale_requests:reduce(rt.RequestReduceMode.AT_LEAST_ONE_TRUE)
end

--- @brief
function rt.Camera:get_bounds()
    if self._resolve_needed then self:_resolve() end
    local x1, y1 = self._transform:transform_point(0, 0)
    local x2, y2 = self._transform:transform_point(love.graphics.getDimensions())
    return rt.AABB(x1, y1, x2 - x1, y2 - y1)
end

--- @brief
function rt.Camera:get_scale_delta()
    if self._resolve_needed then self:_resolve() end
    return rt.SceneManager:get_height() / rt.settings.native_height
end

--- @brief
function rt.Camera:screen_xy_to_world_xy(screen_x, screen_y)
    meta.assert(screen_x, mt.Number, screen_y, mt.Number)
    if self._resolve_needed then self:_resolve() end
    local x, y, _ = self._transform:inverse_transform_point(screen_x, screen_y, 0)
    return x, y
end

--- @brief
function rt.Camera:world_xy_to_screen_xy(world_x, world_y)
    meta.assert(world_x, mt.Number, world_x, mt.Number)
    if self._resolve_needed then self:_resolve() end
    local x, y, _ = self._transform:transform_point(world_x, world_y, 0)
    return x, y
end

--- @brief
function rt.Camera:get_position()
    if self._resolve_needed then self:_resolve() end
    self._transform:transform_point(0, 0)
end

--- @brief
function rt.Camera:get_final_scale()
    if self._resolve_needed then self:_resolve() end
    -- TODO
end

--- @brief
function rt.Camera:get_world_bounds()
    if self._resolve_needed then self:_resolve() end
    return rt.AABB(0, 0, love.graphics.getDimensions())
end


--- @brief
function rt.Camera:get_transform()
    if self._resolve_needed then self:_resolve() end
    return self._transform:clone()
end

--- @brief
function rt.Camera:set_scale_speed(fraction)
    self._scale_speed:set_speed(fraction)
end

--- @brief
function rt.Camera:get_scale_speed()
    return self._scale_speed:get_speed()
end

--- @brief
function rt.Camera:shake(intensity, duration)
    local settings = rt.settings.camera.shake_impulse
    if duration == nil then duration = settings.default_duration end
    if intensity == nil then intensity = settings.default_intensity end

    meta.assert(intensity, mt.Number, duration, mt.Optional(mt.Number))

    local n_nodes = math.ceil(settings.frequency * duration)

    -- pre-generate random walk on unit circle with opposing directions
    local path = { 0, 0 }
    local current_angle = rt.random.number(0, math.tau)

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
function rt.Camera:_resolve()
    -- TODO
    largest rectangle problem
end 