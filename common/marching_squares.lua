require "common.common"

--- Remove collinear points from a flat array of coordinates {x1, y1, x2, y2, ...}
--- Multiple contours are separated by `nil` values.
--- @param flat_points table (flat array)
--- @param closed boolean (true if the contours are closed, false if open)
--- @return table (flat array with collinear points removed)
function dissolve_colinear_points(flat_points, closed)
    local function is_colinear(ax, ay, bx, by, cx, cy)
        local cross_product = (bx - ax) * (cy - ay) - (by - ay) * (cx - ax)
        return math.abs(cross_product) < 1e-6
    end

    local result = {}
    local contour = {}

    for i = 1, #flat_points, 2 do
        local x, y = flat_points[i], flat_points[i + 1]
        if x == nil or y == nil then
            -- Process the current contour
            if #contour > 0 then
                local n = math.floor(#contour / 2)
                local processed_contour = {}

                for j = 1, n do
                    local ax, ay = contour[(j - 1) * 2 + 1], contour[(j - 1) * 2 + 2]
                    local bx, by = contour[(j % n) * 2 + 1], contour[(j % n) * 2 + 2]
                    local cx, cy = contour[(j + 1) % n * 2 + 1], contour[(j + 1) % n * 2 + 2]

                    if not is_colinear(ax, ay, bx, by, cx, cy) then
                        table.insert(processed_contour, bx)
                        table.insert(processed_contour, by)
                    end
                end

                for _, v in ipairs(processed_contour) do
                    table.insert(result, v)
                end
                table.insert(result, nil) -- Add delimiter for the next contour
            end

            -- Reset contour for the next segment
            contour = {}
        else
            table.insert(contour, x)
            table.insert(contour, y)
        end
    end

    -- Process the last contour if it exists
    if #contour > 0 then
        local n = math.floor(#contour / 2)
        local processed_contour = {}

        for j = 1, n do
            local ax, ay = contour[(j - 1) * 2 + 1], contour[(j - 1) * 2 + 2]
            local bx, by = contour[(j % n) * 2 + 1], contour[(j % n) * 2 + 2]
            local cx, cy = contour[(j + 1) % n * 2 + 1], contour[(j + 1) % n * 2 + 2]

            if not is_colinear(ax, ay, bx, by, cx, cy) then
                table.insert(processed_contour, bx)
                table.insert(processed_contour, by)
            end
        end

        for _, v in ipairs(processed_contour) do
            table.insert(result, v)
        end
    end

    return result
end

--- @brief
-- Extracts all contours from a binary image using the marching squares algorithm.
-- Returns a flat list of 2D points (all contours concatenated).
-- @param canvas love.graphics.Canvas
-- @return table of {x, y} points (flat list)
function rt.contour.from_canvas(canvas)
    local data = love.graphics.readbackTexture(canvas:get_native())
    local width, height = data:getWidth(), data:getHeight()

    local function get_pixel(x, y)
        -- Out of bounds is always off (false)
        if x < 0 or y < 0 or x >= width or y >= height then
            return false
        end
        return data:getPixel(x, y) > 1 / 32
    end

    -- Visited edges: visited[x+1][y+1][dir+1] = true
    -- dir: 0=left, 1=top, 2=right, 3=bottom (edge leaving (x, y))
    local visited = {}
    for x = 0, width do
        visited[x+1] = {}
        for y = 0, height do
            visited[x+1][y+1] = {false, false, false, false}
        end
    end

    local edge_moves = {
        [0] = {dx=0, dy=0, nx=0, ny=-1, nd=3}, -- left
        [1] = {dx=1, dy=0, nx=1, ny=0, nd=2},  -- top
        [2] = {dx=1, dy=1, nx=0, ny=1, nd=0},  -- right
        [3] = {dx=0, dy=1, nx=0, ny=0, nd=1},  -- bottom
    }

    local next_edge = {
        [1]  = {[3]=0, [0]=3},
        [2]  = {[0]=1, [1]=0},
        [3]  = {[3]=1, [1]=3},
        [4]  = {[1]=2, [2]=1},
        [5]  = {[3]=2, [2]=3, [1]=0, [0]=1},
        [6]  = {[0]=2, [2]=0},
        [7]  = {[3]=2, [2]=3, [1]=2},
        [8]  = {[2]=3, [3]=2},
        [9]  = {[1]=3, [3]=1},
        [10] = {[0]=2, [2]=0, [1]=3, [3]=1},
        [11] = {[1]=2, [2]=1, [3]=1},
        [12] = {[0]=1, [1]=0, [2]=1},
        [13] = {[0]=3, [3]=0, [1]=3},
        [14] = {[0]=1, [1]=0, [2]=0},
    }

    local function get_case(x, y)
        local c0 = get_pixel(x, y) and 1 or 0
        local c1 = get_pixel(x+1, y) and 1 or 0
        local c2 = get_pixel(x+1, y+1) and 1 or 0
        local c3 = get_pixel(x, y+1) and 1 or 0
        return c0 + 2*c1 + 4*c2 + 8*c3
    end

    local flat_points = {}
    local function trace_contour(sx, sy, sdir)
        local x, y, dir = sx, sy, sdir
        local first = true
        while true do
            visited[x+1][y+1][dir+1] = true

            local px, py
            if dir == 0 then
                px, py = x, y + 0.5
            elseif dir == 1 then
                px, py = x + 0.5, y
            elseif dir == 2 then
                px, py = x + 1, y + 0.5
            elseif dir == 3 then
                px, py = x + 0.5, y + 1
            end
            table.insert(flat_points, px)
            table.insert(flat_points, py)

            local case = get_case(x, y)
            if case == 0 or case == 15 then
                break
            end

            local outgoing = next_edge[case] and next_edge[case][dir]
            if outgoing == nil then
                break
            end

            local move = edge_moves[outgoing]
            local nx = x + move.nx
            local ny = y + move.ny
            local ndir = move.nd

            if not first and nx == sx and ny == sy and ndir == sdir then
                break
            end

            if visited[nx+1] and visited[nx+1][ny+1] and visited[nx+1][ny+1][ndir+1] then
                break
            end

            x, y, dir = nx, ny, ndir
            first = false
        end
    end

    for y = 0, height-1 do
        for x = 0, width-1 do
            local case = get_case(x, y)
            if case ~= 0 and case ~= 15 then
                for dir = 0, 3 do
                    if not visited[x+1][y+1][dir+1] then
                        trace_contour(x, y, dir)
                    end
                end
            end
        end
    end

    flat_points = dissolve_colinear_points(flat_points, true)

    require "common.delaunay_triangulation"
    return rt.DelaunayTriangulation(flat_points, flat_points):get_triangles()
end