Mesh_t = "Mesh"

GraphicsBufferUsage = {
    STATIC = "static",
    DYNAMIC = "dynamic",
    STREAM = "stream"
}

mesh_new = function(data, usage)
    if usage == nil then usage = GraphicsBufferUsaged.DYNAMIC end
    return object_new(Mesh_t, {
        native = love.graphics.newMesh(data, "triangles", usage)
    })
end

mesh_set_texture = function(self, texture)
    log_typecheck(self, Mesh_t, texture, Optional_t(Texture_t))

    if texture == nil then
        self.native:setTexture(nil)
    else
        self.native:setTexture(texture.native)
    end
end

mesh_draw = function(self, ...)
    log_typecheck(self, Mesh_t)
    love.graphics.draw(self.native, ...)
end

mesh_update_vertices = function(self, data)
    log_typecheck(self, Mesh_t, data, Table_t)
    self.native:setVertices(data)
end