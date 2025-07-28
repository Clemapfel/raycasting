require "common.graphics_buffer_usage"

--- @class rt.MeshDrawMode
rt.MeshDrawMode = meta.enum("MeshDrawMode", {
    TRIANGLE_FAN = "fan",
    TRIANGLE_STRIP = "strip",
    TRIANGLES = "triangles",
    POINTS = "points"
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

--- @class rt.MeshAttributeAttachmentMode
rt.MeshAttributeAttachmentMode = meta.enum("MeshAttributeAttachmentMode", {
    PER_VERTEX = "pervertex",
    PER_INSTANCE = "perinstance"
})

rt.VertexFormat = {
    { location = rt.VertexAttributeLocation.POSITION, name = rt.VertexAttribute.POSITION, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.TEXTURE_COORDINATES, name = rt.VertexAttribute.TEXTURE_COORDINATES, format = "floatvec2" },
    { location = rt.VertexAttributeLocation.COLOR, name = rt.VertexAttribute.COLOR, format = "floatvec4" },
}

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

local _n_outer_vertices_to_vertex_map = {}

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