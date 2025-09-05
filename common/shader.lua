rt.settings.shader = {
    precompilation_queue = meta.make_weak({})
}

--- @class rt.Shader
rt.Shader = meta.class("Shader")

local _stencil_active_uniform_name = "love_StencilActive";

--- @brief
function rt.Shader:instantiate(filename, defines)
    meta.install(self, {
        _native = nil, -- == nil marks not precompiled yet
        _filename = filename,
        _defines = defines,
        _before = nil,
        _is_disabled = false
    })
end

--- @brief
function rt.Shader:precompile()
    local success, shader = pcall(love.graphics.newShader, self._filename, {
        defines = self._defines
    })

    if not success then
        rt.critical("In rt.Shader: Error when evaluating shader at `" .. self._filenames .. "`:\n" .. shader)
        self._is_disabled = true
    else
        self._native = shader
        rt.settings.shader.precompilation_queue[self._native] = self._native
    end
end

--- @brief set uniform
--- @param name String
--- @param value
function rt.Shader:send(name, value, ...)
    if self._is_disabled then return elseif self._native == nil then self:precompile() end

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
    if self._is_disabled then return {} elseif self._native == nil then self:precompile() end
    return self._native:getBufferFormat(name)
end

--- @brief
function rt.Shader:has_uniform(name)
    if self._is_disabled then return false elseif self._native == nil then self:precompile() end
    return self._native:hasUniform(name)
end

--- @brief make shader the current on
function rt.Shader:bind()
    self._before = love.graphics.getShader()
    if self._is_disabled then return elseif self._native == nil then self:precompile() end

    if self._native:hasUniform("love_StencilActive") then
        -- custom stencil behavior for canvases
        self._native:send("love_StencilActive", rt.graphics._stencil_mode_active == true)
    end

    love.graphics.setShader(self._native)
end

--- @brief
function rt.Shader:unbind()
    if self._native == nil then self:precompile() end
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
    if self._native == nil then self:precompile() end
    return self._native
end
