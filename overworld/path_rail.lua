require "common.path"

rt.settings.overworld.moving_hitbox_path = {
    rail_inner_radius = 5,
    rail_outer_radius = 6,
    attachment_outer_radius = 10,
    attachment_inner_radius = 7,
    contour_line_width = 1
}

--- @class ow.PathRail
ow.PathRail = meta.class("PathRail")

local function normalize_angle_signed(a)
    -- Normalize to (-pi, pi]
    local two_pi = 2 * math.pi
    a = (a + math.pi) % two_pi
    if a < 0 then a = a + two_pi end
    return a - math.pi
end

local function add_point(out, x, y)
    out[#out + 1] = { x = x, y = y }
end

local function add_arc(out, cx, cy, r, a0, a1, max_angle_step)
    -- Adds points along arc from angle a0 to a1. If a1 < a0, arc is swept CW.
    local da = a1 - a0
    local steps = math.max(1, math.ceil(math.abs(da) / max_angle_step))
    local step = da / steps
    for i = 0, steps do
        local a = a0 + step * i
        local x = cx + r * math.cos(a)
        local y = cy + r * math.sin(a)
        add_point(out, x, y)
    end
end

local function intersect_lines(p1x, p1y, v1x, v1y, p2x, p2y, v2x, v2y, eps)
    -- Intersect infinite lines: p1 + t*v1 = p2 + s*v2
    local denom = math.cross(v1x, v1y, v2x, v2y)
    if math.abs(denom) < eps then
        -- Parallel or nearly parallel
        return p1x, p1y, false
    end
    local dx = p2x - p1x
    local dy = p2y - p1y
    local t = math.cross(dx, dy, v2x, v2y) / denom
    return p1x + t * v1x, p1y + t * v1y, true
end

local function dedup_consecutive(points, eps)
    if #points == 0 then return points end
    local out = {}
    local lastx, lasty = nil, nil
    for i = 1, #points do
        local p = points[i]
        if lastx == nil or math.distance(p.x, p.y, lastx, lasty) > eps then
            out[#out + 1] = p
            lastx, lasty = p.x, p.y
        end
    end
    return out
end

local function clean_flat_points(flat, eps)
    -- Remove consecutive duplicates and separate into xs, ys
    local xs, ys = {}, {}
    local lastx, lasty
    for i = 1, #flat, 2 do
        local x, y = flat[i], flat[i + 1]
        if lastx == nil or math.distance(x, y, lastx, lasty) > eps then
            xs[#xs + 1] = x
            ys[#ys + 1] = y
            lastx, lasty = x, y
        end
    end
    return xs, ys
end

local function build_directions(xs, ys, eps)
    -- Returns arrays ux[i], uy[i] for segments i=1..m where m = #xs-1
    local n = #xs
    local ux, uy, valid = {}, {}, {}
    for i = 1, n - 1 do
        local dx = xs[i + 1] - xs[i]
        local dy = ys[i + 1] - ys[i]
        local len = math.magnitude(dx, dy)
        if len > eps then
            ux[i] = dx / len
            uy[i] = dy / len
            valid[i] = true
        else
            ux[i] = 0
            uy[i] = 0
            valid[i] = false
        end
    end
    return ux, uy, valid
end

local function stroke_polyline_contour(flat_points, r, opts)
    opts = opts or {}
    local max_angle_step = opts.max_angle_step or 0.20
    local eps = opts.epsilon or 1e-9

    if type(flat_points) ~= "table" or #flat_points < 2 then
        return {}
    end
    if not r or r <= 0 then
        error("radius r must be positive")
    end

    -- Clean duplicates
    local xs, ys = clean_flat_points(flat_points, eps)
    local n = #xs
    if n == 0 then
        return {}
    end

    if n == 1 then
        -- Degenerate: single point => circle
        local cx, cy = xs[1], ys[1]
        local circle_pts = {}
        add_arc(circle_pts, cx, cy, r, 0, 2 * math.pi, max_angle_step)
        circle_pts = dedup_consecutive(circle_pts, eps)
        -- Flatten points inline
        local flat = {}
        for i = 1, #circle_pts do
            flat[#flat + 1] = circle_pts[i].x
            flat[#flat + 1] = circle_pts[i].y
        end
        return flat
    end

    -- Build segment directions
    local ux, uy, valid = build_directions(xs, ys, eps)

    -- Find first and last valid segments inline
    local first_seg, last_seg = nil, nil
    for i = 1, #valid do
        if valid[i] then
            if not first_seg then first_seg = i end
            last_seg = i
        end
    end

    if not first_seg or not last_seg then
        -- All segments degenerate -> treat as single point circle around first
        local cx, cy = xs[1], ys[1]
        local circle_pts = {}
        add_arc(circle_pts, cx, cy, r, 0, 2 * math.pi, max_angle_step)
        circle_pts = dedup_consecutive(circle_pts, eps)
        -- Flatten points inline
        local flat = {}
        for i = 1, #circle_pts do
            flat[#flat + 1] = circle_pts[i].x
            flat[#flat + 1] = circle_pts[i].y
        end
        return flat
    end

    -- Build left and right boundary outlines in forward order
    local left_outline, right_outline = {}, {}

    -- Start offsets (using first valid segment)
    do
        local i = first_seg
        local vx, vy = ux[i], uy[i]
        local nlx, nly = math.turn_left(vx, vy)
        local nrx, nry = math.turn_right(vx, vy)
        add_point(left_outline, xs[1] + r * nlx, ys[1] + r * nly)
        add_point(right_outline, xs[1] + r * nrx, ys[1] + r * nry)
    end

    -- Interior joins, i = 2..n-1
    for i = 2, n - 1 do
        if valid[i - 1] and valid[i] then
            -- LEFT SIDE (y-down: left turn => delta < 0, right turn => delta > 0)
            do
                local vx_prev, vy_prev = ux[i - 1], uy[i - 1]
                local vx_next, vy_next = ux[i], uy[i]
                local nlx_prev, nly_prev = math.turn_left(vx_prev, vy_prev)
                local nlx_next, nly_next = math.turn_left(vx_next, vy_next)
                local a_prev_left = math.angle(nlx_prev, nly_prev)
                local a_next_left = math.angle(nlx_next, nly_next)
                local delta = normalize_angle_signed(a_next_left - a_prev_left)

                if delta > eps then
                    -- Right turn on left side => add CCW arc (positive delta)
                    add_arc(left_outline, xs[i], ys[i], r, a_prev_left, a_prev_left + delta, max_angle_step)
                else
                    -- Left turn or straight => miter via intersection of left offset lines
                    local p1x = xs[i] + r * nlx_prev
                    local p1y = ys[i] + r * nly_prev
                    local p2x = xs[i] + r * nlx_next
                    local p2y = ys[i] + r * nly_next
                    local ix, iy = intersect_lines(p1x, p1y, vx_prev, vy_prev, p2x, p2y, vx_next, vy_next, eps)
                    add_point(left_outline, ix, iy)
                end
            end

            -- RIGHT SIDE (y-down: left turn => delta < 0, right turn => delta > 0)
            do
                local vx_prev, vy_prev = ux[i - 1], uy[i - 1]
                local vx_next, vy_next = ux[i], uy[i]
                local nrx_prev, nry_prev = math.turn_right(vx_prev, vy_prev)
                local nrx_next, nry_next = math.turn_right(vx_next, vy_next)
                local a_prev_right = math.angle(nrx_prev, nry_prev)
                local a_next_right = math.angle(nrx_next, nry_next)
                local delta = normalize_angle_signed(a_next_right - a_prev_right)

                if delta < -eps then
                    -- Left turn on right side => add CW arc (negative delta)
                    add_arc(right_outline, xs[i], ys[i], r, a_prev_right, a_prev_right + delta, max_angle_step)
                else
                    -- Right turn or straight => miter via intersection of right offset lines
                    local p1x = xs[i] + r * nrx_prev
                    local p1y = ys[i] + r * nry_prev
                    local p2x = xs[i] + r * nrx_next
                    local p2y = ys[i] + r * nry_next
                    local ix, iy = intersect_lines(p1x, p1y, vx_prev, vy_prev, p2x, p2y, vx_next, vy_next, eps)
                    add_point(right_outline, ix, iy)
                end
            end
        else
            -- Degenerate adjacency: fall back to offsetting using whichever segment is valid
            if valid[i - 1] then
                local vx, vy = ux[i - 1], uy[i - 1]
                local nlx, nly = math.turn_left(vx, vy)
                local nrx, nry = math.turn_right(vx, vy)
                add_point(left_outline, xs[i] + r * nlx, ys[i] + r * nly)
                add_point(right_outline, xs[i] + r * nrx, ys[i] + r * nry)
            elseif valid[i] then
                local vx, vy = ux[i], uy[i]
                local nlx, nly = math.turn_left(vx, vy)
                local nrx, nry = math.turn_right(vx, vy)
                add_point(left_outline, xs[i] + r * nlx, ys[i] + r * nly)
                add_point(right_outline, xs[i] + r * nrx, ys[i] + r * nry)
            else
                -- both invalid: skip
            end
        end
    end

    -- Append endpoints for left/right outlines using last valid segment
    do
        local j = last_seg
        local vx, vy = ux[j], uy[j]
        local nlx, nly = math.turn_left(vx, vy)
        local nrx, nry = math.turn_right(vx, vy)
        add_point(left_outline, xs[n] + r * nlx, ys[n] + r * nly)
        add_point(right_outline, xs[n] + r * nrx, ys[n] + r * nry)
    end

    -- Build full contour for y-down:
    -- left side (forward) -> end cap (CCW +pi) -> right side (reverse) -> start cap (CCW +pi)
    left_outline = dedup_consecutive(left_outline, eps)
    right_outline = dedup_consecutive(right_outline, eps)

    local full = {}

    -- Append left outline
    for i = 1, #left_outline do full[#full + 1] = left_outline[i] end

    -- End cap around last point: left normal -> right normal via +pi (CCW in math)
    do
        local j = last_seg
        local vx, vy = ux[j], uy[j]
        local nlx, nly = math.turn_left(vx, vy)
        local theta_end = math.angle(nlx, nly)
        local cx, cy = xs[n], ys[n]
        add_arc(full, cx, cy, r, theta_end, theta_end + math.pi, max_angle_step)
    end

    -- Append right outline in reverse (from end back to start)
    for i = #right_outline, 1, -1 do
        full[#full + 1] = right_outline[i]
    end

    -- Start cap around first point: right normal -> left normal via +pi (CCW in math)
    do
        local i = first_seg
        local vx, vy = ux[i], uy[i]
        local nrx, nry = math.turn_right(vx, vy)
        local phi_start = math.angle(nrx, nry)
        local cx, cy = xs[1], ys[1]
        add_arc(full, cx, cy, r, phi_start, phi_start + math.pi, max_angle_step)
    end

    -- Final dedup
    full = dedup_consecutive(full, eps)

    -- Flatten points inline
    local flat = {}
    for i = 1, #full do
        flat[#flat + 1] = full[i].x
        flat[#flat + 1] = full[i].y
    end
    return flat
end

--- @brief
function ow.PathRail:instantiate(path)
    meta.assert(path, rt.Path)

    self._path = path
    self._points = path:get_points()

    local outer_r = rt.settings.overworld.moving_hitbox_path.rail_outer_radius
    local inner_r = rt.settings.overworld.moving_hitbox_path.rail_inner_radius

    self._inner_contour = stroke_polyline_contour(self._points, inner_r)
    self._outer_contour = stroke_polyline_contour(self._points, outer_r)

    local outer_attachment_r = rt.settings.overworld.moving_hitbox_path.attachment_outer_radius
    local inner_attachment_r = rt.settings.overworld.moving_hitbox_path.attachment_inner_radius
    self._inner_attachment = { 0, 0, inner_attachment_r }
    self._outer_attachment = { 0, 0, outer_attachment_r }
    self._outer_attachment_contour = {}
    self._inner_attachment_contour = {}

    local n_vertices = 24
    for i = 1, n_vertices + 1 do
        local angle = ((i - 1) / n_vertices) * (2 * math.pi)
        local dx, dy = math.cos(angle), math.sin(angle)

        table.insert(self._inner_attachment_contour, dx * inner_attachment_r)
        table.insert(self._inner_attachment_contour, dy * inner_attachment_r)
        table.insert(self._outer_attachment_contour, dx * outer_attachment_r)
        table.insert(self._outer_attachment_contour, dy * outer_attachment_r)
    end
end

--- @brief
function ow.PathRail:draw_rail(origin_x, origin_y)
    love.graphics.setLineJoin("none")

    local outer_r = rt.settings.overworld.moving_hitbox_path.rail_outer_radius
    local inner_r = rt.settings.overworld.moving_hitbox_path.rail_inner_radius

    local draw_solid = function(radius)
        for i = 1, #self._points, 2 do
            local x = self._points[i+0]
            local y = self._points[i+1]
            love.graphics.circle("fill", x, y, radius)
        end

        love.graphics.setLineWidth(2 * radius)
        love.graphics.line(self._points)
    end

    local draw_line = function(points)
        love.graphics.setLineWidth(rt.settings.overworld.moving_hitbox_path.contour_line_width)
        love.graphics.line(points)
    end

    rt.Palette.MOVING_HITBOX_PATH_OUTER:bind()
    draw_solid(outer_r)

    rt.Palette.MOVING_HITBOX_PATH_INNER:bind()
    draw_solid(inner_r)

    rt.Palette.BLACK:bind()
    draw_line(self._outer_contour)
    draw_line(self._inner_contour)
end

function ow.PathRail:draw_attachment(origin_x, origin_y)
    love.graphics.push()
    love.graphics.translate(origin_x, origin_y)

    rt.Palette.MOVING_HITBOX_PATH_OUTER:bind()
    love.graphics.circle("fill", table.unpack(self._outer_attachment))

    rt.Palette.MOVING_HITBOX_PATH_INNER:bind()
    love.graphics.circle("fill", table.unpack(self._inner_attachment))

    love.graphics.setLineWidth(1)
    rt.Palette.BLACK:bind()
    love.graphics.line(self._outer_attachment_contour)
    love.graphics.line(self._inner_attachment_contour)

    love.graphics.pop()
end