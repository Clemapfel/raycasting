require "include"
require "common.color"
require "common.transform"
require "common.shader"

-- Function to generate a UV sphere mesh
function make_sphere_mesh(center_x, center_y, center_z, radius, n_rings, n_segments_per_ring)
    local data = {}
    local indices = {}

    -- Generate vertices
    for ring = 0, n_rings do
        local phi = (ring / n_rings) * math.pi -- 0 to π (top to bottom)
        local y = math.cos(phi)
        local ring_radius = math.sin(phi)

        for seg = 0, n_segments_per_ring do
            local theta = (seg / n_segments_per_ring) * 2 * math.pi -- 0 to 2π (around)

            -- Position
            local x = ring_radius * math.cos(theta)
            local z = ring_radius * math.sin(theta)

            -- Scale by radius and offset by center
            local px = center_x + x * radius
            local py = center_y + y * radius
            local pz = center_z + z * radius

            -- UV coordinates
            local u = seg / n_segments_per_ring
            local v = ring / n_rings

            -- Insert vertex: { x, y, z, u, v, r, g, b, a }
            table.insert(data, {px, py, pz, u, v, rt.lcha_to_rgba(0.8, 1,  ternary(y == -1, 0.5, 1), 1) })
        end
    end

    -- Generate indices for triangulation
    for ring = 0, n_rings - 1 do
        for seg = 0, n_segments_per_ring - 1 do
            -- Current ring vertices
            local current = ring * (n_segments_per_ring + 1) + seg + 1 -- +1 for 1-based indexing
            local next_seg = ring * (n_segments_per_ring + 1) + seg + 2

            -- Next ring vertices
            local below = (ring + 1) * (n_segments_per_ring + 1) + seg + 1
            local below_next = (ring + 1) * (n_segments_per_ring + 1) + seg + 2

            -- First triangle (current, next_seg, below)
            table.insert(indices, current)
            table.insert(indices, next_seg)
            table.insert(indices, below)

            -- Second triangle (next_seg, below_next, below)
            table.insert(indices, next_seg)
            table.insert(indices, below_next)
            table.insert(indices, below)
        end
    end

    require "common.mesh"
    local mesh = love.graphics.newMesh(rt.VertexFormat3D, data, "triangles", "static")
    mesh:setVertexMap(indices)
    return mesh
end

-- create render canvas
require "common.render_texture_3d"
local canvas_3d = rt.RenderTexture3D(love.graphics.getDimensions())
local sphere_mesh = make_sphere_mesh(
    0, 0, 0,  -- center
    100, -- radius
    8, 8 -- n rings, n segments per ring
)

local perspective = true
love.keypressed = function()
    perspective = not perspective
end

local shader = rt.Shader("main_3d.glsl")

function love.draw()
    local time = love.timer.getTime()

    local model = rt.Transform()
    model:rotate_y(time)
    model:translate(
        0,--0.5 * love.graphics.getWidth(),
        0,--0.5 * love.graphics.getHeight(),
        0
    )

    local view = rt.Transform()
    view:translate(0, 0, -1000)

    canvas_3d:set_projection_type(ternary(perspective,
        rt.ProjectionType3D.ORTHOGRAPHIC,
        rt.ProjectionType3D.PERSPECTIVE
    ))

    canvas_3d:set_fov(0.2)
    canvas_3d:set_model_transform(model)
    canvas_3d:set_view_transform(view)
    canvas_3d:bind()
    shader:bind()

    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.draw(sphere_mesh)
    shader:unbind()
    canvas_3d:unbind()

    love.graphics.setColor(1, 1, 1, 1)
    canvas_3d:draw()
end