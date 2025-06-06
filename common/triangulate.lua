if rt == nil then rt = {} end
if rt.math == nil then rt.math = {} end

local slick = require "dependencies.slick.slick"
rt.math.triangulate = function(points)
    local success, out = pcall(love.math.triangulate, points)
    if not success then
        success, out = pcall(slick.triangulate, { points })
        if not success then
            rt.error(out)
        end
    end

    return out
end

rt.math.polygonize = function(n, points)
    return slick.polygonize(n, { points })
end
