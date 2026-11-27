require "common.random"
require "common.smoothed_motion_2d"
require "common.transform"
require "common.request_handler"
require "common.path"

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
        _final_x = 0,
        _final_y = 0,
        _final_scale = 1,

        _fit_was_active = false,
        _fit_requests = rt.RequestHandler(nil), -- aabbs
        _use_pixel_scale_requests = rt.RequestHandler(true), -- booleans
        _allow_override_requests = rt.RequestHandler(false), -- booleans

        _shake_requests = rt.RequestHandler(0, 1),
        _shake_path = rt.Path({ 0, 0, 0, 1 }),
        _shake_path_progress = 0,
        _shake_offset_x = 0,
        _shake_offset_y = 0,
        _shake_impulse_offset_x = 0,
        _shake_impulse_offset_y = 0,
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
    return math.clamp(x, -limit, limit)
end

--- @brief
function rt.Camera:bind()
    if self._is_bound then return end
    if self._resolve_needed then self:_resolve() end

    love.graphics.push()
    love.graphics.replaceTransform(self._transform:get_native()) -- rounded

    if rt.GameState:get_is_screen_shake_enabled() then
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
function rt.Camera:request_shake(id, intensity, frequency)
    meta.typecheck(id, mt.Any, intensity, mt.Optional(mt.Number), frequency, mt.Optional(mt.Number))

    if intensity == nil then
        self._shake_requests:request(id, nil, nil)
    else
        if frequency == nil then frequency = 1 end
        self._shake_requests:request(
            id,
            math.clamp(intensity / rt.settings.camera.shake_max_offset, 0, 1),
            math.clamp(frequency, 0, 1)
        )
    end
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
    self._resolve_needed = true
end

--- @brief
function rt.Camera:get_use_pixel_scale()
    return self._use_pixel_scale_requests:reduce(rt.RequestReduceMode.AT_LEAST_ONE_TRUE)
end

--- @brief
function rt.Camera:request_allow_override(id, b)
    meta.typecheck(id, mt.Any, b, mt.Optional(mt.Boolean))
    self._allow_override_requests:request(id, b)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:remove_request_allow_override(id)
    meta.typecheck(id, mt.Any)
    self._allow_override_requests:request(id, nil)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:get_allow_override()
    return self._allow_override_requests:reduce(rt.RequestReduceMode.AT_LEAST_ONE_TRUE)
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
    local x, y = self._final_x, self._final_y
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
    return self._final_x, self._final_y
end

--- @brief
function rt.Camera:get_scale()
    if self._resolve_needed then self:_resolve() end
    return self._final_scale
end

--- @brief
function rt.Camera:get_rotation()
    if self._resolve_needed then self:_resolve() end
    return self._angle_motion:get_value()
end

--- @brief
function rt.Camera:get_final_scale()
    return self:get_scale() * self:get_scale_delta()
end

--- @brief
function rt.Camera:get_scale_delta()
    return rt.SceneManager:get_height() / rt.settings.native_height
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

    local min_x, min_y = math.huge, math.huge
    local max_x, max_y = -math.huge, -math.huge

    for i = 1, #world_corners, 2 do
        min_x, min_y = math.min2(world_corners[i], world_corners[i + 1], min_x, min_y)
        max_x, max_y = math.max2(world_corners[i], world_corners[i + 1], max_x, max_y)
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

    if duration <= 0 then return end

    local n_nodes = math.max(1, math.ceil(settings.frequency * duration))

    -- pre-generate random walk on unit circle with opposing directions
    local points = { 0, 0 }
    local current_angle = rt.random.number(0, math.tau)

    for i = 1, n_nodes do
        local angle_offset = rt.random.number(-math.pi / 4, math.pi / 4)
        -- always make it so the new point is on the opposite half plane
        current_angle = math.normalize_angle(current_angle + math.pi + angle_offset)
        local x, y = math.rotate2(1, 0, current_angle)
        table.insert(points, x)
        table.insert(points, y)
    end

    local path = rt.Path(rt.Polyline(points):close())
    table.insert(self._shake_impulse_sources, {
        start = love.timer.getTime(),
        intensity = intensity,
        duration = duration,
        path = path
    })
end

