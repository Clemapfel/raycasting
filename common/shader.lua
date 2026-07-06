rt.settings.shader = {
    precompilation_queue = meta.make_weak({})
}

--- @class rt.Shader
--- @overload fun(filename : String?, defines : Table?)
rt.Shader = meta.class("Shader")

local _dummy_shader = love.graphics.newShader([[
vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 screen_coords) {
    return vec4(vec3(0.5), 1) * texture(tex, texture_coords);
}
]])

--- @brief
function rt.Shader:instantiate(filename, defines)
    meta.install(self, {
        _native = nil, -- == nil marks not precompiled yet
        _filename = filename,
        _defines = defines,
        _before = nil,
        _is_disabled = false,
        _uniform_to_warning_printed = {}
    })
end

--- @brief
function rt.Shader:compile()
    if self._native ~= nil then
        rt.settings.shader.precompilation_queue[self._native] = nil
    end

    if self._defines == nil then self._defines = {} end

    if DEBUG then
        local valid, message = love.graphics.validateShader(true, self._filename, {
            defines = self._defines
        })

        if not valid then
            rt.error("In rt.Shader: Error when validating shader at `", self._filename, "` for GL ES:\n", message)
        end
    end

    local success, shader = pcall(love.graphics.newShader, self._filename, {
        defines = self._defines
    })

    if not success then
        rt.critical("In rt.Shader: Error when evaluating shader at `", self._filename, "`:\n", shader)
        self._native = _dummy_shader
        self._is_disabled = true
    else
        self._native = shader
        rt.settings.shader.precompilation_queue[self] = self
    end
end

do
    local _render_textures, _draw_callbacks

    --- @brief force compilation of the shader program gpu-side, necessary on vulkan
    function rt.Shader:precompile()
        if _render_textures == nil then
            _render_textures = {}
            for format in range(
                rt.TextureFormat.R8,
                rt.TextureFormat.RGB565,
                rt.TextureFormat.RGBA8
            ) do
                table.insert(_render_textures,
                    love.graphics.newCanvas(1, 1, {
                        format = format
                    })
                )
            end
        end

        if _draw_callbacks == nil then
            local mesh = love.graphics.newMesh({
                { 0, 0, 0, 0, 1, 1, 1, 1 },
                { 1, 0, 1, 0, 1, 1, 1, 1 },
                { 1, 1, 1, 1, 1, 1, 1, 1 },
                { 0, 1, 0, 1, 1, 1, 1, 1 }
            }, "fan", "static")

            local texture = love.graphics.newImage(love.image.newImageData(1, 1))
            mesh:setTexture(texture)

            _draw_callbacks = {
                function() love.graphics.draw(mesh) end,
                function() love.graphics.polygon("fill", { 0, 0, 1, 0, 1, 1, 0, 1 }) end,
                function() love.graphics.draw(texture) end
            }
        end

        love.graphics.push("all")
        love.graphics.reset()
        for canvas in values(_render_textures) do
            love.graphics.setCanvas({ canvas, stencil = true, depth = true })
            for callback in values(_draw_callbacks) do
                love.graphics.setShader(self._native)
                callback()
                love.graphics.setShader(nil)
            end
        end
        love.graphics.pop() -- all
    end
end

--- @brief flush all shaders, prevents shader compilation stutter on vulkan
function rt.Shader:precompile_all()
    love.graphics.push("all")

    for shader in values(rt.Shader.precompilation_queue) do
        shader:precompile()
    end

    rt.settings.shader.precompilation_queue = meta.make_weak({})
end

--- @brief set uniform
--- @param name String
--- @param value Any
function rt.Shader:send(name, value, ...)
    if self._is_disabled then return elseif self._native == nil then self:compile() end

    rt.assert(value ~= nil, "In rt.Shader.send: uniform `", name, "` is nil")

    local args = { value, ... }
    for i, x in ipairs(args) do
        if meta.is_table(x) then
            if meta.is_function(x.get_native) then
                args[i] = x:get_native()
            elseif meta.is_function(x.unpack) then
                args[i] = { x:unpack() }
            end
        end
    end

    if self._native:hasUniform(name) then
        self._native:send(name, table.unpack(args))
    else
        if self._uniform_to_warning_printed[name] ~= true then
            rt.critical("In rt.Shader: shader at `", self._filename, "` does not have uniform `", name, "`")
            self._uniform_to_warning_printed[name] = true
        end
    end
end

--- @brief
function rt.Shader:try_send(name, value, ...)
    if value == nil or self._native:hasUniform(name) == false then return false end
    self:send(name, value, ...)
    return true
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
        rt.critical("In rt.Shader.recompile: for shader at `", self._filename, "`:\n", native)
    end

    self._uniform_to_warning_printed = {}
end

--- @brief
function rt.Shader:get_native()
    if self._native == nil then self:compile() end
    return self._native
end
