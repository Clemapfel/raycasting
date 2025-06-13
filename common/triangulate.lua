if rt == nil then rt = {} end
if rt.math == nil then rt.math = {} end

local slick = require "dependencies.slick.slick"
require "common.delaunay_triangulation"

local _instance = rt.DelaunayTriangulation()

rt.math.triangulate = function(points, use_speedup)
    local success, out = pcall(love.math.triangulate, points)
    if not success then
        if use_speedup then
            return _instance:triangulate(points, points):get_triangles()
        else
            success, out = pcall(slick.triangulate, { points })
            if not success then
                rt.error(out)
            end
        end
    end

    return out
end

rt.math.polygonize = function(n, points)
    return slick.polygonize(n, { points })
end
