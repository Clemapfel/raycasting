--- @class rt.Shader
rt.Shader = meta.class("Shader")

local _stencil_active_uniform_name = "love_StencilActive";

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
        _defines = defines,
        _filename = filename,
        _before = nil,
    })
end


--- @brief set uniform
--- @param name String
--- @param value
function rt.Shader:send(name, value, ...)
    assert(value ~= nil, "In rt.Shader.send: uniform `" .. name .. "` is nil")
    if meta.typeof(value) == "GraphicsBuffer" or meta.typeof(value) == "Texture" or meta.typeof(value) == "RenderTexture" then value = value._native end
    if self._native:hasUniform(name) then
        self._native:send(name, value, ...)
    else
        if self._uniform_to_warning_printed == nil then self._uniform_to_warning_printed = {} end
        if self._uniform_to_warning_printed[name] == true then return end

        rt.warning("In rt.Shader: shader at `" .. self._filename .. "` does not have uniform `" .. name .. "`")
        self._uniform_to_warning_printed[name] = true
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

    if self._native:hasUniform("love_StencilActive") then
        -- custom stencil behavior for canvases
        self._native:send("love_StencilActive", rt.graphics._stencil_mode_active == true)
    end

    love.graphics.setShader(self._native)
end

--- @brief
function rt.Shader:unbind()
    love.graphics.setShader(self._before)
end

--- @brief
function rt.Shader:recompile()
    local success, native = pcall(love.graphics.newShader, self._filename, {
        defines = self._defines
    })

    if success then
        self._native = native
    else
        rt.critical("In rt.Shader.recompile: for shader at `" .. self._filename .. "`:\n" .. native)
    end
end

--- @brief
function rt.Shader:get_native()
    return self._native
end
