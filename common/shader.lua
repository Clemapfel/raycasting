--- @class rt.Shader
rt.Shader = meta.class("Shader")

local _path_to_shader = {} -- shader atlas

--- @return rt.Shader
function rt.Shader:instantiate(path)
    local cached = _path_to_shader[path]
    if cached == nil then
        cached = love.graphics.newShader(path)
    end

    meta.install(self, {
        _path = path,
        _native = cached
    })
end

--- @brief
function rt.Shader:bind()
    love.graphics.setShader(self._native)
end

--- @brief
function rt.Shader:unbind()
    love.graphics.setShader(nil)
end

--- @brief
function rt.Shader:send(name, value)
    assert(value ~= nil, "In Shader.send: value for uniform `name` is nil")
    if self._native:hasUniform(name) ~= true then
        rt.warning("In Shader.send: shader has no uniform called `" .. name .. "`")
        return
    end

    self._native:send(name, value)
end

--- @brief
function rt.Shader:has_uniform(name)
    assert(type(name) == "string")
    return self._native:hasUniform(name)
end

--- @brief
function rt.Shader:get_native()
    return self._native
end

--- @brief
function rt.Shader:recompile()
    self._native = love.graphics.newShader(self._path)
    _path_to_shader[self._path] = self._native
end

--- @brief
function rt.Shader:get_buffer_format(name)
    return self._native:getBufferFormat(name)
end
