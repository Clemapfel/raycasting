require "common.graphics_buffer_usage"

--- @class rt.MeshDrawMode
rt.MeshDrawMode = meta.enum("MeshDrawMode", {
    TRIANGLE_FAN = "fan",
    TRIANGLE_STRIP = "strip",
    TRIANGLES = "triangles",
    POINTS = "points"
})

--- @class rt.MeshAttributeAttachmentMode
rt.MeshAttributeAttachmentMode = meta.enum("MeshAttributeAttachmentMode", {
    PER_VERTEX = "pervertex",
    PER_INSTANCE = "perinstance"
})

--- @class rt.VertexAttribute
rt.VertexAttribute = meta.enum("VertexAttribute", {
    POSITION = "VertexPosition",
    TEXTURE_COORDINATES = "VertexTexCoord",
    COLOR = "VertexColor"
})

--- @class rt.VertexAttributeLocation
rt.VertexAttributeLocation = meta.enum("VertexAttribute", {
    POSITION = 0,
    TEXTURE_COORDINATES = 1,
    COLOR = 2
})

rt.VertexFormat2D = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.TEXTURE_COORDINATES, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.COLOR, name = rt.VertexAttribute.COLOR, format = "floatvec4" },
}

rt.VertexFormat3D = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec3" },
    { location = rt.VertexAttributeLocation.TEXTURE_COORDINATES, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.COLOR, name = rt.VertexAttribute.COLOR, format = "floatvec4" },
}

rt.VertexFormat = rt.VertexFormat2D

--- @class rt.Mesh
rt.Mesh = meta.class("Mesh", rt.Drawable)

--- @brief
function rt.Mesh:instantiate(data, draw_mode, format, usage)
    meta.install(self, {
        _native = love.graphics.newMesh(
            format or rt.VertexFormat,
            data,
            draw_mode or rt.MeshDrawMode.TRIANGLE_FAN,
            usage or rt.GraphicsBufferUsage.STATIC
        ),
        _r = 1,
        _g = 1,
        _b = 1,
        _opacity = 1
    })
end

--- @class rt.VertexRectangle
rt.MeshRectangle = function(x, y, width, height)
    if x == nil then x = 0 end
    if y == nil then y = 0 end
    if width == nil then width = 1 end
    if height == nil then height = 1 end

    local data = {
        {x + 0 * width, y + 0 * height, 0, 0, 1, 1, 1, 1},
        {x + 1 * width, y + 0 * height, 1, 0, 1, 1, 1, 1},
        {x + 1 * width, y + 1 * height, 1, 1, 1, 1, 1, 1},
        {x + 0 * width, y + 1 * height, 0, 1, 1, 1, 1, 1}
    }

    local out = setmetatable({}, meta.get_instance_metatable(rt.Mesh))
    return meta.install(out, {
        _native = love.graphics.newMesh(
            rt.VertexFormat,
            data,
            rt.MeshDrawMode.TRIANGLE_FAN,
            rt.GraphicsBufferUsage.STATIC
        ),
        _r = 1,
        _g = 1,
        _b = 1,
        _opacity = 1
    })
end


--- @class rt.VertexCircle
rt.MeshCircle = function(center_x, center_y, x_radius, y_radius, n_outer_vertices)
    y_radius = y_radius or x_radius
    n_outer_vertices = n_outer_vertices or 16
    local data = {
        {center_x, center_y, 0.5, 0.5, 1, 1, 1, 1},
    }

    local step = 2 * math.pi / n_outer_vertices
    for angle = 0, 2 * math.pi, step do
        table.insert(data, {
            center_x + math.cos(angle) * x_radius,
            center_y + math.sin(angle) * y_radius,
            0.5 + math.cos(angle) * 0.5,
            0.5 + math.sin(angle) * 0.5,
            1, 1, 1, 1
        })
    end

    local map = {}
    for outer_i = 2, n_outer_vertices do
        for i in range(1, outer_i, outer_i + 1) do
            table.insert(map, i)
        end
    end

    for i in range(n_outer_vertices + 1, 1, 2) do
        table.insert(map, i)
    end

    local native = love.graphics.newMesh(
        rt.VertexFormat,
        data,
        rt.MeshDrawMode.TRIANGLES,
        rt.GraphicsBufferUsage.STATIC
    )
    native:setVertexMap(map)

    local out = setmetatable({}, meta.get_instance_metatable(rt.Mesh))
    return meta.install(out, {
        _native = native,
        _r = 1,
        _g = 1,
        _b = 1,
        _opacity = 1
    })