--- @brief
function rt.Camera:_resolve()
    local target_x, target_y = self._position_requests:reduce(rt.RequestReduceMode.NEWEST)
    local position_speed = self._position_speed_requests:reduce(rt.RequestReduceMode.MAX)

    local angle = self._angle_requests:reduce(rt.RequestReduceMode.NEWEST)
    local angle_speed = self._angle_speed_requests:reduce(rt.RequestReduceMode.MAX)

    local scale = self._scale_requests:reduce(rt.RequestReduceMode.MULTIPLY)
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

local _is_rect_contained = function(x, y, w, h, bounds)
    if w < 0 or h < 0 then return false end
    if w == 0 or h == 0 then return true end

    local x_edges = { x, x + w }
    local y_edges = { y, y + h }

    for aabb in values(bounds) do
        local x1, y1 = aabb.x, aabb.y
        local x2, y2 = aabb.x + aabb.width, aabb.y + aabb.height

        if x1 > x and x1 < x + w then table.insert(x_edges, x1) end
        if x2 > x and x2 < x + w then table.insert(x_edges, x2) end
        if y1 > y and y1 < y + h then table.insert(y_edges, y1) end
        if y2 > y and y2 < y + h then table.insert(y_edges, y2) end
    end

    table.sort(x_edges)
    table.sort(y_edges)

    for yi = 1, #y_edges - 1 do
        local my = math.mix1(y_edges[yi], y_edges[yi + 1], 0.5)
        for xi = 1, #x_edges - 1 do
            local mx = math.mix1(x_edges[xi], x_edges[xi + 1], 0.5)
            local is_covered = false

            for aabb in values(bounds) do
                if mx >= aabb.x and mx <= aabb.x + aabb.width
                    and my >= aabb.y and my <= aabb.y + aabb.height then
                    is_covered = true
                    break
                end
            end

            if not is_covered then return false end
        end
    end

    return true
end

