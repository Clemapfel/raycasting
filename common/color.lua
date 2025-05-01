--- @class RGBA
rt.RGBA = meta.class("RGBA")

--- @brief
function rt.RGBA:instantiate(r, g, b, a)
    meta.install(self, {
        r = r or 1,
        g = g or 1,
        b = b or 1,
        a = a or 1
    })
end

--- @brief
function rt.RGBA:bind()
    love.graphics.setColor(self.r, self.g, self.b, self.a)
end

--- @brief
function rt.RGBA:unpack()
    return self.r, self.g, self.b, self.a
end

--- @class HSVA
rt.HSVA = meta.class("HSVA")

--- @brief
function rt.HSVA:instantiate(h, s, v, a)
    meta.install(self, {
        h = h or 0,
        s = s or 0,
        v = v or 1,
        a = a or 1
    })
end

--- @brief
function rt.HSVA:unpack()
    return self.h, self.s, self.v, self.a
end

--- @brie
function rt.HSVA:bind()
    local r, g, b, a = rt.hsva_to_rgba(self.h, self.s, self.v, self.a)
    love.graphics.setColor(r, g, b, a)
end

--- @class LCHA
rt.LCHA = meta.class("LCHA")

--- @brief
function rt.LCHA:instantiate(l, c, h, a)
    meta.install(self, {
        l = l or 1,
        c = c or 1,
        h = h or 0,
        a = a or 1
    })
end

--- @brief
function rt.LCHA:unpack()
    return self.l, self.c, self.h, self.a
end

--- @brie
function rt.LCHA:bind()
    local r, g, b, a = rt.lcha_to_rgba(self.l, self.c, self.h, self.a)
    love.graphics.setColor(r, g, b, a)
end

--- @brief
function rt.color_unpack(color)
    if meta.typeof(color) == "RGBA" then
        return color.r, color.g, color.b, color.a
    elseif meta.typeof(color) == "HSVA" then
        return color.h, color.s, color.v. color.a
    else
        rt.error("In rt.color_unpack: unknown color format `" .. meta.typeof(color) .. "`")
    end
end

--- @brief
function rt.rgba_to_hsva(r, g, b, a)
    -- cf. https://github.com/Clemapfel/mousetrap/blob/main/src/color.cpp#L112
    local h, s, v

    local min = 0

    if r < g then min = r else min = g end
    if min < b then min = min else min = b end

    local max = 0

    if r > g then max = r else max = g end
    if max > b then max = max else max = b end

    local delta = max - min

    if delta == 0 then
        h = 0
    elseif max == r then
        h = 60 * (math.fmod(((g - b) / delta), 6))
    elseif max == g then
        h = 60 * (((b - r) / delta) + 2)
    elseif max == b then
        h = 60 * (((r - g) / delta) + 4)
    end

    if (max == 0) then
        s = 1
    else
        s = delta / max
    end

    v = max

    if (h < 0) then
        h = h + 360
    end

    return h / 360, s, v, a
end

--- @brief
function rt.hsva_to_rgba(h, s, v, a)
    -- cf. https://github.com/Clemapfel/mousetrap/blob/main/src/color.cpp#L151
    h = h * 360

    local c = v * s
    local h_2 = h / 60.0
    local x = c * (1 - math.abs(math.fmod(h_2, 2) - 1))

    local r, g, b

    if (0 <= h_2 and h_2 < 1) then
        r, g, b = c, x, 0
    elseif (1 <= h_2 and h_2 < 2) then
        r, g, b  = x, c, 0
    elseif (2 <= h_2 and h_2 < 3) then
        r, g, b  = 0, c, x
    elseif (3 <= h_2 and h_2 < 4) then
        r, g, b  = 0, x, c
    elseif (4 <= h_2 and h_2 < 5) then
        r, g, b  = x, 0, c
    else
        r, g, b  = c, 0, x
    end

    local m = v - c

    r = r + m
    g = g + m
    b = b + m

    return r, g, b, a
end

--- @brief
function rt.lcha_to_rgba(l, c, h, alpha)
    local L, C, H = l, c, h

    L = L * 100
    C = C * 100
    H = H * 360

    local a = math.cos(math.rad(H)) * C
    local b = math.sin(math.rad(H)) * C

    local Y = (L + 16.0) / 116.0
    local X = a / 500.0 + Y
    local Z = Y - b / 200.0

    if X * X * X > 0.008856 then
        X = 0.95047 * X * X * X
    else
        X = 0.95047 * (X - 16.0 / 116.0) / 7.787
    end

    if Y * Y * Y > 0.008856 then
        Y = 1.00000 * Y * Y * Y
    else
        Y = 1.00000 * (Y - 16.0 / 116.0) / 7.787
    end

    if Z * Z * Z > 0.008856 then
        Z = 1.08883 * Z * Z * Z
    else
        Z = 1.08883 * (Z - 16.0 / 116.0) / 7.787
    end

    local R = X *  3.2406 + Y * -1.5372 + Z * -0.4986
    local G = X * -0.9689 + Y *  1.8758 + Z *  0.0415
    local B = X *  0.0557 + Y * -0.2040 + Z *  1.0570

    if R > 0.0031308 then
        R = 1.055 * R^(1.0 / 2.4) - 0.055
    else
        R = 12.92 * R
    end

    if G > 0.0031308 then
        G = 1.055 * G^(1.0 / 2.4) - 0.055
    else
        G = 12.92 * G
    end

    if B > 0.0031308 then
        B = 1.055 * B^(1.0 / 2.4) - 0.055
    else
        B = 12.92 * B
    end

    return
        math.clamp(R, 0.0, 1.0),
        math.clamp(G, 0.0, 1.0),
        math.clamp(B, 0.0, 1.0),
        alpha
