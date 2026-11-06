Upscaler_t = "upscaler"

upscaler_new = function(width, height)
    log_typecheck(width, Number_t, height, Number_t)
    return upscaler_resize(object_new(Upscaler_t, {
        translate_x = 0,
        translate_y = 0,
        scale_x = 1,
        scale_y = 1,

        aabb_x = 0,
        aabb_y = 0,
        aabb_w = 0,
        aabb_h = 0,

        fade_active = false,
        fade_motion = lag_new(0), -- 0: default, 1: fully black
        fade_callback = nil
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

    self.aabb_x = self.translate_x
    self.aabb_y = self.translate_y
    self.aabb_w = texture_w
    self.aabb_h = texture_h

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
    graphics_set_scale(1 / graphics_get_dpi_scale())
    graphics_set_translation(self.translate_x, self.translate_y)
    graphics_draw_texture(self.texture)
    graphics_pop_state()

    local t = lag_get_value(self.fade_motion)
    local w, h = graphics_get_size()
    graphics_set_color(0, 0, 0, t)
    graphics_draw_rectangle(self.aabb_x, self.aabb_y, self.aabb_w, self.aabb_h)
end

upscaler_update = function(self, delta)
    log_typecheck(self, Upscaler_t, delta, Number_t)

    local lag = self.fade_motion
    local value = lag_update(lag, delta)

    if self.fade_callback ~= nil and math_equals(
        lag_get_value(lag),
        1, -- target value
        0.001 -- eps
    ) then
        log_safe_call(self.fade_callback)
        self.fade_callback = nil
        lag_set_target_value(self.fade_motion, 0)
    end
end

upscaler_queue_fade = function(self, on_swap)
    log_typecheck(self, Upscaler_t, on_swap, Function_t)

    if self.fade_callback ~= nil then
        log_safe_call(self.fade_callback)
    end

    lag_set_target_value(self.fade_motion, 1)
    self.fade_callback = on_swap
end