require "common.random"
require "common.smoothed_motion_2d"
require "common.transform"
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

        _scale_requests = rt.RequestHandler(1), -- fraction
        _scale_motion = rt.SmoothedMotion1D(1),
        
        _position_speed_requests = rt.RequestHandler(default_speed),  -- factor
        _position_speed_motion = rt.SmoothedMotion1D(default_speed),

        _scale_speed_requests = rt.RequestHandler(default_speed),  -- factor
        _scale_speed_motion = rt.SmoothedMotion1D(default_speed),

        _angle_speed_requests = rt.RequestHandler(default_speed), -- factor
        _angle_speed_motion = rt.SmoothedMotion1D(default_speed),
        
        _bounds_requests = rt.RequestHandler( -- aabbs
            rt.AABB(-math.huge, -math.huge, math.huge, math.huge)
        ),
        
        _fit_requests = rt.RequestHandler(nil), -- aabbs
        _use_pixel_scale_requests = rt.RequestHandler(true), -- booleans

        _shake_impulse_sources = {}, -- Table<Duration>
        _transform = rt.Transform(),
        _is_bound = false,
        
        _resolve_needed = true
    })
    
    self._angle_motion:set_is_periodic(true, 0, math.tau)
    self:update(0)
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
    if self._resolve_needed then self:_resolve() end

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
function rt.Camera:request_position(id, x, y)
    meta.typecheck(id, mt.Any, x, mt.Optional(mt.Number), y, mt.Optional(mt.Number))
    self._position_requests:request(id, x, y)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_scale(id, scale)
    meta.typecheck(id, mt.Any, scale, mt.Optional(mt.Number))
    self._scale_requests:request(id, scale)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_angle(id, angle)
    meta.typecheck(id, mt.Any, angle, mt.Optional(mt.Number))
    self._angle_requests:request(id, angle)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_fit(id, bounds_or_x, y, w, h)
    meta.typecheck(id, mt.Any)
    self._fit_requests:request(id, rt.AABB(bounds_or_x, y, w, h))
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_bounds(id, bounds_or_x, y, w, h)
    meta.typecheck(id, mt.Any)
    self._bounds_requests:request(id, rt.AABB(bounds_or_x, y, w, h))
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_use_pixel_scale(id, b)
    meta.typecheck(id, mt.Any, b, mt.Optional(mt.Boolean))
    self._use_pixel_scale_requests:request(id, b)
end

--- @brief
function rt.Camera:get_use_pixel_scale()
    return self._use_pixel_scale_requests:reduce(rt.RequestReduceMode.AT_LEAST_ONE_TRUE)
end

--- @brief
function rt.Camera:request_position_speed(id, speed)
    meta.typecheck(id, mt.Any, speed, mt.Optional(mt.Number))
    self._position_speed_requests:request(id, speed)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_scale_speed(id, speed)
    meta.typecheck(id, mt.Any, speed, mt.Optional(mt.Number))
    self._scale_speed_requests:request(id, speed)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:request_rotation_speed(id, speed)
    meta.typecheck(id, mt.Any, speed, mt.Optional(mt.Number))
    self._angle_speed_requests:request(id, speed)
    self._resolve_needed = true
end


--- @brief
function rt.Camera:get_offset()
    local w, h = rt.SceneManager:get_size()
    local x, y = self._position_motion:get_position()
    local x_offset = -_floor(x + 0.5 * w)
    local y_offset = -_floor(y + 0.5 * h)
    return x_offset, y_offset
end

--- @brief
function rt.Camera:screen_xy_to_world_xy(screen_x, screen_y)
    meta.typecheck(screen_x, mt.Number, screen_y, mt.Number)
    if self._resolve_needed then self:_resolve() end
    local x, y, _ = self._transform:inverse_transform_point(screen_x, screen_y, 0)
    return x, y
end

--- @brief
function rt.Camera:world_xy_to_screen_xy(world_x, world_y)
    meta.typecheck(world_x, mt.Number, world_x, mt.Number)
    if self._resolve_needed then self:_resolve() end
    local x, y, _ = self._transform:transform_point(world_x, world_y, 0)
    return x, y
end

--- @brief
function rt.Camera:get_position()
    if self._resolve_needed then self:_resolve() end
    return self._position_motion:get_position()
end

--- @brief
function rt.Camera:get_scale()
    if self._resolve_needed then self:_resolve() end
    return self._scale_motion:get_value()
end

--- @brief
function rt.Camera:get_rotation()
    if self._resolve_needed then self:_resolve() end
    return self._angle_motion:get_value()
end

--- @brief
function rt.Camera:get_scale_delta()
    return 1
end

--- @brief
function rt.Camera:get_final_scale()
    return self:get_scale()
end