-- find rectangle of maximal area, cenered with aspect ratio, fully contained in union of bounds
local _constrain = function(cx, cy, cw, ch, bounds)
    if cw <= 0 or ch <= 0 then
        return rt.AABB(cx - 0.5 * cw, cy - 0.5 * ch, cw, ch)
    end

    if _is_rect_contained(cx - 0.5 * cw, cy - 0.5 * ch, cw, ch, bounds) then
        return rt.AABB(cx - 0.5 * cw, cy - 0.5 * ch, cw, ch)
    end

    local finite_min_x, finite_min_y = math.huge, math.huge
    local finite_max_x, finite_max_y = -math.huge, -math.huge
    local x_edges, y_edges = {}, {}

    for aabb in values(bounds) do
        local x1, y1 = aabb.x, aabb.y
        local x2, y2 = aabb.x + aabb.width, aabb.y + aabb.height

        if x1 == -math.huge or x2 == math.huge or y1 == -math.huge or y2 == math.huge then
            if cx - 0.5 * cw >= x1 and cx + 0.5 * cw <= x2
                and cy - 0.5 * ch >= y1 and cy + 0.5 * ch <= y2 then
                return rt.AABB(cx - 0.5 * cw, cy - 0.5 * ch, cw, ch)
            end
        end

        if x1 ~= -math.huge and x1 ~= math.huge then
            table.insert(x_edges, x1)
            finite_min_x = math.min(finite_min_x, x1)
            finite_max_x = math.max(finite_max_x, x1)
        end
        if x2 ~= -math.huge and x2 ~= math.huge then
            table.insert(x_edges, x2)
            finite_min_x = math.min(finite_min_x, x2)
            finite_max_x = math.max(finite_max_x, x2)
        end
        if y1 ~= -math.huge and y1 ~= math.huge then
            table.insert(y_edges, y1)
            finite_min_y = math.min(finite_min_y, y1)
            finite_max_y = math.max(finite_max_y, y1)
        end
        if y2 ~= -math.huge and y2 ~= math.huge then
            table.insert(y_edges, y2)
            finite_min_y = math.min(finite_min_y, y2)
            finite_max_y = math.max(finite_max_y, y2)
        end
    end

    local search_min_x = math.min(cx - cw, finite_min_x - cw)
    local search_max_x = math.max(cx + cw, finite_max_x + cw)
    local search_min_y = math.min(cy - ch, finite_min_y - ch)
    local search_max_y = math.max(cy + ch, finite_max_y + ch)

    if search_min_x == math.huge then search_min_x = cx - cw end
    if search_max_x == -math.huge then search_max_x = cx + cw end
    if search_min_y == math.huge then search_min_y = cy - ch end
    if search_max_y == -math.huge then search_max_y = cy + ch end

    table.insert(x_edges, search_min_x)
    table.insert(x_edges, search_max_x)
    table.insert(y_edges, search_min_y)
    table.insert(y_edges, search_max_y)
    table.sort(x_edges)
    table.sort(y_edges)

    local function unique_sorted(values)
        local out = {}
        for i = 1, #values do
            if #out == 0 or values[i] ~= out[#out] then
                table.insert(out, values[i])
            end
        end
        return out
    end

    x_edges = unique_sorted(x_edges)
    y_edges = unique_sorted(y_edges)

    local n_columns = #x_edges - 1
    local n_rows = #y_edges - 1
    if n_columns <= 0 or n_rows <= 0 then
        return rt.AABB(cx - 0.5 * cw, cy - 0.5 * ch, cw, ch)
    end

    local covered = {}
    for yi = 1, n_rows do
        covered[yi] = {}
        local my = math.mix1(y_edges[yi], y_edges[yi + 1], 0.5)
        for xi = 1, n_columns do
            local mx = math.mix1(x_edges[xi], x_edges[xi + 1], 0.5)
            local is_covered = false
            for aabb in values(bounds) do
                if mx >= aabb.x and mx <= aabb.x + aabb.width
                    and my >= aabb.y and my <= aabb.y + aabb.height then
                    is_covered = true
                    break
                end
            end
            covered[yi][xi] = is_covered
        end
    end

    local best_factor = -1
    local best_distance = math.huge
    local best_x, best_y, best_w, best_h = cx - 0.5 * cw, cy - 0.5 * ch, cw, ch

    for y_start = 1, n_rows do
        local columns_are_covered = {}
        for xi = 1, n_columns do columns_are_covered[xi] = true end

        for y_end = y_start, n_rows do
            for xi = 1, n_columns do
                columns_are_covered[xi] = columns_are_covered[xi] and covered[y_end][xi]
            end

            local xi = 1
            while xi <= n_columns do
                if not columns_are_covered[xi] then
                    xi = xi + 1
                else
                    local run_start = xi
                    while xi <= n_columns and columns_are_covered[xi] do
                        xi = xi + 1
                    end
                    local run_end = xi - 1

                    local region_x1, region_x2 = x_edges[run_start], x_edges[run_end + 1]
                    local region_y1, region_y2 = y_edges[y_start], y_edges[y_end + 1]
                    local region_w = region_x2 - region_x1
                    local region_h = region_y2 - region_y1
                    local factor = math.min(1, region_w / cw, region_h / ch)

                    if factor > best_factor then
                        local fitted_w, fitted_h = math.multiply2(cw, ch, factor)
                        local fitted_cx = math.clamp(cx,
                            region_x1 + 0.5 * fitted_w, region_x2 - 0.5 * fitted_w)
                        local fitted_cy = math.clamp(cy,
                            region_y1 + 0.5 * fitted_h, region_y2 - 0.5 * fitted_h)
                        local dx, dy = math.subtract2(fitted_cx, fitted_cy, cx, cy)
                        best_factor = factor
                        best_distance = math.squared_magnitude2(dx, dy)
                        best_x, best_y = fitted_cx - 0.5 * fitted_w, fitted_cy - 0.5 * fitted_h
                        best_w, best_h = fitted_w, fitted_h
                    elseif factor == best_factor then
                        local fitted_w, fitted_h = math.multiply2(cw, ch, factor)
                        local fitted_cx = math.clamp(cx,
                            region_x1 + 0.5 * fitted_w, region_x2 - 0.5 * fitted_w)
                        local fitted_cy = math.clamp(cy,
                            region_y1 + 0.5 * fitted_h, region_y2 - 0.5 * fitted_h)
                        local dx, dy = math.subtract2(fitted_cx, fitted_cy, cx, cy)
                        local distance = math.squared_magnitude2(dx, dy)
                        if distance < best_distance then
                            best_distance = distance
                            best_x, best_y = fitted_cx - 0.5 * fitted_w, fitted_cy - 0.5 * fitted_h
                            best_w, best_h = fitted_w, fitted_h
                        end
                    end
                end
            end
        end
    end

    if best_factor <= 0 then
        return rt.AABB(cx - 0.5 * cw, cy - 0.5 * ch, cw, ch)
    end

    return rt.AABB(best_x, best_y, best_w, best_h)
