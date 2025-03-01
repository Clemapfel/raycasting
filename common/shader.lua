--- @class rt.Shader
rt.Shader = meta.class("Shader")

--- @brief
function rt.Shader:instantiate(filename, defines)
    local success, shader = pcall(love.graphics.newShader, filename, {
        defines = defines
    })

    if not success then
        rt.error("In rt.Shader: Error when evaluating shader at `" .. filename .. "`:\n" .. shader)
    end

    meta.install(self, {
        _native = shader,
        _filename = filename,
        _before = nil,
    })
end

--- @brief set uniform
--- @param name String
--- @param value
function rt.Shader:send(name, value)
    assert(value ~= nil, "In rt.Shader.send: uniform `" .. name .. "` is nil")
    if meta.isa(value, rt.GraphicsBuffer) or meta.isa(value, rt.Texture) then value = value._native end
    if self._native:hasUniform(name) then
        self._native:send(name, value)
    end
end

--- @brief
function rt.Shader:get_buffer_format(name)
    return self._native:getBufferFormat(name)
end

--- @brief
function rt.Shader:has_uniform(name)
    return self._native:hasUniform(name)
end

--- @brief make shader the current on
function rt.Shader:bind()
    self._before = love.graphics.getShader()
    love.graphics.setShader(self._native)
end

--- @brief
function rt.Shader:unbind()
    love.graphics.setShader(self._before)
end

--- @brief
function rt.Shader:recompile()
    self._native = love.graphics.newShader(self._filename)
end