--- @brief
function rt.Camera:get_world_bounds()
    if self._resolve_needed then self:_resolve() end

    local w, h = rt.SceneManager:get_size()
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

    return rt.AABB(
        min_x,
        min_y,
        max_x - min_x,
        max_y - min_y
    )
end

--- @brief
function rt.Camera:get_transform()
    if self._resolve_needed then self:_resolve() end
    return self._transform:clone()
end

--- @brief
function rt.Camera:shake(intensity, duration)
    local settings = rt.settings.camera.shake_impulse
    if duration == nil then duration = settings.default_duration end
    if intensity == nil then intensity = settings.default_intensity end

    meta.typecheck(intensity, mt.Number, duration, mt.Optional(mt.Number))

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

    path = rt.Polyline(path):close()

    table.insert(self._shake_impulse_sources, {
        start = love.timer.getTime(),
        intensity = intensity or settings.default_intensity,
        duration = duration,
        path = rt.Path(path)
    })
end

--- @brief
function rt.Camera:_resolve()
    local target_x, target_y = self._position_requests:reduce(rt.RequestReduceMode.MEAN)
    local position_speed = self._position_speed_requests:reduce(rt.RequestReduceMode.MAX)

    local angle = self._angle_requests:reduce(rt.RequestReduceMode.NEWEST)
    local angle_speed = self._angle_speed_requests:reduce(rt.RequestReduceMode.MAX)

    local scale = self._scale_requests:reduce(rt.RequestReduceMode.MIN)
    local scale_speed = self._scale_speed_requests:reduce(rt.RequestReduceMode.MAX)

    self._bounds_requests_union = {}
    for aabb in values(self._bounds_requests:reduce(rt.RequestReduceMode.ENUMERATE)) do
        table.insert(self._bounds_requests_union, aabb)
    end

    local use_pixel_scale = self._use_pixel_scale_requests:reduce(rt.RequestReduceMode.AT_LEAST_ONE_TRUE)
    self._position_motion:set_target_position(target_x, target_y)
    self._position_speed_motion:set_target_value(position_speed)

    self._scale_motion:set_target_value(scale * (use_pixel_scale and rt.SceneManager:get_pixel_scale() or 1))
    self._scale_speed_motion:set_target_value(scale_speed)

    self._angle_motion:set_target_value(angle)
    self._angle_speed_motion:set_target_value(angle_speed)

    self._resolve_needed = false
end

-- find rectangle of maximal area, cenered with aspect ratio, fully contained in union of bounds
local _constrain = function(center_x, center_y, aspect, bounds)
    local has_top_left = false
    local has_top_right = false
    local has_bottom_left = false
    local has_bottom_right = false

    for aabb in values(bounds) do
        local x, y, w, h = aabb:unpack()
        local right, bottom = x + w, y + h

        if x < center_x and right >= center_x
            and y < center_y and bottom >= center_y then
            has_top_left = true
        end

        if x <= center_x and right > center_x
            and y < center_y and bottom >= center_y then
            has_top_right = true
        end

        if x < center_x and right >= center_x
            and y <= center_y and bottom > center_y then
            has_bottom_left = true
        end

        if x <= center_x and right > center_x
            and y <= center_y and bottom > center_y then
            has_bottom_right = true
        end
    end

    if not (has_top_left and has_top_right
        and has_bottom_left and has_bottom_right) then
        return rt.AABB(center_x, center_y, 0, 0)
    end

    local min_height = math.huge

    local consider_vertical = function(edge_x, edge_top, edge_bottom, is_left)
        local cuts = {edge_top, edge_bottom}

        for aabb in values(bounds) do
            local x, y, w, h = aabb:unpack()
            local right = x + w

            if (is_left and (x < edge_x and right >= edge_x)
                or (not is_left and x <= edge_x and right > edge_x))
                and y < edge_bottom
                and y + h > edge_top
            then
                table.insert(cuts, math.max(edge_top, y))
                table.insert(cuts, math.min(edge_bottom, y + h))
            end
        end

        table.sort(cuts)

        for i = 1, #cuts - 1 do
            local top = cuts[i]
            local bottom = cuts[i + 1]

            if bottom > top then
                local mid_y = 0.5 * (top + bottom)
                local covered = false

                for aabb in values(bounds) do
                    local x, y, w, h = aabb:unpack()
                    local right = x + w

                    if (is_left and (x < edge_x and right >= edge_x)
                        or (not is_left and x <= edge_x and right > edge_x))
                        and y <= mid_y
                        and y + h >= mid_y
                    then
                        covered = true
                        break
                    end
                end

                if not covered then
                    min_height = math.min(min_height, math.max(
                        math.abs(edge_x - center_x) / aspect,
                        math.max(top - center_y, center_y - bottom, 0)
                    ))
                end
            end
        end
    end

    local consider_horizontal = function(edge_y, edge_left, edge_right, is_top)
        local cuts = { edge_left, edge_right }

        for aabb in values(bounds) do
            local x, y, w, h = aabb:unpack()
            local bottom = y + h

            if (is_top and (y < edge_y and bottom >= edge_y)
                or (not is_top and y <= edge_y and bottom > edge_y))
                and x < edge_right
                and x + w > edge_left
            then
                table.insert(cuts, math.max(edge_left, x))
                table.insert(cuts, math.min(edge_right, x + w))
            end
        end

        table.sort(cuts)

        for i = 1, #cuts - 1 do
            local left = cuts[i]
            local right = cuts[i + 1]

            if right > left then
                local mid_x = 0.5 * (left + right)
                local covered = false

                for aabb in values(bounds) do
                    local x, y, w, h = aabb:unpack()
                    local bottom = y + h

                    if (is_top and (y < edge_y and bottom >= edge_y)
                        or (not is_top and y <= edge_y and bottom > edge_y))
                        and x <= mid_x
                        and x + w >= mid_x
                    then
                        covered = true
                        break
                    end
                end

                if not covered then
                    min_height = math.min(min_height, math.max(
                        math.abs(edge_y - center_y),
                        math.max(left - center_x, center_x - right, 0) / aspect
                    ))
                end
            end
        end
    end

    for aabb in values(bounds) do
        local x, y, w, h = aabb:unpack()

        consider_vertical(x, y, y + h, true)
        consider_vertical(x + w, y, y + h, false)

        consider_horizontal(y, x, x + w, true)
        consider_horizontal(y + h, x, x + w, false)
    end

    local final_h = 2 * min_height
    local final_w = aspect * final_h

    return rt.AABB(
        center_x - 0.5 * final_w,
        center_y - 0.5 * final_h,
        final_w,
        final_h
    )
