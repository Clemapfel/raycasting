if rt == nil then rt = {} end
if rt.contour == nil then rt.contour = {} end

-- Distribute circles of different radii over a polygon defined by triangles
-- using an initial triangular lattice and Lloyd relaxation to equalize density.
--
-- polygon_tris: Table of triangles, each as a table of 6 numbers: {x1,y1,x2,y2,x3,y3}
-- circle_i_to_radius: Dense array of radii, index-aligned with the output order
--
-- Returns:
--   flat_centers: flat array of numbers [x1, y1, x2, y2, ...] of same length as radii*2
--
-- Notes:
-- - 2D vectors are two numbers (x, y), not tables.
-- - Uses available math helpers: math.eps, math.distance, math.cross, math.mix.
-- - Polygon may be non-convex and may contain holes; triangles are assumed to
--   tessellate the polygon area (holes are simply absent).
function rt.contour.distribute_circles(polygon_tris, circle_i_to_radius)
    local N = #circle_i_to_radius
    if N == 0 then return {} end
    if polygon_tris == nil or #polygon_tris == 0 then return {} end

    -- Local aliases for performance
    local sqrt, abs, max, min, random = math.sqrt, math.abs, math.max, math.min, math.random
    local distance, cross, mix = math.distance, math.cross, math.mix
    local EPS = math.eps or 1e-9
    local SQRT3 = sqrt(3.0)
    local PI = math.pi or 3.141592653589793

    -- Flatten triangles and precompute per-triangle data for performance:
    -- coords: ax,ay,bx,by,cx,cy repeating
    -- bbox: minx,maxx,miny,maxy repeating per triangle
    -- areas: absolute area per triangle
    local tri_coords = {}
    local tri_bbox = {}
    local tri_areas = {}
    local tri_cum_areas = {}
    local tri_count = #polygon_tris

    local minx, miny = 1/0, 1/0
    local maxx, maxy = -1/0, -1/0
    local total_area = 0.0

    for i = 1, tri_count do
        local t = polygon_tris[i]
        local ax, ay, bx, by, cx, cy = t[1], t[2], t[3], t[4], t[5], t[6]
        tri_coords[#tri_coords+1] = ax
        tri_coords[#tri_coords+1] = ay
        tri_coords[#tri_coords+1] = bx
        tri_coords[#tri_coords+1] = by
        tri_coords[#tri_coords+1] = cx
        tri_coords[#tri_coords+1] = cy

        -- bbox
        local tminx = min(ax, min(bx, cx))
        local tmaxx = max(ax, max(bx, cx))
        local tminy = min(ay, min(by, cy))
        local tmaxy = max(ay, max(by, cy))
        tri_bbox[#tri_bbox+1] = tminx
        tri_bbox[#tri_bbox+1] = tmaxx
        tri_bbox[#tri_bbox+1] = tminy
        tri_bbox[#tri_bbox+1] = tmaxy

        -- area from cross((b-a),(c-a)) / 2
        local abx, aby = bx - ax, by - ay
        local acx, acy = cx - ax, cy - ay
        local area = 0.5 * abs(cross(abx, aby, acx, acy))
        tri_areas[#tri_areas+1] = area
        total_area = total_area + area

        if tminx < minx then minx = tminx end
        if tmaxx > maxx then maxx = tmaxx end
        if tminy < miny then miny = tminy end
        if tmaxy > maxy then maxy = tmaxy end
    end

    -- Early exit safeguards
    if total_area <= EPS then
        return {}
    end

    -- Build cumulative areas for triangle sampling
    local acc = 0.0
    for i = 1, tri_count do
        acc = acc + tri_areas[i]
        tri_cum_areas[i] = acc
    end

    -- Helper: point in triangle using cross sign test (robust to winding).
    local function point_in_triangle(px, py, ax, ay, bx, by, cx, cy)
        -- Compute cross products for each edge with vector to P
        local c1 = cross(bx - ax, by - ay, px - ax, py - ay)
        local c2 = cross(cx - bx, cy - by, px - bx, py - by)
        local c3 = cross(ax - cx, ay - cy, px - cx, py - cy)
        local has_neg = (c1 < -EPS) or (c2 < -EPS) or (c3 < -EPS)
        local has_pos = (c1 > EPS) or (c2 > EPS) or (c3 > EPS)
        return not (has_neg and has_pos)
    end

    -- Helper: test point in polygon via any-triangle check with bbox early-out
    local function point_in_polygon(px, py)
        local ci = 1
        local bi = 1
        for _ = 1, tri_count do
            local tminx = tri_bbox[bi]; local tmaxx = tri_bbox[bi+1]
            local tminy = tri_bbox[bi+2]; local tmaxy = tri_bbox[bi+3]
            if px >= tminx and px <= tmaxx and py >= tminy and py <= tmaxy then
                local ax = tri_coords[ci]; local ay = tri_coords[ci+1]
                local bx = tri_coords[ci+2]; local by = tri_coords[ci+3]
                local cx = tri_coords[ci+4]; local cy = tri_coords[ci+5]
                if point_in_triangle(px, py, ax, ay, bx, by, cx, cy) then
                    return true
                end
            end
            ci = ci + 6
            bi = bi + 4
        end
        return false
    end

    -- Helper: sample a random point uniformly inside the polygon,
    -- by selecting a triangle proportional to area and sampling barycentrically.
    local function sample_point_in_polygon()
        local r = random() * total_area
        -- binary search cumulative areas
        local lo, hi = 1, tri_count
        while lo < hi do
            local mid = math.floor((lo + hi) / 2)
            if r <= tri_cum_areas[mid] then
                hi = mid
            else
                lo = mid + 1
            end
        end
        local tri_index = lo
        local ci = (tri_index - 1) * 6 + 1
        local ax = tri_coords[ci]; local ay = tri_coords[ci+1]
        local bx = tri_coords[ci+2]; local by = tri_coords[ci+3]
        local cx = tri_coords[ci+4]; local cy = tri_coords[ci+5]
        -- uniform barycentric (u,v), fold if outside
        local u = random()
        local v = random()
        if (u + v) > 1.0 then
            u = 1.0 - u
            v = 1.0 - v
        end
        -- point = a + u*(b-a) + v*(c-a)
        local px = ax + u * (bx - ax) + v * (cx - ax)
        local py = ay + u * (by - ay) + v * (cy - ay)
        return px, py
    end

    -- Initial centers: triangular lattice inside polygon.
    -- Lattice spacing 'a' estimated from polygon area and number of circles.
    local a = sqrt((2.0 * total_area) / (SQRT3 * N))
    -- Slightly denser to ensure we have enough points
    a = a * 0.95
    local h = a * (SQRT3 * 0.5)

    -- Build lattice points within expanded bbox, filter by polygon inclusion.
    local candidates = {} -- flat array [x1,y1,x2,y2,...]
    local row = 0
    local y = miny - h
    local y_end = maxy + h
    while y <= y_end do
        local x_offset = ((row % 2) ~= 0) and (a * 0.5) or 0.0
        local x = (minx - a) + x_offset
        local x_end = maxx + a
        while x <= x_end do
            if point_in_polygon(x, y) then
                candidates[#candidates+1] = x
                candidates[#candidates+1] = y
            end
            x = x + a
        end
        row = row + 1
        y = y + h
    end

    -- If not enough lattice points, top up from uniform sampling inside polygon.
    local need = N - math.floor(#candidates / 2)
    if need > 0 then
        for _ = 1, need do
            local sx, sy = sample_point_in_polygon()
            candidates[#candidates+1] = sx
            candidates[#candidates+1] = sy
        end
    end

    -- Shuffle candidates and take first N
    local cand_pairs = math.floor(#candidates / 2)
    -- Fisher-Yates shuffle on pairs
    for i = cand_pairs, 2, -1 do
        local j = 1 + math.floor((random() * i) / 1)
        local ia = (i - 1) * 2 + 1
        local ja = (j - 1) * 2 + 1
        candidates[ia], candidates[ja] = candidates[ja], candidates[ia]
        candidates[ia+1], candidates[ja+1] = candidates[ja+1], candidates[ia+1]
    end

    local centers = {} -- flat array [x1,y1,...] length 2*N
    centers[2*N] = nil -- pre-size
    for i = 1, N do
        local ci = (i - 1) * 2 + 1
        local si = (i - 1) * 2 + 1
        centers[ci] = candidates[si]
        centers[ci+1] = candidates[si+1]
    end

    -- Lloyd relaxation to equalize density.
    -- Use a distance metric scaled by radius (d / r) to bias influence by area ~ r^2.
    local iters = 6
    local alpha = 0.85 -- relaxation factor for stability

    -- Precompute radii and tiny guard
    local radii = circle_i_to_radius
    local tiny = EPS

    local function lloyd_iteration()
        -- Sums per center
        local sums = {}
        local counts = {}
        sums[2*N] = nil
        counts[N] = nil
        for i = 1, 2*N do sums[i] = 0.0 end
        for i = 1, N do counts[i] = 0 end

        -- Choose sample count proportional to N for stability/perf
        local M = max(12 * N, 400)
        -- Cap samples to avoid excessive cost on huge N; adjust if needed
        M = min(M, 12000)

        for _ = 1, M do
            local sx, sy = sample_point_in_polygon()
            -- Find nearest center under scaled distance d / r
            local best_i = 1
            local ci = 1
            local cx = centers[ci]; local cy = centers[ci+1]
            local denom = max(radii[1], tiny)
            local best_d = distance(sx, sy, cx, cy) / denom

            for i = 2, N do
                ci = (i - 1) * 2 + 1
                cx = centers[ci]; cy = centers[ci+1]
                denom = max(radii[i], tiny)
                local d = distance(sx, sy, cx, cy) / denom
                if d < best_d then
                    best_d = d
                    best_i = i
                end
            end

            local bi = (best_i - 1) * 2 + 1
            sums[bi] = sums[bi] + sx
            sums[bi+1] = sums[bi+1] + sy
            counts[best_i] = counts[best_i] + 1
        end

        -- Update centers to centroids (with mixing), keep inside polygon by construction
        for i = 1, N do
            local c = counts[i]
            local ci = (i - 1) * 2 + 1
            if c > 0 then
                local meanx = sums[ci] / c
                local meany = sums[ci+1] / c
                local ox = centers[ci]
                local oy = centers[ci+1]
                centers[ci] = mix(ox, meanx, alpha)
                centers[ci+1] = mix(oy, meany, alpha)
            else
                -- Rare: re-seed to a random valid point to avoid stranding
                local rx, ry = sample_point_in_polygon()
                centers[ci] = rx
                centers[ci+1] = ry
            end
        end
    end

    for _ = 1, iters do
        lloyd_iteration()
    end

    return centers
end