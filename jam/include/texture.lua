Texture_t = "Texture"

TextureScaleMode = {
    NEAREST = "nearest",
    LINEAR = "linear"
}

texture_new = function(path)
    if DEBUG then
        path = "jam/" .. path
    end

    return object_new(Texture_t, {
        native = love.graphics.newImage(path)
    })
end

texture_set_scale_mode = function(self, mode)
    log_typecheck(self, Texture_t, mode, String_t)
    self.native:setFilter(mode, mode)
end

texture_set_wrap_mode = function(self, mode)
    log_typecheck(self, Texture_t, mode, String_t)
    self.native:setWrap(mode, mode)
end

texture_get_width = function(self)
    log_typecheck(self, Texture_t)
    return self.native:getWidth()
end

texture_get_height = function(self)
    log_typecheck(self, Texture_t)
    return self.native:getHeight()
end

texture_get_height = function(self)
    log_typecheck(self, Texture_t)
    return self.native:getDimensions()
end

texture_draw = function(self, ...)
    log_typecheck(self, Texture_t)
    love.graphics.draw(self.native, ...)
end