end

function rt.Camera:update(delta)
    meta.typecheck(delta, mt.Number)

    if self._resolve_needed then
        self:_resolve()
    end

    local target_fit = self._fit_requests:reduce(rt.RequestReduceMode.NEWEST) -- aabb
    local use_override = self._allow_override_requests:reduce(rt.RequestReduceMode.AT_LEAST_ONE_TRUE)
    local has_fit = target_fit ~= nil
    local use_fit = has_fit and not use_override

    if self._fit_was_active and has_fit and use_override then
        self._position_motion:set_position(self._final_x, self._final_y)
        self._scale_motion:set_value(self._final_scale)
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
    local screen_w, screen_h = rt.SceneManager:get_size()
    local downscaling_factor = rt.SceneManager:get_downscaling_factor()

    local target_x, target_y = position_x, position_y
    local bounds = self._bounds_requests_union or {}

    local c, s = math.abs(math.cos(angle)), math.abs(math.sin(angle))
    if not use_fit and self._scale_requests:get_count() == 0 then
        local default_scale = self:get_use_pixel_scale() and rt.SceneManager:get_pixel_scale() or 1
        scale = math.min(scale, default_scale)
    end

    -- constrain to union of bounds
    if use_fit then
        local fit_w = math.dot2(c, s, target_fit.width, target_fit.height)
        local fit_h = math.dot2(s, c, target_fit.width, target_fit.height)
        local scale_x = screen_w * downscaling_factor / math.max(fit_w, 1e-9)
        local scale_y = screen_h * downscaling_factor / math.max(fit_h, 1e-9)

        scale = math.min(scale_x, scale_y)
        target_x = math.mix1(target_fit.x, target_fit.x + target_fit.width, 0.5)
        target_y = math.mix1(target_fit.y, target_fit.y + target_fit.height, 0.5)
    elseif #bounds > 0 then
        local view_w, view_h = math.divide2(
            screen_w * downscaling_factor,
            screen_h * downscaling_factor,
            math.max(scale, 1e-9)
        )

        local bounds_w = math.dot2(c, s, view_w, view_h)
        local bounds_h = math.dot2(s, c, view_w, view_h)
        local fitted = _constrain(target_x, target_y, bounds_w, bounds_h, bounds)
        local fitted_factor = math.min(fitted.width / bounds_w, fitted.height / bounds_h)

        if fitted_factor > 0 and fitted_factor < 1 then
            scale = scale / fitted_factor
        end
        target_x = math.mix1(fitted.x, fitted.x + fitted.width, 0.5)
        target_y = math.mix1(fitted.y, fitted.y + fitted.height, 0.5)
    end

    local shake_intensity, shake_frequency = self._shake_requests:reduce(rt.RequestReduceMode.NEWEST)
    if shake_intensity > 0 and shake_frequency > 0 then
        local distance_traveled = rt.settings.camera.shake_max_frequency * shake_frequency * delta
        while distance_traveled > 0 do
            local path_length = self._shake_path:get_length()
            local remaining = path_length * (1 - self._shake_path_progress)

            if remaining <= math.eps then
                self._shake_path_progress = 1
                local current_x, current_y = self._shake_path:at(1)
                local angle = rt.random.number(0, math.tau)
                local target_x, target_y = math.rotate2(1, 0, angle)
                if math.distance2(current_x, current_y, target_x, target_y) < math.eps then
                    target_x, target_y = -current_x, -current_y
                end
                self._shake_path = rt.Path({ current_x, current_y, target_x, target_y })
                self._shake_path_progress = 0
            elseif distance_traveled >= remaining then
                distance_traveled = distance_traveled - remaining
                local current_x, current_y = self._shake_path:at(1)
                local angle = rt.random.number(0, math.tau)
                local target_x, target_y = math.rotate2(1, 0, angle)
                if math.distance2(current_x, current_y, target_x, target_y) < math.eps then
                    target_x, target_y = -current_x, -current_y
                end
                self._shake_path = rt.Path({ current_x, current_y, target_x, target_y })
                self._shake_path_progress = 0
            else
                self._shake_path_progress = self._shake_path_progress + distance_traveled / path_length
                distance_traveled = 0
            end
        end

        local x, y = self._shake_path:at(self._shake_path_progress)
        self._shake_offset_x, self._shake_offset_y = math.multiply2(
            x, y,
            rt.settings.camera.shake_max_offset * shake_intensity
        )
    else
        self._shake_offset_x, self._shake_offset_y = 0, 0
    end

    local now = love.timer.getTime()
    local impulse_x, impulse_y = 0, 0
    local impulse_settings = rt.settings.camera.shake_impulse
    for i = #self._shake_impulse_sources, 1, -1 do
        local source = self._shake_impulse_sources[i]
        local elapsed = now - source.start
        if elapsed >= source.duration then
            table.remove(self._shake_impulse_sources, i)
        else
            local progress = math.clamp(elapsed / source.duration, 0, 1)
            local envelope = 1
            if impulse_settings.envelope_attack > 0 then
                envelope = math.min(envelope, elapsed / impulse_settings.envelope_attack)
            end
            if impulse_settings.envelope_decay > 0 then
                envelope = math.min(envelope, (source.duration - elapsed) / impulse_settings.envelope_decay)
            end
            envelope = math.clamp(envelope, 0, 1)

            local x, y = source.path:at(progress)
            x, y = math.multiply2(x, y, source.intensity * envelope)

            local magnitude = math.magnitude2(x, y)
            local max_impulse_offset = impulse_settings.max_offset
            if magnitude > max_impulse_offset and magnitude > 0 then
                x, y = math.multiply2(x, y, max_impulse_offset / magnitude)
            end

            impulse_x, impulse_y = math.add2(impulse_x, impulse_y, x, y)
        end
    end

    self._shake_impulse_offset_x = impulse_x
    self._shake_impulse_offset_y = impulse_y
    self._final_x, self._final_y = target_x, target_y
    self._final_scale = scale
    self._fit_was_active = use_fit

    -- update transform
    local t = self._transform:reset()
    t:translate(0.5 * screen_w, 0.5 * screen_h, 0)
    t:scale(scale, scale, 1)
    t:scale(1 / downscaling_factor)

    if self._scale_add ~= nil then
        t:scale(1 + self._scale_add)
    end

    t:rotate_z(angle)
    t:translate(-target_x, -target_y, 0)

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
    self._allow_override_requests:clear()

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

    self._shake_requests:clear()
    self._shake_path = rt.Path({ 0, 0, 0, 1 })
    self._shake_path_progress = 0
    self._shake_offset_x, self._shake_offset_y = 0, 0
    self._shake_impulse_offset_x, self._shake_impulse_offset_y = 0, 0
    self._shake_impulse_sources = {}
    self._bounds_requests_union = {}

    self._fit_was_active = false
    self._resolve_needed = true