end

--- @brief
function rt.rgba_to_lcha(r, g, b, a)
    r = (r <= 0.04045) and (r / 12.92) or (((r + 0.055) / 1.055) ^ 2.4)
    g = (g <= 0.04045) and (g / 12.92) or (((g + 0.055) / 1.055) ^ 2.4)
    b = (b <= 0.04045) and (b / 12.92) or (((b + 0.055) / 1.055) ^ 2.4)

    local x = r * 0.4124564 + g * 0.3575761 + b * 0.1804375
    local y = r * 0.2126729 + g * 0.7151522 + b * 0.0721750
    local z = r * 0.0193339 + g * 0.1191920 + b * 0.9503041

    local x_ref, y_ref, z_ref = 0.95047, 1.00000, 1.08883

    x = x / x_ref
    y = y / y_ref
    z = z / z_ref

    x = (x > 0.008856) and (x ^ (1/3)) or ((7.787 * x) + (16 / 116))
    y = (y > 0.008856) and (y ^ (1/3)) or ((7.787 * y) + (16 / 116))
    z = (z > 0.008856) and (z ^ (1/3)) or ((7.787 * z) + (16 / 116))

    local l = (116 * y) - 16
    local a = 500 * (x - y)
    local b = 200 * (y - z)

    local c = math.sqrt(a ^ 2 + b ^ 2)
    local h = math.atan2(b, a)
    h = math.deg(h)
    if h < 0 then
        h = h + 360
    end

    return l / 100, c / 100, h / 360, a
end

--- @brief
function rt.html_code_to_color(code)
    function hex_char_to_int(c)
        c = string.upper(c)
        if c == '0' then return 0
        elseif c == '1' then return 1
        elseif c == '2' then return 2
        elseif c == '3' then return 3
        elseif c == '4' then return 4
        elseif c == '5' then return 5
        elseif c == '6' then return 6
        elseif c == '7' then return 7
        elseif c == '8' then return 8
        elseif c == '9' then return 9
        elseif c == 'A' then return 10
        elseif c == 'B' then return 11
        elseif c == 'C' then return 12
        elseif c == 'D' then return 13
        elseif c == 'E' then return 14
        elseif c == 'F' then return 15
        else return -1 end
    end

    function hex_component_to_int(left, right)

        return left * 16 + right
    end

    local error_reason = ""

    local as_hex = {}
    if string.sub(code, 1, 1) ~= '#' then
        code = "#" .. code
    end
    for i = 2, #code do
        local to_push = hex_char_to_int(string.sub(code, i, i))
        if to_push == -1 then
            error_reason = "character `" .. string.sub(code, i, i) .. "` is not a valid hexadecimal digit"
            goto error
        end
        table.insert(as_hex, to_push)
    end

    if #as_hex == 6 then
        return rt.RGBA(
            hex_component_to_int(as_hex[1], as_hex[2]) / 255.0,
            hex_component_to_int(as_hex[3], as_hex[4]) / 255.0,
            hex_component_to_int(as_hex[5], as_hex[6]) / 255.0,
            1
        )
    elseif #as_hex == 8 then
        return rt.RGBA(
            hex_component_to_int(as_hex[1], as_hex[2]) / 255.0,
            hex_component_to_int(as_hex[3], as_hex[4]) / 255.0,
            hex_component_to_int(as_hex[5], as_hex[6]) / 255.0,
            hex_component_to_int(as_hex[7], as_hex[8]) / 255.0
        )
    else
        error_reason = "more than 6 or 8 digits specified"
        goto error
    end

    ::error::
    rt.error("In rt.html_code_to_rgba: `" .. code .. "` is not a valid hexadecimal color identifier. Reason: " .. error_reason)
end

--- @brief
function rt.color_to_html_code(rgba, use_alpha)
    if use_alpha == nil then
        use_alpha = false
    end

    rgba.r = math.clamp(rgba.r, 0, 1)
    rgba.g = math.clamp(rgba.g, 0, 1)
    rgba.b = math.clamp(rgba.b, 0, 1)
    rgba.a = math.clamp(rgba.a, 0, 1)

    function to_hex(x)
        local out = string.upper(string.format("%x", x))
        if #out == 1 then out = "0" .. out end

        return out
    end

    local r = to_hex(math.round(rgba.r * 255))
    local g = to_hex(math.round(rgba.g * 255))
    local b = to_hex(math.round(rgba.b * 255))
    local a = to_hex(math.round(rgba.a * 255))

    local out = "#" .. r .. g .. b
    if use_alpha then
        out = out .. a
    end
    return out
end

