require "include"
require "common.color"
require "common.transform"

-- Function to generate a UV sphere mesh
function make_sphere_mesh(center_x, center_y, center_z, radius, rings, segments)
    local vertices = {}
    local indices = {}

    -- Use standard UV sphere generation for correct triangulation
    for ring = 0, rings do
        local v = ring / rings
        local theta = v * math.pi
        local sin_theta = math.sin(theta)
        local cos_theta = math.cos(theta)

        -- Apply Fibonacci-like distribution to segments
        for segment = 0, segments do
            -- Fibonacci-like distribution around the circle
            local golden_ratio = (1 + math.sqrt(5)) / 2
            local u_fib = (segment / segments) * golden_ratio % 1.0

            local phi = u_fib * math.pi * 2
            local sin_phi = math.sin(phi)
            local cos_phi = math.cos(phi)

            local x = center_x + radius * sin_theta * cos_phi
            local y = center_y + radius * cos_theta
            local z = center_z + radius * sin_theta * sin_phi

            table.insert(vertices, {
                x, y, z,
                u_fib, v,
                rt.lcha_to_rgba(0.8, 1, segment / segments, 1)
            })
        end
    end

    -- Standard UV sphere triangulation (guaranteed to work)
    local vertices_per_row = segments + 1
    for ring = 0, rings - 1 do
        for segment = 0, segments - 1 do
            local i1 = ring * vertices_per_row + segment + 1
            local i2 = i1 + vertices_per_row
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

    require "common.mesh"
    local mesh = love.graphics.newMesh(rt.VertexFormat3D, vertices, "triangles", "static")
    mesh:setVertexMap(indices)
    return mesh
end

-- Create sphere mesh
local sphere_mesh = make_sphere_mesh(0, 0, 0, 1, 8, 8)

-- get window dimensions
local window_width, window_height = love.graphics.getDimensions()

-- create render canvas
require "common.render_texture_3d"
local canvas_3d = rt.RenderTexture3D()

local projection_transform = rt.Transform()
projection_transform:as_screen_to_ndc_inverse(window_width, window_height)

local perspective_transform = rt.Transform()
perspective_transform:as_perspective_projection_hfov(window_width, window_height, 0.1, math.pi * 0.5)

local origin_transform = projection_transform:apply(perspective_transform)

function love.draw()
    local time = love.timer.getTime()

    -- Render 3D scene to canvas
    canvas_3d:bind()

    love.graphics.clear(0, 0, 0, 1)

    -- Create model transform (translation + rotation)
    local translation_transform = rt.Transform()
    translation_transform:translate(0, 0, 2.5)

    local rotation_transform = rt.Transform()
    local quat_i, quat_j, quat_k, quat_w = rt.Transform.axis_angle_to_quaternion(
        math.cos(time),
        math.sin(time),
        0,
        time % (math.pi * 2)
    )
    rotation_transform:set_to_orientation_from_quaternion(quat_i, quat_j, quat_k, quat_w)

    local model_view_projection = origin_transform:apply(translation_transform):apply(rotation_transform)

    love.graphics.replaceTransform(model_view_projection:get_native())
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sphere_mesh)

    canvas_3d:unbind()

    love.graphics.setColor(1, 1, 1, 1)
    canvas_3d:draw()
end

function love.keypressed(key, scancode, is_repeat)
    if key == "escape" then
        love.event.quit(0)
    end
end