end

--- @brief
function rt.Camera:remove_request_position(id)
    meta.typecheck(id, mt.Any)
    self._position_requests:request(id, nil, nil)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:remove_request_scale(id)
    meta.typecheck(id, mt.Any)
    self._scale_requests:request(id, nil)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:remove_request_angle(id)
    meta.typecheck(id, mt.Any)
    self._angle_requests:request(id, nil)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:remove_request_fit(id)
    meta.typecheck(id, mt.Any)
    self._fit_requests:request(id, nil)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:remove_request_shake(id)
    meta.typecheck(id, mt.Any)
    self._shake_requests:request(id, nil, nil)
end

--- @brief
function rt.Camera:remove_request_bounds(id)
    meta.typecheck(id, mt.Any)
    self._bounds_requests:request(id, nil)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:remove_request_use_pixel_scale(id)
    meta.typecheck(id, mt.Any)
    self._use_pixel_scale_requests:request(id, nil)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:remove_request_position_speed(id)
    meta.typecheck(id, mt.Any)
    self._position_speed_requests:request(id, nil)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:remove_request_scale_speed(id)
    meta.typecheck(id, mt.Any)
    self._scale_speed_requests:request(id, nil)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:remove_request_rotation_speed(id)
    meta.typecheck(id, mt.Any)
    self._angle_speed_requests:request(id, nil)
    self._resolve_needed = true
end

--- @brief
function rt.Camera:_add_scale(t)
    self._scale_add = t
end