end

--- @class rt.MeshLine
rt.MeshLine = function(x1, y1, x2, y2, thickness)
    if thickness == nil then thickness = 1 end

    local dx, dy = x2 - x1, y2 - y1
    local length = math.sqrt(dx * dx + dy * dy)
    local nx, ny = -dy / length, dx / length

    local half_thickness = thickness / 2
    local vertices = {
        {x1 + nx * half_thickness, y1 + ny * half_thickness, 0, 0, 1, 1, 1, 1},
        {x1 - nx * half_thickness, y1 - ny * half_thickness, 0, 1, 1, 1, 1, 1},
        {x2 - nx * half_thickness, y2 - ny * half_thickness, 1, 1, 1, 1, 1, 1},
        {x2 + nx * half_thickness, y2 + ny * half_thickness, 1, 0, 1, 1, 1, 1},
    }

    local out = setmetatable({}, meta.get_instance_metatable(rt.Mesh))
    return meta.install(out, {
        _native = love.graphics.newMesh(
            rt.VertexFormat,
            vertices,
            rt.MeshDrawMode.TRIANGLE_FAN,
            rt.GraphicsBufferUsage.STATIC
        )
    })
end

--- @class rt.MeshPlane
rt.MeshPlane = function(center_x, center_y, center_z, width, height, curvature, n_segments_x, n_segments_y)
    -- Choose resolution based on size and curvature
    -- More curvature needs more vertices for smooth deformation
    n_segments_x = n_segments_x or math.max(20, math.floor(width * 2 + curvature * 10))
    n_segments_y = n_segments_y or math.max(20, math.floor(height * 2 + curvature * 10))

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


--- @class rt.MeshSphere
function rt.MeshSphere(center_x, center_y, center_z, radius, n_rings, n_segments_per_ring)
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
            local c = 1 --math.max(math.cos(theta - math.pi / 2), 0.5)
            table.insert(data, { px, py, pz, u, v, c, c, c, 1 })
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

--- @override
function rt.Mesh:draw(...)
    love.graphics.draw(self._native, ...)
end

--- @brief
function rt.Mesh:draw_instanced(n_instances)
    love.graphics.drawInstanced(self._native, n_instances)
end

--- @brief
function rt.Mesh:reformat(...)
    local n = select("#", ...)
    local vertex_i = 1
    for i = 1, n, 2 do
        local x, y = select(i, ...), select(i + 1, ...)
        self._native:setVertexAttribute(vertex_i, 1, x, y)
        vertex_i = vertex_i + 1
    end
end

--- @brief
function rt.Mesh:reformat_texture_coordinates(...)
    local n = select("#", ...)
    local vertex_i = 1
    for i = 1, n, 2 do
        local x, y = select(i, ...), select(i + 1, ...)
        self._native:setVertexAttribute(vertex_i, 2, x, y)
        vertex_i = vertex_i + 1
    end
end

--- @brief
function rt.Mesh:set_vertex_position(i, x, y)
    self._native:setVertexAttribute(i, 1, x, y)
end

--- @brief
function rt.Mesh:set_vertex_texture_coordinate(i, u, v)
    self._native:setVertexAttribute(i, 2, u, v)
end

--- @brief
function rt.Mesh:set_vertex_color(i, r, g, b, a)
    self._native:setVertexAttribute(i, 3, r, g, b, a)
end

--- @brief
function rt.Mesh:get_vertex_attributes()
    local out = {}
    for i = 1, #self._native:getVertexFormat() do
        for x in range(self._native:getVertexAttribute()) do
            table.insert(out)
        end
    end
    return out
end

--- @brief
function rt.Mesh:set_vertex_attribute(i, ...)
    self._native:setVertexAttribute(i, ...)
end

--- @brief
function rt.Mesh:set_texture(texture)
    self._native:setTexture(texture._native)
end

--- @brief
function rt.Mesh:get_n_vertices()
    return self._native:getVertexCount()
end

--- @brief
function rt.Mesh:replace_data(data)
    self._native:setVertices(data)
end

--- @brief
function rt.Mesh:set_vertex_map(map, ...)
    if type(map) == "number" then
        map = { map, ... }
    end

    self._native:setVertexMap(map)
end

--- @brief
function rt.Mesh:get_native()
    return self._native
end

--- @brief
function rt.Mesh:attach_attribute(mesh, attribute_name, mode)
    self._native:attachAttribute(attribute_name, mesh:get_native(), mode or "pervertex")
end