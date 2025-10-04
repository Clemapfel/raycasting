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
            local v = 1 - ring / n_rings

            -- Insert vertex: { x, y, z, u, v, r, g, b, a }
            local c = math.max(math.cos(theta - math.pi / 2), 0.5)
            table.insert(data, { px, py, pz, u, v, c, c, c, 0.25 })
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
    local mesh = rt.Mesh(data, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat3D)
    mesh:set_vertex_map(indices)
    return mesh
end

function make_deformed_plane_mesh(center_x, center_y, center_z, width, height, curvature)
    -- Choose resolution based on size and curvature
    -- More curvature needs more vertices for smooth deformation
    local n_segments_x = math.max(20, math.floor(width * 2 + curvature * 10))
    local n_segments_y = math.max(20, math.floor(height * 2 + curvature * 10))

    local data = {}
    local indices = {}

    -- Half dimensions for centering
    local half_width = width / 2
    local half_height = height / 2

    -- Generate vertices
    for row = 0, n_segments_y do
        for col = 0, n_segments_x do
            -- Normalized coordinates from 0 to 1
            local u = col / n_segments_x
            local v = row / n_segments_y

            -- Position in plane space (before deformation)
            -- Map from [0,1] to [-half_width, half_width] and [-half_height, half_height]
            local px = (u - 0.5) * width
            local py = (v - 0.5) * height

            -- Calculate distance from center for deformation
            local dist = math.sqrt(px * px + py * py)

            -- Spherical deformation using a smooth falloff function
            -- The deformation creates a bump at the center that smoothly falls off
            local max_radius = math.sqrt(half_width * half_width + half_height * half_height)
            local normalized_dist = math.min(dist / max_radius, 1)

            -- Use cosine falloff for smooth deformation (like a sphere cap)
            -- pz represents the vertical displacement
            local pz = curvature * math.cos(normalized_dist * math.pi / 2)

            -- World space position
            local world_x = center_x + px
            local world_y = center_y + py
            local world_z = center_z + pz

            -- Insert vertex: { x, y, z, u, v, r, g, b, a }
            table.insert(data, {
                world_x, world_y, world_z,
                u, v,
                1, 1, 1, 1
            })
        end
    end

    -- Generate indices for triangulation
    for row = 0, n_segments_y - 1 do
        for col = 0, n_segments_x - 1 do
            -- Current row vertices (1-based indexing)
            local current = row * (n_segments_x + 1) + col + 1
            local next_col = row * (n_segments_x + 1) + col + 2

            -- Next row vertices
            local below = (row + 1) * (n_segments_x + 1) + col + 1
            local below_next = (row + 1) * (n_segments_x + 1) + col + 2

            -- First triangle (current, next_col, below)
            table.insert(indices, current)
            table.insert(indices, next_col)
            table.insert(indices, below)

            -- Second triangle (next_col, below_next, below)
            table.insert(indices, next_col)
            table.insert(indices, below_next)
            table.insert(indices, below)
        end
    end

    require "common.mesh"
    local mesh = rt.Mesh(data, rt.MeshDrawMode.TRIANGLES, rt.VertexFormat3D)
    mesh:set_vertex_map(indices)
    return mesh
end

-- create render canvas
require "common.render_texture_3d"
local canvas_3d = rt.RenderTexture3D(love.graphics.getDimensions())

local sphere_x, sphere_y, sphere_z = 0, 0, 0

local instance_mesh = make_sphere_mesh(
    sphere_x, sphere_y, sphere_z,  -- center
    1, -- radius
    8, 8 -- n rings, n segments per ring
)

require "common.random"
local data_mesh_data = {}
local min_x, max_x = -100, 100
local min_y, max_y = -100, 100
local min_z, max_z = -100, 100
local min_r, max_r = 2, 5
local n_instances = 5000
for i = 1, n_instances do
    table.insert(data_mesh_data, {
        rt.random.number(min_x, max_x),
        rt.random.number(min_y, max_y),
        rt.random.number(min_z, max_z),

        rt.random.number(min_r, max_r),

        rt.random.number(0, 1)
    })
end

local data_mesh_format = {
    { location = 3, name = "position", format = "floatvec3" },
    { location = 4, name = "radius", format = "float" },
    { location = 5, name = "hue", format = "float" }
}
local data_mesh = rt.Mesh(data_mesh_data, rt.MeshDrawMode.TRIANGLES, data_mesh_format, rt.GraphicsBufferUsage.STREAM)

for v in values(data_mesh_format) do
    instance_mesh:attach_attribute(data_mesh, v.name, rt.MeshAttributeAttachmentMode.PER_INSTANCE)
end

local shader = rt.Shader("main_3d.glsl")

local curvature = 20
local eye_mesh = make_deformed_plane_mesh(
    sphere_x, sphere_y, sphere_z + math.sqrt(2) * curvature,
    100, 100,
    curvature
)

require "common.render_texture"
local radius, padding = 200
padding = radius * 0.5
local texture = rt.RenderTexture(
    2 * (radius + padding), 2 * (radius + padding)
)
texture:set_scale_mode(rt.TextureScaleMode.LINEAR)

require "overworld.player_recorder_eyes"
local eyes = ow.PlayerRecorderEyes(radius)

eye_mesh:set_texture(texture)

local camera_x, camera_z = 0, -200

function love.update(delta)
    eyes:update(delta)

    texture:bind()
    love.graphics.clear(true, true, true)
    love.graphics.translate(0.5 * texture:get_width(), 0.5 * texture:get_height())
    eyes:draw()
    texture:unbind()

    if love.keyboard.isDown("w") then
    camera_z = camera_z + 100 * delta
    elseif love.keyboard.isDown("s") then
    camera_z = camera_z - 10* delta
    elseif love.keyboard.isDown("a") then
    camera_x = camera_x - 100 * delta
    elseif love.keyboard.isDown("d") then
    camera_x = camera_x + 100 * delta
    end
    end

    function love.draw()
    local mouse_x, mouse_y = love.mouse.getPosition()
    local mouse_z = -10

    mouse_x, mouse_y = math.subtract(mouse_x, mouse_y, 0.5 * love.graphics.getWidth(), 0.5 * love.graphics.getHeight())
    mouse_x = mouse_x / love.graphics.getWidth()
    mouse_y = mouse_y / love.graphics.getHeight()

    local turn_magnitude = 30

    local model = rt.Transform()

    model:set_target_to(
    0, 0, 0,  -- eye / object position
    mouse_x * turn_magnitude, mouse_y * turn_magnitude, mouse_z, -- target (mouse converted)
    0, 1, 0 -- up vector (negative Y because screen Y goes down)
    )

    model = model:inverse()


    local view = rt.Transform()
    view:translate(camera_x, 0, camera_z)

    canvas_3d:set_projection_type(ternary(false,
    rt.ProjectionType3D.ORTHOGRAPHIC,
    rt.ProjectionType3D.PERSPECTIVE
    ))

    canvas_3d:set_fov(0.2)
    canvas_3d:set_model_transform(model)
    canvas_3d:set_view_transform(view)
    canvas_3d:bind()

    love.graphics.setMeshCullMode("back")

    love.graphics.clear(0, 0, 0, 1)
    love.graphics.setColor(1, 1, 1, 1)
    eye_mesh:draw()

    canvas_3d:unbind()

    love.graphics.setColor(1, 1, 1, 1)
    canvas_3d:draw()
    end