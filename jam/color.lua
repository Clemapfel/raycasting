RGBA_t = "RGBA"
LCHA_t = "LCHA"

rgba_new = function(r, g, b, a)
    return rgba_init(object_new(RGBA_t, {}), r, g, b, a)
end

rgba_init = function(self, r, g, b, a)
    if a == nil then a = 1 end
    log_typecheck(self, RGBA_t, r, Number_t, g, Number_t, b, Number_t, a, Number_t)
    self.r = r
    self.g = g
    self.b = b
    self.a = a
    return self
end

rgba_unpack = function(self)
    log_typecheck(self, RGBA_t)
    return self.r, self.g, self.b, self.a
end

rgba_bind = function(self)
    log_typecheck(self, RGBA_t)
    graphics_set_color(rgba_unpack(self))
    return self
end

rgba_darken = function(self, darken)
    log_typecheck(self, RGBA_t, darken, Number_t)
    self.r = self.r * (1 - darken)
    self.g = self.g * (1 - darken)
    self.b = self.b * (1 - darken)
    return self
end

rgba_lighten = function(self, lighten)
    log_typecheck(self, RGBA_t, lighten, Number_t)
    self.r = math_clamp(self.r * (1 + lighten), 0, 1)
    self.g = math_clamp(self.g * (1 + lighten), 0, 1)
    self.b = math_clamp(self.b * (1 + lighten), 0, 1)
    return self
end


lcha_new = function(l, c, h, a)
    return lcha_init(object_new(LCHA_t, {}), l, c, h, a)
end

lcha_init = function(self, l, c, h, a)
    if a == nil then a = 1 end
    log_typecheck(self, LCHA_t, l, Number_t, c, Number_t, h, Number_t, a, Number_t)
    self.l = l
    self.c = c
    self.h = h
    self.a = a
    return self
end

lcha_unpack = function(self)
    log_typecheck(self, LCHA_t)
    return self.l, self.c, self.h, self.a
end

lcha_bind = function(self)
    log_typecheck(self, LCHA_t)
    rgba_bind(lcha_to_rgba(self))
    return self
end

do
    local function linearize(value)
        return (value <= 0.04045) and (value / 12.92) or (((value + 0.055) / 1.055) ^ 2.4)
    end

    rgba_to_lcha = function(self_or_r, g, b, a)
        local self

        if object_is_number(self_or_r) then
            if a == nil then a = 1 end
            log_typecheck(self_or_r, Number_t, g, Number_t, b, Number_t, a, Number_t)
            self = rgba_new(self_or_r, g, b, a)
        else
            self = self_or_r
            log_typecheck(self, RGBA_t)
        end

        local r, g, b = linearize(self.r), linearize(self.g), linearize(self.b)

        local x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
        local y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
        local z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041

        x = x / 0.95047
        y = y / 1.00000
        z = z / 1.08883

        local function f(t)
            return (t > 0.008856) and (t ^ (1 / 3)) or ((7.787 * t) + (16 / 116))
        end

        x, y, z = f(x), f(y), f(z)

        local lightness = (116 * y) - 16
        local lab_a = 500 * (x - y)
        local lab_b = 200 * (y - z)

        local chroma = math_sqrt(lab_a * lab_a + lab_b * lab_b)
        local hue = math_angle(lab_a, lab_b)
        if hue < 0 then
            hue = hue + math_tau
        end

        return lcha_new(lightness / 100, chroma / 100, hue / math_tau, self.a)
    end
end

do
    local function gamma(value)
        value = (value > 0.0031308) and (1.055 * value ^ (1 / 2.4) - 0.055) or (12.92 * value)
        return (value < 0) and 0 or ((value > 1) and 1 or value)
    end

    lcha_to_rgba = function(self_or_l, c, h, a)
        if object_is_number(self_or_l) then
            if a == nil then a = 1 end
            log_typecheck(self_or_l, Number_t, c, Number_t, h, Number_t, a, Number_t)
            self = lcha_new(self_or_l, c, h, a)
        else
            self = self_or_l
            log_typecheck(self, LCHA_t)
        end

        local lightness = self.l * 100
        local lab_a = math_cos(self.h * math_tau) * self.c * 100
        local lab_b = math_sin(self.h * math_tau) * self.c * 100

        local y = (lightness + 16) / 116
        local x = lab_a / 500 + y
        local z = y - lab_b / 200

        local function f_inv(t)
            local t_cubed = t * t * t
            return (t_cubed > 0.008856) and t_cubed or ((t - 16 / 116) / 7.787)
        end

        x = 0.95047 * f_inv(x)
        y = 1.00000 * f_inv(y)
        z = 1.08883 * f_inv(z)

        local r = x * 3.2406 - y * 1.5372 - z * 0.4986
        local g = -x * 0.9689 + y * 1.8758 + z * 0.0415
        local b = x * 0.0557 - y * 0.2040 + z * 1.0570

        return rgba_new(gamma(r), gamma(g), gamma(b), self.a)
    end
end