end

--- @brief
function rt.Camera:update(delta)
    meta.typecheck(delta, mt.Number)

    if self._resolve_needed then
        self:_resolve()
    end

    for to_update in range(
        self._position_motion,
        self._position_speed_motion,
        self._angle_motion,
        self._angle_speed_motion,
        self._scale_motion,
        self._scale_speed_motion
    ) do
        to_update:update(delta)
    end

    self._position_motion:set_speed(self._position_speed_motion:get_value())
    self._angle_motion:set_speed(self._angle_speed_motion:get_value())
    self._scale_motion:set_speed(self._scale_speed_motion:get_value())

    local position_x, position_y = self._position_motion:get_position()
    local angle = self._angle_motion:get_value()
    local scale = self._scale_motion:get_value()

    local target_w, target_h = rt.SceneManager:get_size()
    target_w = target_w * scale
    target_h = target_h * scale

    local target_x, target_y = position_x, position_y
    local screen_w, screen_h = rt.SceneManager:get_size()

    -- constrain to union of bounds
    if self._bounds_requests:get_count() > 0 then
        local fitted = _constrain(
            target_x, target_y, screen_w / screen_h,
            self._bounds_requests:reduce(rt.RequestReduceMode.ENUMERATE)
        )

        local fitted_h = fitted.height
        if fitted_h > 0 and fitted_h < math.huge then
            scale = math.max(1, screen_h / fitted_h)
        end
    end

    -- update transform
    local t = self._transform:reset()
    t:translate(_floor(0.5 * screen_w), _floor(0.5 * screen_h), 0)
    t:scale(scale, scale, 1)
    t:scale(1 / rt.SceneManager:get_downscaling_factor())
    t:rotate_z(angle)
    t:translate(-_floor(target_x), -_floor(target_y), 0)

    if self._is_bound then
        self:unbind()
        self:bind()
    end
end

--- @brief
function rt.Camera:reset()
    local default_speed = 4

    -- clear all requests
    self._position_requests:clear()
    self._angle_requests:clear()
    self._scale_requests:clear()

    self._position_speed_requests:clear()
    self._scale_speed_requests:clear()
    self._angle_speed_requests:clear()

    self._bounds_requests:clear()
    self._fit_requests:clear()
    self._use_pixel_scale_requests:clear()

    self._position_motion:set_position(0, 0)
    self._position_motion:set_target_position(0, 0)

    self._angle_motion:set_value(0)
    self._angle_motion:set_target_value(0)

    self._scale_motion:set_value(1)
    self._scale_motion:set_target_value(1)

    self._position_speed_motion:set_value(default_speed)
    self._position_speed_motion:set_target_value(default_speed)

    self._scale_speed_motion:set_value(default_speed)
    self._scale_speed_motion:set_target_value(default_speed)

    self._angle_speed_motion:set_value(default_speed)
    self._angle_speed_motion:set_target_value(default_speed)

    self._shake_impulse_sources = {}
    self._bounds_requests_union = {}

    self._resolve_needed = true
end