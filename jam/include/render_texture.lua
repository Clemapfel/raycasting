RenderTexture_t = "RenderTexture"

render_texture_new = function(width, height)
    return object_new(RenderTexture_t, {
        native = love.graphics.newCanvas(width, height)
    })
end

render_texture_set_scale_mode = function(self, mode)
    log_typecheck(self, RenderTexture_t, mode, String_t)
    self.native:setFilter(mode, mode)
end

render_texture_set_wrap_mode = function(self, mode)
    log_typecheck(self, RenderTexture_t, mode, String_t)
    self.native:setWrap(mode, mode)
end

render_texture_get_width = function(self)
    log_typecheck(self, RenderTexture_t)
    return self.native:getWidth()
end

render_texture_get_height = function(self)
    log_typecheck(self, RenderTexture_t)
    return self.native:getHeight()
end

render_texture_get_height = function(self)
    log_typecheck(self, RenderTexture_t)
    return self.native:getDimensions()
end

render_texture_draw = function(self, ...)
    log_typecheck(self, RenderTexture_t)
    love.graphics.draw(self.native, ...)
end

render_texture_bind = function(self)
    log_typecheck(self, RenderTexture_t)
    self.before = love.graphics.getCanvas()
    love.graphics.setCanvas(self.native)
end

render_texture_unbind = function(self)
    log_typecheck(self, RenderTexture_t)
    love.graphics.setCanvas(self.before)
end