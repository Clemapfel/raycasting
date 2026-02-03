if rt == nil then rt = {} end
if rt.contour == nil then rt.contour = {} end

-- Distribute circles of different radii over a polygon defined by triangles
-- using an initial triangular lattice and Lloyd relaxation to equalize density.
--
-- polygon_tris: array of triangles, each as 6 numbers {ax,ay,bx,by,cx,cy}
-- circle_i_to_radius: array of radii; length defines number of circles
--
-- Returns:
--   centers: flat array [x1,y1,x2,y2,...] length = 2 * #circle_i_to_radius
--
-- Structural optimizations:
-- - O(1) triangle sampling via Walker alias method + precomputed bases (a, ab, ac).
-- - Spatial hash grid for accelerated nearest-center search in Lloyd iterations.
-- - Reuse buffers across iterations to reduce allocations.
function rt.contour.distribute_circles(polygon_tris, circle_i_to_radius)
    local N = #circle_i_to_radius
    if N == 0 then return {} end
    if polygon_tris == nil or #polygon_tris == 0 then return {} end

    -- Local aliases for performance and fallback RNG
    local sqrt, abs, max, min, floor = math.sqrt, math.abs, math.max, math.min, math.floor
    local random = (love and love.math and love.math.random) or math.random
    local distance, cross, mix = math.distance, math.cross, math.mix
    local EPS = math.eps or 1e-9
    local SQRT3 = sqrt(3.0)

    -- Precompute triangle stats and global bbox
    local tri_count = #polygon_tris
    local tri_areas = {}
    local total_area = 0.0
    local minx, miny = 1/0, 1/0
    local maxx, maxy = -1/0, -1/0

    -- For faster barycentric sampling: store triangle bases: a, ab, ac per tri
    -- Layout: [ax,ay, abx,aby, acx,acy] per triangle
    local tri_basis = {}
    tri_basis[6 * tri_count] = nil

    for i = 1, tri_count do
        local t = polygon_tris[i]
        local ax, ay, bx, by, cx, cy = t[1], t[2], t[3], t[4], t[5], t[6]
        local abx, aby = bx - ax, by - ay
        local acx, acy = cx - ax, cy - ay
        local area = 0.5 * abs(cross(abx, aby, acx, acy))
        tri_areas[i] = area
        total_area = total_area + area

        local base = (i - 1) * 6
        tri_basis[base + 1] = ax
        tri_basis[base + 2] = ay
        tri_basis[base + 3] = abx
        tri_basis[base + 4] = aby
        tri_basis[base + 5] = acx
        tri_basis[base + 6] = acy

        -- bbox accumulation
        local tminx = min(ax, min(bx, cx))
        local tmaxx = max(ax, max(bx, cx))
        local tminy = min(ay, min(by, cy))
        local tmaxy = max(ay, max(by, cy))
        if tminx < minx then minx = tminx end
        if tmaxx > maxx then maxx = tmaxx end
        if tminy < miny then miny = tminy end
        if tmaxy > maxy then maxy = tmaxy end
    end
    if total_area <= EPS then
        return {}
    end

    -- Build Walker alias table for O(1) triangle sampling
    -- prob[i] in [0,1], alias[i] in [1..tri_count]
    local prob = {}
    local alias = {}
    prob[tri_count] = nil
    alias[tri_count] = nil

    do
        -- Normalize areas
        local scaled = {}
        scaled[tri_count] = nil
        local inv_total = 1.0 / total_area
        for i = 1, tri_count do
            scaled[i] = tri_areas[i] * inv_total * tri_count
        end
        -- Worklists
        local small, large = {}, {}
        for i = 1, tri_count do
            if scaled[i] < 1.0 then
                small[#small+1] = i
            else
                large[#large+1] = i
            end
        end
        while #small > 0 and #large > 0 do
            local l = small[#small]; small[#small] = nil
            local g = large[#large]; large[#large] = nil
            prob[l] = scaled[l]
            alias[l] = g
            scaled[g] = (scaled[g] + scaled[l]) - 1.0
            if scaled[g] < 1.0 then
                small[#small+1] = g
            else
                large[#large+1] = g
            end
        end
        while #large > 0 do
            local g = large[#large]; large[#large] = nil
            prob[g] = 1.0
            alias[g] = g
        end
        while #small > 0 do
            local l = small[#small]; small[#small] = nil
            prob[l] = 1.0
            alias[l] = l
        end
    end

    -- O(1) sample of a triangle index
    local function sample_triangle_index()
        -- random() in [0,1), scale by tri_count
        local r = random() * tri_count
        local k = floor(r) + 1
        local frac = r - floor(r)
        if frac < prob[k] then
            return k
        else
            return alias[k]
        end
    end

    -- Uniform sample inside polygon by:
    -- 1) Choose triangle with alias sampler
    -- 2) Barycentric sample inside chosen triangle using bases
    local function sample_point_in_polygon()
        local tri_index = sample_triangle_index()
        -- Barycentric fold
        local u = random()
        local v = random()
        if (u + v) > 1.0 then
            u = 1.0 - u
            v = 1.0 - v
        end
        local base = (tri_index - 1) * 6
        local ax = tri_basis[base + 1]
        local ay = tri_basis[base + 2]
        local abx = tri_basis[base + 3]
        local aby = tri_basis[base + 4]
        local acx = tri_basis[base + 5]
        local acy = tri_basis[base + 6]
        local px = ax + u * abx + v * acx
        local py = ay + u * aby + v * acy
        return px, py
    end

    -- Initial centers: triangular lattice inside polygon.
    -- Lattice spacing 'a' estimated from polygon area and number of circles.
    local a = sqrt((2.0 * total_area) / (SQRT3 * N))
    a = a * 0.95
    local h = a * (SQRT3 * 0.5)

    -- Point-in-triangle for lattice filtering (triangles tessellate the polygon)
    local function point_in_triangle(px, py, ax, ay, bx, by, cx, cy)
        local c1 = cross(bx - ax, by - ay, px - ax, py - ay)
        local c2 = cross(cx - bx, cy - by, px - bx, py - by)
        local c3 = cross(ax - cx, ay - cy, px - cx, py - cy)
        local has_neg = (c1 < -EPS) or (c2 < -EPS) or (c3 < -EPS)
        local has_pos = (c1 > EPS) or (c2 > EPS) or (c3 > EPS)
        return not (has_neg and has_pos)
    end

    -- For lattice inclusion, accelerate "point in polygon (triangulation)" by
    -- checking each triangle's bbox and doing the triangle test.
    -- This is kept simple since this step runs once, while Lloyd runs multiple times.
    local tri_bbox = {}
    tri_bbox[4 * tri_count] = nil
    do
        for i = 1, tri_count do
            local t = polygon_tris[i]
            local ax, ay, bx, by, cx, cy = t[1], t[2], t[3], t[4], t[5], t[6]
            local tminx = min(ax, min(bx, cx))
            local tmaxx = max(ax, max(bx, cx))
            local tminy = min(ay, min(by, cy))
            local tmaxy = max(ay, max(by, cy))
            local base = (i - 1) * 4
            tri_bbox[base + 1] = tminx
            tri_bbox[base + 2] = tmaxx
            tri_bbox[base + 3] = tminy
            tri_bbox[base + 4] = tmaxy
        end
    end

    local function point_in_polygon(px, py)
        for i = 1, tri_count do
            local bb = (i - 1) * 4
            local tminx = tri_bbox[bb + 1]
            local tmaxx = tri_bbox[bb + 2]
            local tminy = tri_bbox[bb + 3]
            local tmaxy = tri_bbox[bb + 4]
            if px >= tminx and px <= tmaxx and py >= tminy and py <= tmaxy then
                local t = polygon_tris[i]
                if point_in_triangle(px, py, t[1], t[2], t[3], t[4], t[5], t[6]) then
                    return true
                end
            end
        end
        return false
    end

    -- Build lattice points within expanded bbox, filter by polygon inclusion
    local candidates = {}
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

    -- Top up if not enough lattice points (use uniform sampling inside polygon)
    local need = N - floor(#candidates / 2)
    if need > 0 then
        for _ = 1, need do
            local sx, sy = sample_point_in_polygon()
            candidates[#candidates+1] = sx
            candidates[#candidates+1] = sy
        end
    end

    -- Shuffle candidates (Fisher-Yates on pairs)
    local cand_pairs = floor(#candidates / 2)
    for i = cand_pairs, 2, -1 do
        local j = 1 + floor(random() * i)
        local ia = (i - 1) * 2 + 1
        local ja = (j - 1) * 2 + 1
        candidates[ia], candidates[ja] = candidates[ja], candidates[ia]
        candidates[ia+1], candidates[ja+1] = candidates[ja+1], candidates[ia+1]
    end

    local centers = {}
    centers[2 * N] = nil
    for i = 1, N do
        local ci = (i - 1) * 2 + 1
        local si = (i - 1) * 2 + 1
        centers[ci] = candidates[si]
        centers[ci+1] = candidates[si+1]
    end

    -- Lloyd parameters (iterations kept modest; acceleration is structural)
    local n_lloyd_iterations = 4
    local alpha = 0.5
    local radii = circle_i_to_radius
    local tiny = EPS

    -- Preallocate working buffers for reuse
    local sums = {}
    local counts = {}
    sums[2 * N] = nil
    counts[N] = nil

    -- Spatial grid to accelerate nearest-center queries
    -- Use lattice spacing 'a' as grid cell size
    local cell = a
    if cell < EPS then cell = 1.0 end
    local inv_cell = 1.0 / cell
    local grid_w = max(1, floor((maxx - minx) * inv_cell) + 1)
    local grid_h = max(1, floor((maxy - miny) * inv_cell) + 1)
    local grid_size = grid_w * grid_h
    local grid = {}          -- grid[cell_idx] = array of center indices
    local center_cell_ix = {} -- per-center cached cell index (for rebuilding)

    local function cell_index(ix, iy)
        return iy * grid_w + ix + 1
    end

    local function clampi(v, lo, hi)
        if v < lo then return lo end
        if v > hi then return hi end
        return v
    end

    local function rebuild_grid()
        for i = 1, grid_size do grid[i] = nil end
        -- Populate grid
        for i = 1, N do
            local ci = (i - 1) * 2 + 1
            local x = centers[ci]
            local y = centers[ci+1]
            local ix = clampi(floor((x - minx) * inv_cell), 0, grid_w - 1)
            local iy = clampi(floor((y - miny) * inv_cell), 0, grid_h - 1)
            local gi = cell_index(ix, iy)
            local bucket = grid[gi]
            if bucket == nil then
                bucket = {}
                grid[gi] = bucket
            end
            bucket[#bucket+1] = i
            center_cell_ix[i] = gi
        end
    end

    local function nearest_center_scaled(sx, sy)
        -- Query around sample's cell, expanding rings until at least one candidate is found.
        local ix = clampi(floor((sx - minx) * inv_cell), 0, grid_w - 1)
        local iy = clampi(floor((sy - miny) * inv_cell), 0, grid_h - 1)

        local best_i = nil
        local best_d = 1/0

        local r = 0
        local maxR = max(grid_w, grid_h)
        while r <= maxR do
            local found_any = false
            local xmin = clampi(ix - r, 0, grid_w - 1)
            local xmax = clampi(ix + r, 0, grid_w - 1)
            local ymin = clampi(iy - r, 0, grid_h - 1)
            local ymax = clampi(iy + r, 0, grid_h - 1)

            for yy = ymin, ymax do
                for xx = xmin, xmax do
                    local gi = cell_index(xx, yy)
                    local bucket = grid[gi]
                    if bucket ~= nil then
                        found_any = true
                        for k = 1, #bucket do
                            local idx = bucket[k]
                            local ci = (idx - 1) * 2 + 1
                            local cx = centers[ci]
                            local cy = centers[ci+1]
                            local denom = max(radii[idx], tiny)
                            local d = distance(sx, sy, cx, cy) / denom
                            if d < best_d then
                                best_d = d
                                best_i = idx
                            end
                        end
                    end
                end
            end

            if found_any and best_i ~= nil then
                break
            end
            r = r + 1
        end

        -- Fallback (should be rare): if no buckets found (empty grid), do a linear scan
        if best_i == nil then
            best_i = 1
            local ci = 1
            local denom = max(radii[1], tiny)
            best_d = distance(sx, sy, centers[ci], centers[ci+1]) / denom
            for i = 2, N do
                ci = (i - 1) * 2 + 1
                local d = distance(sx, sy, centers[ci], centers[ci+1]) / max(radii[i], tiny)
                if d < best_d then
                    best_d = d
                    best_i = i
                end
            end
        end

        return best_i
    end

    local function lloyd_iteration()
        -- Zero buffers
        for i = 1, 2 * N do sums[i] = 0.0 end
        for i = 1, N do counts[i] = 0 end

        rebuild_grid()

        -- Monte Carlo samples proportional to N
        local M = min(max(12 * N, 400), 12000)

        for _ = 1, M do
            local sx, sy = sample_point_in_polygon()
            local best_i = nearest_center_scaled(sx, sy)

            local bi = (best_i - 1) * 2 + 1
            sums[bi] = sums[bi] + sx
            sums[bi + 1] = sums[bi + 1] + sy
            counts[best_i] = counts[best_i] + 1
        end

        -- Update centers to centroids (with mixing)
        for i = 1, N do
            local c = counts[i]
            local ci = (i - 1) * 2 + 1
            if c > 0 then
                local meanx = sums[ci] / c
                local meany = sums[ci + 1] / c
                local ox = centers[ci]
                local oy = centers[ci + 1]
                centers[ci] = mix(ox, meanx, alpha)
                centers[ci + 1] = mix(oy, meany, alpha)
            else
                -- Rare: re-seed to a random valid point
                local rx, ry = sample_point_in_polygon()
                centers[ci] = rx
                centers[ci + 1] = ry
            end
        end
    end

    for _ = 1, n_lloyd_iterations do
        lloyd_iteration()
    end

    return centers
end