rt.settings.compute_shader = {
    allow_unused_uniform = true
}

--- @class rt.ComputeShader
rt.ComputeShader = meta.class("ComputeShader")

--- @brief
function rt.ComputeShader:instantiate(filename, defines)
    local limits = love.graphics.getSystemLimits()
    self._is_disabled = 0 == (
        limits.threadgroupsx +
        limits.threadgroupsy +
        limits.threadgroupsz
    )

    if not self._is_disabled then
        local success, shader = pcall(love.graphics.newComputeShader, filename, {
            defines = defines
        })

        if not success then
            rt.error("In rt.ComputeShader: Error when evaluating shader at `", filename, "`:\n", shader)
        end

        meta.install(self, {
            _native = shader,
            _filename = filename,
            _defines = defines
        })
    end
end

--- @brief set uniform
--- @param name String
--- @param value
function rt.ComputeShader:send(name, value, ...)
    if self._is_disabled then return end

    rt.assert(value ~= nil, "uniform " .. name .. " is nil")

    local args = { value, ... }
    for i, x in ipairs(args) do
        if meta.is_table(x) and x.get_native ~= nil then
            args[i] = x:get_native()
        end
    end

    if self._native:hasUniform(name) then
        self._native:send(name, table.unpack(args))
    else
        rt.critical("In rt.ComputeShader: shader at `", self._filename, "` does not have uniform `" .. name .. "`")
    end
end

--- @brief set uniform
--- @param name String
--- @param value
function rt.ComputeShader:try_send(name, value, ...)
    if self._is_disabled then return end

    if self._native:hasUniform(name) then
        self:send(name, value, ...)
        return true
    else
        return false
    end
end

--- @brief
function rt.ComputeShader:has_uniform(name)
    if self._is_disabled then return false end
    return self._native:hasUniform(name)
end

--- @brief
function rt.ComputeShader:get_buffer_format(buffer)
    if self._is_disabled then return {} end
    return self._native:getBufferFormat(buffer)
end

--- @brief
function rt.ComputeShader:dispatch(x, y, z)
    if self._is_disabled then return end

    local limits = love.graphics.getSystemLimits()
    love.graphics.dispatchThreadgroups(self._native,
        math.clamp(math.ceil(x or 1), 1, limits.threadgroupsx),
        math.clamp(math.ceil(y or 1), 1, limits.threadgroupsy),
        math.clamp(math.ceil(z or 1), 1, limits.threadgroupsz)
    )
end

--- @brief
function rt.ComputeShader:get_native()
    if self._is_disabled then return nil end
    return self._native
end

--- @brief
function rt.ComputeShader:recompile()
    if self._is_disabled then return end
    local success, shader = pcall(love.graphics.newComputeShader, self._filename, {
        defines = self._defines
    })

    if not success then
        rt.critical("In rt.ComputeShader: Error when evaluating shader at `", self._filename, "`:\n", shader)
    else
        self._native = shader
    end
end