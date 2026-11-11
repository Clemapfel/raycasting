Shader_t = "Shader"

shader_new = function(path)
    return shader_init(object_new(Shader_t, {}), path)
end

shader_init = function(self, path)
    log_typecheck(self, Shader_t)

    if DEBUG then
        path = "jam/" .. path
    end

    self.path = path

    local valid, message = love.graphics.validateShader(true, self.path)
    if not valid then
        log_error("In shader_init: validation for GLES failed: ", message)
        return
    end

    local success, shader_or_message = pcall(love.graphics.newShader, self.path)
    if not success then
        log_error("In shader_init: compilation failed:", shader_or_message)
        return
    else
        self.native = shader_or_message
    end
end

shader_bind = function(self)
    log_typecheck(self, Shader_t)
    if self.native == nil then return end

    self.before = love.graphics.getShader()
    love.graphics.setShader(self.native)
end

shader_unbind = function(self)
    log_typecheck(self, Shader_t)
    if self.native == nil then return end

    love.graphics.setShader(self.before)
end

shader_set_uniform = function(self, key, value)
    log_typecheck(self, Shader_t, key, String_t)
    if self.native == nil then return end

    if value == nil then
        log_error("In shader_set_uniform: trying to set uniform `", key, "` to `nil`")
    end

    if not self.native:hasUniform(key) then
        log_warning("In shader_set_uniform: shader at `", self.path, "` does not have uniform `", key, "`")
        return
    end

    if object_typeof(value) == RGBA_t then
        self.native:send(key, { rgba_unpack(value) })
    elseif object_is_table(value) and object.native ~= nil then
        -- texture, meshes, etc.
        self.native:send(key, object.native)
    else
        self.native:send(key, value)
    end
end