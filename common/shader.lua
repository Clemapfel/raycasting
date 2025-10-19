rt.settings.shader = {
    precompilation_queue = meta.make_weak({})
}

--- @class rt.Shader
rt.Shader = meta.class("Shader")

local _dummy_shader = love.graphics.newShader([[
vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    return vec4(vec3(0.5), 1) * texture(tex, texture_coords);
}
]])

local _feature_to_define = {
    ["shaderderivatives"] = "RT_SHADER_DERIVATIVES",
    ["glsl4"] = "RT_GLSL4",
    ["glsl3"] = "RT_GLSL3"
}

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
function rt.Shader:compile()
    if self._native ~= nil then
        rt.settings.shader.precompilation_queue[self._native] = nil
    end

    if self._defines == nil then self._defines = {} end

    local supported = love.graphics.getSupported()
    for feature, define in pairs(_feature_to_define) do
        self._defines[feature] = ternary(supported[feature], define, nil)
    end

    local success, shader = pcall(love.graphics.newShader, self._filename, {
        defines = self._defines
    })

    if not success then
        rt.critical("In rt.Shader: Error when evaluating shader at `" .. self._filename .. "`:\n" .. shader)
        self._native = _dummy_shader
        self._is_disabled = true
    else
        self._native = shader
        rt.settings.shader.precompilation_queue[self._native] = self._native
    end
end

--- @brief flush all shaders, prevents shader compilation stutter on vulkan
function rt.Shader:precompile_all()
    love.graphics.push("all")
    local texture = love.graphics.newCanvas(1, 1)
    love.graphics.setCanvas(texture)
    for native in values(rt.settings.shader.precompilation_queue) do
        love.graphics.setShader(native)
        love.graphics.rectangle("fill", 0, 0, 1, 1)
        love.graphics.setShader(nil)
    end
    love.graphics.pop("all")

    rt.settings.shader.precompilation_queue = meta.make_weak({})
end

--- @brief set uniform
--- @param name String
--- @param value
function rt.Shader:send(name, value, ...)
    if self._is_disabled then return elseif self._native == nil then self:compile() end

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
    if self._is_disabled then return {} elseif self._native == nil then self:compile() end
    return self._native:getBufferFormat(name)
end

--- @brief
function rt.Shader:has_uniform(name)
    if self._is_disabled then return false elseif self._native == nil then self:compile() end
    return self._native:hasUniform(name)
end

--- @brief make shader the current on
function rt.Shader:bind()
    self._before = love.graphics.getShader()
    if self._native == nil then self:compile() end
    love.graphics.setShader(self._native)
end

--- @brief
function rt.Shader:unbind()
    if self._native == nil then self:compile() end
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
    if self._native == nil then self:compile() end
    return self._native
end
