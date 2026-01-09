rt.settings.spline = {
    discretize_maximum_recursion_depth = 15,
    metric_threshold = 5,
    metric_curvature_weight = 10
}

--- @brief rt.Spline
rt.Spline = meta.class("Spline")

--- @brief
function rt.Spline:instantiate(...)
    self:create_from(...)
end

--- @brief
function rt.Spline:create_from(...)
    local first = select(1, ...)
    local points
    if type(first) == "number" then
        points = {...}
    else
        points = first
    end

    if #points < 2 or #points % 2 ~= 0 then
        rt.error("In rt.Spline: number of coordinates is not a multiple of 2")
    end

    if #points < 4 then
        -- line is point
        table.insert(points, points[1])
        table.insert(points, points[2])
    end

    -- Check if spline should be closed (first and last points are very close)
    local first_x, first_y = points[1], points[2]
    local last_x, last_y = points[#points - 1], points[#points]
    local is_closed = math.distance(first_x, first_y, last_x, last_y) < math.eps

    if is_closed then
        -- For closed splines, use actual neighboring points as phantoms
        -- Phantom at start: use second-to-last real point
        local p0_x = points[#points - 3]
        local p0_y = points[#points - 2]
        table.insert(points, 1, p0_y)
        table.insert(points, 1, p0_x)

        -- Phantom at end: use second real point
        local pn_x = points[5]  -- After inserting two values at start, second point is at index 5
        local pn_y = points[6]
        table.insert(points, pn_x)
        table.insert(points, pn_y)
    else
        -- For open splines, use reflected phantom points
        local p0_x = 2 * points[1] - points[3]
        local p0_y = 2 * points[2] - points[4]
        table.insert(points, 1, p0_y)
        table.insert(points, 1, p0_x)

        local n = #points
        local pn_x = 2 * points[n - 1] - points[n - 3]
        local pn_y = 2 * points[n] - points[n - 2]
        table.insert(points, pn_x)
        table.insert(points, pn_y)
    end

    self._points = points
    self._is_closed = is_closed
    self._length = nil -- computed on first query
end

local _catmull_rom_basis = function(t, p0, p1, p2, p3)
    local t2 = t * t
    local t3 = t2 * t

    return 0.5 * (
        (2 * p1) +
            (-p0 + p2) * t +
            (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 +
            (-p0 + 3 * p1 - 3 * p2 + p3) * t3
    )
end

--- @brief
function rt.Spline:at(t)
    t = math.clamp(t, 0, 1)

    local points = self._points
    local num_points = #points / 2
    local num_segments = num_points - 3

    if t == 0 then
        return points[3], points[4]  -- first real point (after phantom)
    elseif t == 1 then
        return points[#points - 3], points[#points - 2]  -- last real point (before phantom)
    end

    -- get segment
    local segment_float = t * num_segments
    local segment_index = math.floor(segment_float)
    local local_t = segment_float - segment_index

    if segment_index >= num_segments then
        segment_index = num_segments - 1
        local_t = 1.0
    end

    -- get control points
    local base_idx = segment_index * 2 + 1
    local p0_x, p0_y = points[base_idx], points[base_idx + 1]
    local p1_x, p1_y = points[base_idx + 2], points[base_idx + 3]
    local p2_x, p2_y = points[base_idx + 4], points[base_idx + 5]
    local p3_x, p3_y = points[base_idx + 6], points[base_idx + 7]

    return _catmull_rom_basis(local_t, p0_x, p1_x, p2_x, p3_x),
    _catmull_rom_basis(local_t, p0_y, p1_y, p2_y, p3_y)
end

-- derivative of basis function
local _catmull_rom_derivative = function(t, p0, p1, p2, p3)
    local t2 = t * t
    return 0.5 * (
        (-p0 + p2) +
            (4 * p0 - 10 * p1 + 8 * p2 - 2 * p3) * t +
            (-3 * p0 + 9 * p1 - 9 * p2 + 3 * p3) * t2
    )
end

-- get tangent at t
function rt.Spline:get_derivative_at(t)
    t = math.clamp(t, 0, 1)

    local points = self._points
    local num_points = #points / 2
    local num_segments = num_points - 3

    if num_segments < 1 then
        return 0, 0
    end

    -- handle edge cases with small epsilon to avoid division by zero
    if t <= math.eps then
        t = math.eps
    elseif t >= 1 - math.eps then
        t = 1 - math.eps
    end

    -- get segment
    local segment_float = t * num_segments
    local segment_index = math.floor(segment_float)
    local local_t = segment_float - segment_index

    if segment_index >= num_segments then
        segment_index = num_segments - 1
        local_t = 1.0
    end

    -- get control points
    local base_idx = segment_index * 2 + 1
    local p0_x, p0_y = points[base_idx], points[base_idx + 1]
    local p1_x, p1_y = points[base_idx + 2], points[base_idx + 3]
    local p2_x, p2_y = points[base_idx + 4], points[base_idx + 5]
    local p3_x, p3_y = points[base_idx + 6], points[base_idx + 7]

    -- calculate derivative and scale by segment density
    local dx = _catmull_rom_derivative(local_t, p0_x, p1_x, p2_x, p3_x) * num_segments
    local dy = _catmull_rom_derivative(local_t, p0_y, p1_y, p2_y, p3_y) * num_segments

    return dx, dy
end

-- adaptive gauss-legendre quadrature for arc length integration
local _integrate
do
    -- 5-point Gauss-Legendre quadrature weights and nodes
    local _nodes = { -0.9061798459, -0.5384693101, 0, 0.5384693101, 0.9061798459 }
    local _weights = { 0.2369268851, 0.4786286705, 0.5688888889, 0.4786286705, 0.2369268851 }

    _integrate = function(a, b, f)
        local function gauss_integrate(start, stop)
            local mid = (start + stop) * 0.5
            local half_width = (stop - start) * 0.5
            local result = 0

            for i = 1, 5 do
                local x = mid + half_width * _nodes[i]
                result = result + _weights[i] * f(x)
            end

            return result * half_width
        end

        local function adaptive_step(start, stop, whole_integral, depth)
            if depth > 20 then  -- maximum recursion depth for safety
                return whole_integral
            end

            local mid = (start + stop) * 0.5
            local left = gauss_integrate(start, mid)
            local right = gauss_integrate(mid, stop)
            local combined = left + right

            if math.abs(combined - whole_integral) < math.eps then
                return combined
            else
                return adaptive_step(start, mid, left, depth + 1) +
                    adaptive_step(mid, stop, right, depth + 1)
            end
        end

        return adaptive_step(a, b, gauss_integrate(a, b), 0)
    end
end

--- @brief get arc length
function rt.Spline:get_length()
    if self._length then return self._length end

    self._length = _integrate(0, 1, function(t)
        return math.magnitude(self:get_derivative_at(t))
    end)

    return self._length
end

--- @brief discretize into flat list of points, adaptive sampling
function rt.Spline:discretize()
    local result = {}
    local points = self._points

    local function add_point(t)
        local x, y = self:at(t)
        table.insert(result, x)
        table.insert(result, y)
    end

    local function get_curvature_metric(t)
        local dx, dy = self:get_derivative_at(t)
        local speed = math.magnitude(dx, dy)

        -- sample nearby points to estimate curvature
        local dt = 0.001
        local t_prev = math.clamp(t - dt, 0, 1)
        local t_next = math.clamp(t + dt, 0, 1)

        local dx_prev, dy_prev = self:get_derivative_at(t_prev)
        local dx_next, dy_next = self:get_derivative_at(t_next)

        -- approximate second derivative
        local ddx = (dx_next - dx_prev) / (2 * dt)
        local ddy = (dy_next - dy_prev) / (2 * dt)
        local curvature = math.magnitude(ddx, ddy)

        return speed + curvature * rt.settings.spline.metric_curvature_weight
    end

    -- adaptive subdivision
    local function subdivide(t_start, t_end, depth)
        if depth > rt.settings.spline.discretize_maximum_recursion_depth then
            add_point(t_end)
            return
        end

        local t_mid = math.mix(t_start, t_end, 0.5)

        local x_start, y_start = self:at(t_start)
        local x_mid, y_mid = self:at(t_mid)
        local x_end, y_end = self:at(t_end)

        local x_interp = math.mix(x_start, x_end, 0.5)
        local y_interp = math.mix(y_start, y_end, 0.5)

        -- distance between actual midpoint and linear interpolation
        local error = math.distance(x_mid, y_mid, x_interp, y_interp)

        -- get curvature metric for adaptive threshold
        local metric = get_curvature_metric(t_mid)
        local threshold = math.max(rt.settings.spline.metric_threshold / (1 + metric), 0.5) -- metric threshold

        if error > threshold then
            subdivide(t_start, t_mid, depth + 1)
            subdivide(t_mid, t_end, depth + 1)
        else
            add_point(t_end)
        end
    end

    add_point(0)
    subdivide(0, 1, 0)

    return result
end