Upscaler_t = "upscaler"

upscaler_new = function(width, height)
    log_typecheck(width, Number_t, height, Number_t)
    return upscaler_resize(new(Upscaler_t, {
        translate_x = 0,
        translate_y = 0,
        scale_x = 1,
        scale_y = 1,
    }), width, height)
end

upscaler_resize = function(self, w, h)
    log_typecheck(self, Upscaler_t, w, Number_t, h, Number_t)

    local local_w, log_h = graphics_get_size()
    local fit = math_min(w / local_w, h / log_h)
    local texture_w = math_max(1, math_floor(local_w * fit + 0.5))
    local texture_h = math_max(1, math_floor(log_h * fit + 0.5))

    if self.texture == nil
        or self.texture:getWidth() ~= texture_w
        or self.texture:getHeight() ~= texture_h
    then
        self.texture = love.graphics.newCanvas(texture_w, texture_h)
        self.texture:setFilter("linear", "linear")
    end

    self.scale_x = texture_w / local_w
    self.scale_y = texture_h / log_h
    self.translate_x = math_floor((w - texture_w) / 2)
    self.translate_y = math_floor((h - texture_h) / 2)

    return self
end

upscaler_get_size = function(self)
    log_typecheck(self, Upscaler_t)
    return graphics_get_size()
end

upscaler_bind = function(self)
    log_typecheck(self, Upscaler_t)
    graphics_push_state()
    graphics_reset_state()
    graphics_set_render_texture(self.texture)
    graphics_clear(0, 0, 0, 0)
    graphics_set_scale(self.scale_x, self.scale_y)
end

upscaler_unbind = function(self)
    log_typecheck(self, Upscaler_t)
    graphics_pop_state()
end

upscaler_draw = function(self)
    log_typecheck(self, Upscaler_t)
    graphics_push_state()
    graphics_reset_state()
    graphics_set_scale(1 / love.graphics.getDPIScale())
    graphics_set_translation(self.translate_x, self.translate_y)
    graphics_draw_texture(self.texture)
    graphics_pop_state()
end