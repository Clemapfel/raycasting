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

    -- phantom points

    local p0_x = 2 * points[1] - points[3]
    local p0_y = 2 * points[2] - points[4]
    table.insert(points, 1, p0_y)
    table.insert(points, 1, p0_x)

    local n = #points
    local pn_x = 2 * points[n - 1] - points[n - 3]
    local pn_y = 2 * points[n] - points[n - 2]
    table.insert(points, pn_x)
    table.insert(points, pn_y)

    self._points = points
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

--- @brief Discretizes the spline into a series of points with a target distance between them.
-- @param step_size The desired distance between consecutive points along the curve.
-- @return A table of numbers {x1, y1, x2, y2, ...} representing the discretized points.
function rt.Spline:discretize(step_size)
    if not step_size or step_size <= 0 then
        rt.error("In rt.Spline:discretize: step_size must be a positive number")
        return {}
    end

    local result = {}
    local current_t = 0.0

    local start_x, start_y = self:at(0)
    table.insert(result, start_x)
    table.insert(result, start_y)

    while current_t < 1.0 do
        local dx, dy = self:get_derivative_at(current_t)
        local speed = math.magnitude(dx, dy)

        local delta_t = math.max(step_size / speed, 1e-3)
        current_t = current_t + delta_t

        if current_t < 1.0 then
            local next_x, next_y = self:at(current_t)
            table.insert(result, next_x)
            table.insert(result, next_y)
        end
    end

    local end_x, end_y = self:at(1.0)
    if math.distance(end_x, end_y, result[#result - 1], result[#result]) > math.eps then
        table.insert(result, end_x)
        table.insert(result, end_y)
    end

    return result
end