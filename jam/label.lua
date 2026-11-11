Label_t = "Label"

local _settings_font_size_default = 30
local _settings_font_path_regular = "jam/assets/baloo_2_regular.ttf"
local _settings_font_path_bold = "jam/assets/baloo_2_bold.ttf"
local _settings_font_path_mono = "jam/assets/dejavu_sans_mono.ttf"
local _settings_font_size_to_outline_width = 2

local _settings_rainbow_width = 120.0
local _settings_rainbow_speed = 0.3
local _settings_rainbow_lightness = 0.8
local _settings_rainbow_chroma = 1.0
local _settings_rainbow_lut_size = 256

local _settings_wave_period = 10.0
local _settings_wave_offset = 6.0
local _settings_wave_speed = 4.0


TextStyle = {
    REGULAR = "REGULAR",
    BOLD = "BOLD",
    MONO = "MONO"
}

local _text_style_to_path = {
    [TextStyle.REGULAR] = _settings_font_path_regular,
    [TextStyle.BOLD] = _settings_font_path_bold,
    [TextStyle.MONO] = _settings_font_path_mono
}

local _style_to_font_cache = {}
local _get_font = function(size, style)
    local cache = _style_to_font_cache[style]
    if cache == nil then
        cache = {}
        _style_to_font_cache[style] = cache
    end

    if cache[size] ~= nil then
        return cache[size]
    else
        local success, font_or_error = pcall(love.graphics.newFont, _text_style_to_path[style], size)
        if not success then
            font_or_error = love.graphics.newFont(size)
            log_critical("In label_init: unable to load font at `", _text_style_to_path[style], "`: ", font_or_error)
        end

        cache[size] = font_or_error
        return font_or_error
    end
end

local _get_rainbow_color
do
    local _cache = {}
    for i = 0, _settings_rainbow_lut_size - 1 do
        _cache[i + 1] = { rgba_unpack(lcha_to_rgba(lcha_new(
            _settings_rainbow_lightness,
            _settings_rainbow_chroma,
            i / _settings_rainbow_lut_size
        ))) }
    end

    _get_rainbow_color = function(hue)
        local i = math.floor(hue * _settings_rainbow_lut_size) % _settings_rainbow_lut_size
        return _cache[i + 1]
    end
end

JustifyMode = {
    CENTER = "CENTER",
    LEFT = "LEFT",
    RIGHT = "RIGHT"
}

local _update_layout = function(self)
    local text = self.text
    text:clear()

    if not (self.is_rainbow or self.is_wave) then
        text:add(self.raw, 0, 0)
        return
    end

    local elapsed = self.elapsed
    for _, letter in ipairs(self.letters) do
        local y = letter.y
        if self.is_wave then
            local t = elapsed * _settings_wave_speed + letter.index
            y = y + math.sin((t * 2 * math.pi) / _settings_wave_period) * _settings_wave_offset
        end

        local color = letter.color
        if self.is_rainbow then
            local hue = (letter.x / _settings_rainbow_width - elapsed * _settings_rainbow_speed) % 1
            local rgb = _get_rainbow_color(hue)
            color[1], color[2], color[3] = rgb[1], rgb[2], rgb[3]
        else
            color[1], color[2], color[3] = 1, 1, 1
        end

        text:add(letter.colored_text, letter.x, y)
    end
end

label_new = function(text, font_size, style, color, justify_mode, is_outlined, is_rainbow, is_wave)
    return label_init(object_new(Label_t, {
        position_x = 0,
        position_y = 0,
        raw = text,
    }), text, font_size, style, color, justify_mode, is_outlined, is_rainbow, is_wave)
end

local _rebuild = function(self, text)
    local font = self.font
    local line_height = font:getHeight() * font:getLineHeight()

    self.raw = text
    self.letters = {}
    self.width = 0
    self.height = font:getHeight()

    local letter_index = 0
    local line = 0
    local line_text = ""

    for i = 1, string.len(text) do
        local char = string.sub(text, i, i)
        if char == "\n" then
            self.width = math.max(self.width, font:getWidth(line_text))
            line = line + 1
            line_text = ""
            self.height = line_height * line + font:getHeight()
        else
            local x = font:getWidth(line_text .. char) - font:getWidth(char)
            line_text = line_text .. char

            if string.match(char, "%s") == nil then
                local letter_color = {1, 1, 1, 1}
                table_push(self.letters, {
                    index = letter_index,
                    x = x,
                    y = line * line_height,
                    color = letter_color,
                    colored_text = {letter_color, char}
                })
            end
            letter_index = letter_index + 1
        end
    end
    self.width = math.max(self.width, font:getWidth(line_text))

    _update_layout(self)
end

