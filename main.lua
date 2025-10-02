require "include"
require "common.color"

local m = love.math
local g = love.graphics

local tmp = m.newTransform()
local bak = m.newTransform()
local R3 = {}

function R3.new_inverse(width, height)
    return m.newTransform():setMatrix(
        2/width,0,0,-1,
        0,-2/height,0,1,
        0,0,-1/10,0,
        0,0,0,1
    ):inverse()
end

function R3.new_perspective(width, height, near, hfov)
    local n = near or .1
    hfov = hfov or math.pi*.5
    local f = 1/math.tan(hfov*.5)
    local ar = width/height
    return m.newTransform():setMatrix(
        f/ar, 0, 0, 0,
        0, f, 0, 0,
        0, 0, 1, -2*n,
        0, 0, 1, 0
    )
end

function R3.new_ortho(width, height, near, far)
    return m.newTransform():setMatrix(
        2/width, 0, 0, 0,
        0, 2/height, 0, 0,
        0, 0, 2/(far-near), -(far+near)/(far-near),
        0, 0, 0, 1
    )
end

function R3.new_origin(perspective, width, height, near, hfov)
    if perspective then
        return R3.new_inverse(width, height):apply(R3.new_perspective(width, height, near, hfov))
    else
        return R3.new_inverse(width, height):apply(R3.new_ortho(2, 2, near, hfov))
    end
end

function R3.translate(x,y,z)
    tmp:setMatrix(
        1,0,0,x,
        0,1,0,y,
        0,0,1,z,
        0,0,0,1
    )
    tmp, bak = bak, tmp
    return bak
end

function R3.scale(x,y,z)
    tmp:setMatrix(
        x,0,0,0,
        0,y,0,0,
        0,0,z,0,
        0,0,0,1
    )
    tmp, bak = bak, tmp
    return bak
end

function R3.rotate(i,j,k,w)
    tmp:setMatrix(
        1-2*j*j-2*k*k, 2*i*j+2*w*k, 2*i*k-2*w*j, 0,
        2*i*j-2*w*k, 1-2*i*i-2*k*k, 2*j*k+2*w*i, 0,
        2*i*k+2*w*j, 2*j*k-2*w*i, 1-2*i*i-2*j*j, 0,
        0, 0, 0, 1
    )
    tmp, bak = bak, tmp
    return bak
end

function R3.aa_to_quat(x,y,z,a)
    --let's turn axis angle into a quaternion
    local l = math.sqrt(x*x+y*y+z*z)
    x,y,z = x/l, y/l, z/l --normalize imaginary part
    local w, s = math.cos(a/2), math.sin(a/2) --the real part is a COsine of half an angle
    --the imaginary part will get multiplied by sine of half an angle
    return x*s, y*s, z*s, w
end

local vformat = {
    {"VertexPosition", "float", 3},
    {"VertexTexCoord", "float", 2},
    {"VertexColor", "float", 4},
}

-- Function to generate a UV sphere mesh
function make_sphere_mesh(cx, cy, cz, radius, rings, segments)
    local vertices = {}
    local indices = {}

    -- Use standard UV sphere generation for correct triangulation
    for r = 0, rings do
        local v = r / rings
        local theta = v * math.pi
        local sin_theta = math.sin(theta)
        local cos_theta = math.cos(theta)

        -- Apply Fibonacci-like distribution to segments
        for s = 0, segments do
            -- Fibonacci-like distribution around the circle
            local golden_ratio = (1 + math.sqrt(5)) / 2
            local u_fib = (s / segments) * golden_ratio % 1.0

            local phi = u_fib * math.pi * 2
            local sin_phi = math.sin(phi)
            local cos_phi = math.cos(phi)

            local x = cx + radius * sin_theta * cos_phi
            local y = cy + radius * cos_theta
            local z = cz + radius * sin_theta * sin_phi

            table.insert(vertices, {
                x, y, z,
                u_fib, v,
                rt.lcha_to_rgba(0.8, 1, s / segments, 1)
            })
        end
    end

    -- Standard UV sphere triangulation (guaranteed to work)
    local verts_per_row = segments + 1
    for r = 0, rings - 1 do
        for s = 0, segments - 1 do
            local i1 = r * verts_per_row + s + 1
            local i2 = i1 + verts_per_row
            local i3 = i1 + 1
            local i4 = i2 + 1

            table.insert(indices, i1)
            table.insert(indices, i2)
            table.insert(indices, i3)

            table.insert(indices, i3)
            table.insert(indices, i2)
            table.insert(indices, i4)
        end
    end

    local mesh = love.graphics.newMesh(vformat, vertices, "triangles", "static")
    mesh:setVertexMap(indices)
    return mesh
end

-- Example usage: replace your cube mesh with a sphere
local sphere = make_sphere_mesh(0, 0, 0, 1, 8, 8)

-- In your love.draw(), use "sphere" instead of "cube":
-- g.draw(sphere)

-- Or replace the cube global:
local cube = sphere

g.setMeshCullMode("back")
g.setFrontFaceWinding("ccw")
g.setDepthMode("less", true)

local origin = R3.new_origin(true, g.getDimensions())

function love.draw()
    local t = love.timer.getTime()
    g.setDepthMode("less", true)
    g.replaceTransform(
        origin *
            R3.translate(0,0,2.5) * --step away a little bit
            R3.rotate(R3.aa_to_quat(math.cos(t), math.sin(t), 0, t%(math.pi*2))) --rotate the cube
    )

    g.draw(cube)
    g.origin()
    g.setDepthMode("always", false)
    g.print(love.timer.getDelta())
    g.print(g.getStats().drawcalls, 0, 20)
    g.print(love.timer.getFPS(), 0, 40)
end

function love.keypressed(k,s,r)
    if k == "escape" then love.event.quit(0) end
end