label_init = function(self, text, font_size, style, color, justify_mode, is_outlined, is_rainbow, is_wave)
    if font_size == nil then font_size = _settings_font_size_default end
    if style == nil then style = TextStyle.REGULAR end
    if color == nil then color = palette_white end
    if justify_mode == nil then justify_mode = JustifyMode.LEFT end
    if is_outlined == nil then is_outlined = false end
    if is_rainbow == nil then is_rainbow = false end
    if is_wave == nil then is_wave = false end

    log_typecheck(self, Label_t, text, String_t, font_size, Number_t, style, String_t, color, RGBA_t, justify_mode, String_t, is_outlined, Boolean_t, is_rainbow, Boolean_t, is_wave, Boolean_t)
    log_assert(JustifyMode[justify_mode] ~= nil, "In label_init: unknown justify mode `", justify_mode, "`")

    self.raw = text
    self.font_size = font_size
    self.style = style
    self.font = _get_font(font_size, style)
    self.text = love.graphics.newText(self.font)
    self.color = color
    self.justify_mode = justify_mode
    self.is_outlined = is_outlined
    self.is_rainbow = is_rainbow
    self.is_wave = is_wave
    self.elapsed = 0
    self.bounds = aabb_new(0, 0, 0, 0)

    _rebuild(self, text)
    return self
end

label_set_text = function(self, text)
    log_typecheck(self, Label_t, text, String_t)
    if text == self.raw then return self end

    _rebuild(self, text)
    return self
end

label_get_text = function(self)
    log_typecheck(self, Label_t)
    return self.raw
end

label_update = function(self, delta)
    log_typecheck(self, Label_t, delta, Number_t)
    if not (self.is_rainbow or self.is_wave) then return end

    self.elapsed = self.elapsed + delta
    _update_layout(self)
end

label_reformat = function(self, aabb_or_x, y, width, height)
    if object_is_number(aabb_or_x) then
        if width == nil then width = self.bounds.width end
        if height == nil then height = self.bounds.height end
        log_typecheck(self, Label_t, aabb_or_x, Number_t, y, Number_t, width, Number_t, height, Number_t)
        self.bounds.x = aabb_or_x
        self.bounds.y = y
        self.bounds.width = width
        self.bounds.height = height
    else
        log_typecheck(self, Label_t, aabb_or_x, AABB_t)
        self.bounds = aabb_or_x
    end
end

label_get_position = function(self)
    log_typecheck(self, Label_t)
    log_assert(self.bounds ~= nil, "In label_get_position: label has no bounds, call label_reformat first")
    return self.bounds.x, self.bounds.y
end

label_get_size = function(self)
    log_typecheck(self, Label_t)
    return self.width, self.height
end

label_get_width = function(self)
    log_typecheck(self, Label_t)
    return self.width
end

label_get_height = function(self)
    log_typecheck(self, Label_t)
    return self.height
end

label_set_color = function(self, color)
    log_typecheck(self, Label_t, color, RGBA_t)
    self.color = color
    return self
end

label_get_color = function(self)
    log_typecheck(self, Label_t)
    return self.color
end

label_set_is_outlined = function(self, is_outlined)
    if is_outlined == nil then is_outlined = true end
    log_typecheck(self, Label_t, is_outlined, Boolean_t)
    self.is_outlined = is_outlined
    return self
end

label_get_is_outlined = function(self)
    log_typecheck(self, Label_t)
    return self.is_outlined
end

label_set_is_rainbow = function(self, is_rainbow)
    if is_rainbow == nil then is_rainbow = true end
    log_typecheck(self, Label_t, is_rainbow, Boolean_t)
    self.is_rainbow = is_rainbow
    _update_layout(self)
    return self
end

label_get_is_rainbow = function(self)
    log_typecheck(self, Label_t)
    return self.is_rainbow
end

label_set_is_wave = function(self, is_wave)
    if is_wave == nil then is_wave = true end
    log_typecheck(self, Label_t, is_wave, Boolean_t)
    self.is_wave = is_wave
    _update_layout(self)
    return self
end

label_get_is_wave = function(self)
    log_typecheck(self, Label_t)
    return self.is_wave
end

label_set_justify_mode = function(self, justify_mode)
    log_typecheck(self, Label_t, justify_mode, String_t)
    log_assert(JustifyMode[justify_mode] ~= nil, "In label_set_justify_mode: unknown justify mode `", justify_mode, "`")

    self.justify_mode = justify_mode
    return self
end

label_get_justify_mode = function(self)
    log_typecheck(self, Label_t)

    return self.justify_mode
end

label_draw = function(self)
    log_typecheck(self, Label_t)

    graphics_push_state()

    local bounds = self.bounds
    local width, height = self.width, self.height

    local x
    if self.justify_mode == JustifyMode.CENTER then
        x = bounds.x + 0.5 * bounds.width - 0.5 * width
    elseif self.justify_mode == JustifyMode.RIGHT then
        x = bounds.x + bounds.width - width
    elseif self.justify_mode == JustifyMode.LEFT then
        x = bounds.x
    end

    local y = bounds.y + 0.5 * (bounds.height - height)

    local r, g, b, a = love.graphics.getColor()

    if self.is_outlined then
        local offset = _settings_font_size_to_outline_width
        graphics_set_color(r * palette_black.r, g * palette_black.g, b * palette_black.b, a * palette_black.a)
        for x_offset = -offset, offset, offset do
            for y_offset = -offset, offset, offset do
                love.graphics.draw(self.text,
                    math_round(x + x_offset),
                    math_round(y + y_offset)
                )
            end
        end
    end

    if self.is_rainbow then
        graphics_set_color(r, g, b, a * self.color.a)
    else
        local self_r, self_g, self_b, self_a = rgba_unpack(self.color)
        graphics_set_color(r * self_r, g * self_g, b * self_b, a * self_a)
    end
    love.graphics.draw(self.text, math_round(x), math_round(y))

    graphics_pop_state()
end