require "common.widget"
require "common.texture"
require "common.palette"
require "common.font"
require "common.render_texture"

rt.settings.label = {
    outline_offset_padding = 8,
    scroll_speed = 40, -- beats per second
}

--- @class rt.TextEffect
rt.TextEffect = meta.enum("TextEffect", {
    NONE = "NONE",
    SHAKE = "SHAKE",
    WAVE = "WAVE",
    RAINBOW = "RAINBOW"
})

---@class rt.JustifyMode
rt.JustifyMode = meta.enum("JustifyMode", {
    LEFT = "LEFT",
    RIGHT = "RIGHT",
    CENTER = "CENTER"
})

--- @class rt.Label
rt.Label = meta.class("Label", rt.Widget)

function rt.Label:instantiate(text, font_size, font)
    if text == nil then text = "" end
    if font == nil then font = rt.settings.font.default end
    if font_size == nil then font_size = rt.FontSize.REGULAR end

    meta.assert_typeof(text, "String", 1)
    meta.assert_typeof(font, rt.Font, 2)
    meta.assert_enum_value(font_size, rt.FontSize, 3)

    meta.install(self, {
        _raw = text,
        _font = font,
        _font_size = font_size,
        _justify_mode = rt.JustifyMode.LEFT,

        _n_visible_characters = -1,
        _elapsed = 0,
        _glyphs = {},
        _n_glyphs = 0,
        _n_characters = 0,
        _n_lines = 0,

        _glyphs_only = meta.make_weak({}),
        _non_outlined_glyphs = meta.make_weak({}),
        _outlined_glyphs = meta.make_weak({}),

        _use_outline = false,
        _use_animation = false,

        _justify_left_offset = 0,
        _justify_center_offset = 0,
        _justify_right_offset = 0,

        _texture_offset_x = 0,
        _texture_offset_y = 0,
        _texture_width = 1,
        _texture_heigth = 1,
        _texture = nil, -- rt.RenderTexture
        _opacity = 1,

        _width = 0,
        _height = 0,
        _first_wrap = true,
        _last_window_height = love.graphics.getHeight(),

        _total_beats = 0,
    })
end

local _draw_outline_shader = love.graphics.newShader("common/label.glsl", { defines = { MODE = 0 }})
local _draw_text_shader = love.graphics.newShader("common/label.glsl", { defines = { MODE = 1 }})
local _texture_format = rt.TextureFormat.RGBA16
local _padding = rt.settings.label.outline_offset_padding

--- @brief
function rt.Label:_glyph_new(
    text, font, style, is_mono,
    color_r, color_g, color_b,
    outline_color_r, outline_color_g, outline_color_b,
    is_underlined,
    is_strikethrough,
    is_outlined,
    is_effect_shake,
    is_effect_wave,
    is_effect_rainbow,
    is_effect_noise
)
    local font_native = font:get_native(self._font_size, style, false)
    local glyph, outline_glyph = love.graphics.newTextBatch(font_native, text), nil

    if is_outlined then
        outline_glyph = love.graphics.newTextBatch(font:get_native(self._font_size, style, true), text)
    end

    local out = {
        text = text, -- necessary for beat weights
        glyph = glyph,
        outline_glyph = outline_glyph,
        font = font_native,
        is_mono = is_mono,
        is_underlined = is_underlined,
        is_strikethrough = is_strikethrough,
        is_outlined = is_outlined,
        is_effect_shake = is_effect_shake,
        is_effect_rainbow = is_effect_rainbow,
        is_effect_wave = is_effect_wave,
        is_effect_noise = is_effect_noise,
        color = {color_r, color_g, color_b, 1},
        outline_color = {outline_color_r, outline_color_g, outline_color_b, 1},
        n_visible_characters = utf8.len(text),
        n_characters = utf8.len(text),
        justify_left_offset = 0,
        justify_center_offset = 0,
        justify_right_offset = 0,
        row_index = 1,
        x = 0,
        y = 0,
        width = 0,
        height = 0,
        strikethrough_ax = nil,
        strikethrough_ay = nil,
        strikethrough_bx = nil,
        strikethrough_by = nil,
        underline_ax = nil,
        underline_ay = nil,
        underline_bx = nil,
        underline_by = nil
    }

    out.width = out.glyph:getWidth()
    out.height = out.glyph:getHeight()

    return out
end

--- @override
function rt.Label:draw(x, y)
    if self._n_glyphs == 0 or self._is_visible ~= true or self._texture == nil then return end
    if x == nil then x = 0 end
    if y == nil then y = 0 end

    local justify_offset = self._justify_left_offset
    if self._justify_mode == rt.JustifyMode.CENTER then
        justify_offset = self._justify_center_offset
    elseif self._justify_mode == rt.JustifyMode.RIGHT then
        justify_offset = self._justify_right_offset
    end

    love.graphics.push()

    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(self._opacity, self._opacity, self._opacity, self._opacity)

    love.graphics.draw(self._texture._native,
        math.floor(self._bounds.x + justify_offset + self._texture_offset_x + x),
        math.floor(self._bounds.y + self._texture_offset_y + y)
    )

    love.graphics.pop()
    love.graphics.setBlendMode("alpha")
end

--- @brief
function rt.Label:get_snapshot()
    return self._texture
end

--- @brief
function rt.Label:set_font_size(font_size)
    meta.assert_enum_value(font_size, rt.FontSize)
    self._font_size = font_size
    if self:get_is_realized() then
        self:reformat()
    end
end

--- @override
function rt.Label:realize()
    if self:already_realized() then return end
    self:_parse()
end

--- @brief
function rt.Label:_check_for_rescale()
    local current_window_height = love.graphics.getHeight()
    if self._last_window_height ~= current_window_height then
        self._last_window_height = current_window_height
        self:_parse()
        self:_apply_wrapping()
        self:_update_texture()
        self:_update_n_visible_characters()
    end
end

--- @override
function rt.Label:size_allocate(x, y, width, height)
    self:_check_for_rescale()
    x = math.floor(x)
    y = math.floor(y)
    self:_apply_wrapping(width)
    self:_update_texture()
    self:_update_n_visible_characters()
    self._first_wrap = false
end

--- @override
function rt.Label:measure()
    if self._is_realized == false then self:realize() end
    self:_check_for_rescale()
    return self._width, self._height * self._font:get_line_spacing()
end

--- @override
function rt.Label:update(delta)
    self._elapsed = self._elapsed + delta

    if self._use_animation then
        self:_update_texture()
    end
end

--- @brief
function rt.Label:set_justify_mode(mode)
    self._justify_mode = mode
end

--- @brief
function rt.Label:set_text(text)
    if self._raw == text then return end

    self._raw = text
    if self._is_realized then
        self:_parse()
        self._n_visible_characters = self._n_characters
        self:_apply_wrapping(self._bounds.width)
        self:_update_texture()
        self:_update_n_visible_characters()
    end
end

--- @brief
function rt.Label:get_text()
    return self._raw
end

--- @brief
function rt.Label:set_n_visible_characters(n)
    self._n_visible_characters = math.min(n, self._n_characters)
    self:_update_n_visible_characters()
    self:_update_texture()
end

--- @brief
function rt.Label:get_n_visible_characters()
    return self._n_visible_characters
end

--- @brief
function rt.Label:get_n_characters()
    return self._n_characters
end

--- @brief
function rt.Label:get_n_lines()
    return self._n_lines
end

--- @brief
function rt.Label:set_opacity(alpha)
    meta.assert(alpha, "Number")
    self._opacity = alpha
end

--- @brief
function rt.Label:get_line_height()
    return self._font:get_native(rt.FontStyle.BOLD_ITALIC):getHeight()
end

local _make_set = function(...)
    local n_args = _G.select("#", ...)
    local out = {}
    for i = 1, n_args do
        local arg = _G.select(i, ...)
        out[arg] = true
    end
    return out
end

local _syntax = {
    SPACE = " ",
    NEWLINE = "\n",
    TAB = "    ",
    ESCAPE_CHARACTER = "\\",
    BEAT = "|", -- pause when text scrolling
    BEAT_WEIGHTS = { -- factor, takes n times longer to scroll than a regular character
        ["|"] = 10,
        ["."] = 10,
        [","] = 4,
        ["!"] = 10,
        ["?"] = 10
    },

    -- regex patterns to match tags
    BOLD_TAG_START = _make_set("<b>", "<bold>"),
    BOLD_TAG_END = _make_set("</b>", "</bold>"),

    ITALIC_TAG_START = _make_set("<i>", "<italic>"),
    ITALIC_TAG_END = _make_set("</i>", "</italic>"),

    UNDERLINED_TAG_START = _make_set("<u>", "<underlined>"),
    UNDERLINED_TAG_END = _make_set("</u>", "</underlined>"),

    STRIKETHROUGH_TAG_START = _make_set("<s>", "<strikethrough>"),
    STRIKETHROUGH_TAG_END = _make_set("</s>", "</strikethrough>"),

    COLOR_TAG_START = _make_set("<col=(.*)>", "<color=(.*)>"),
    COLOR_TAG_END = _make_set("</col>", "</color>"),

    OUTLINE_COLOR_TAG_START = _make_set("<ocol=(.*)>", "<outline_color=(.*)>"),
    OUTLINE_COLOR_TAG_END = _make_set("</ocol>", "</outline_color>"),

    OUTLINE_TAG_START = _make_set("<o>", "<outline>"),
    OUTLINE_TAG_END = _make_set("</o>", "</outline>"),

    BACKGROUND_TAG_START = _make_set("<bg=(.*)>", "<background=(.*)>"),
    BACKGROUND_TAG_END = _make_set("</bg>", "</background>"),

    EFFECT_SHAKE_TAG_START = _make_set("<shake>", "<fx_shake>"),
    EFFECT_SHAKE_TAG_END = _make_set("</shake>", "</fx_shake>"),
    EFFECT_WAVE_TAG_START = _make_set("<wave>", "<fx_wave>"),
    EFFECT_WAVE_TAG_END = _make_set("</wave>", "</fx_wave>"),
    EFFECT_RAINBOW_TAG_START = _make_set("<rainbow>", "<fx_rainbow>"),
    EFFECT_RAINBOW_TAG_END = _make_set("</rainbow>", "</fx_rainbow>"),
    EFFECT_NOISE_TAG_START = _make_set("<noise>", "<fx_noise>"),
    EFFECT_NOISE_TAG_END = _make_set("</noise>", "</fx_noise>"),

    MONOSPACE_TAG_START = _make_set("<tt>", "<mono>"),
    MONOSPACE_TAG_END = _make_set("</tt>", "</mono>")
}

local _sequence_to_settings_key = {}
for set_settings_key in range(
    {_syntax.BOLD_TAG_START, "is_bold"},
    {_syntax.BOLD_TAG_END, "is_bold"},

    {_syntax.ITALIC_TAG_START, "is_italic"},
    {_syntax.ITALIC_TAG_END, "is_italic"},

    {_syntax.UNDERLINED_TAG_START, "is_underlined"},
    {_syntax.UNDERLINED_TAG_END, "is_underlined"},

    {_syntax.STRIKETHROUGH_TAG_START, "is_strikethrough"},
    {_syntax.STRIKETHROUGH_TAG_END, "is_strikethrough"},

--{_syntax.COLOR_TAG_START, "color_active"}, sic
--{_syntax.COLOR_TAG_END, "color_active"}, sic

--{_syntax.OUTLINE_COLOR_TAG_START, "outline_color_active"}, sic
--{_syntax.OUTLINE_COLOR_TAG_END, "outline_color_active"}, sic

    {_syntax.OUTLINE_TAG_START, "is_outlined"},
    {_syntax.OUTLINE_TAG_END, "is_outlined"},

    {_syntax.EFFECT_SHAKE_TAG_START, "is_effect_shake"},
    {_syntax.EFFECT_SHAKE_TAG_END, "is_effect_shake"},
    {_syntax.EFFECT_WAVE_TAG_START, "is_effect_wave"},
    {_syntax.EFFECT_WAVE_TAG_END, "is_effect_wave"},
    {_syntax.EFFECT_RAINBOW_TAG_START, "is_effect_rainbow"},
    {_syntax.EFFECT_RAINBOW_TAG_END, "is_effect_rainbow"},
    {_syntax.EFFECT_NOISE_TAG_START, "is_effect_noise"},
    {_syntax.EFFECT_NOISE_TAG_END, "is_effect_noise"},

    {_syntax.MONOSPACE_TAG_START, "is_mono"},
    {_syntax.MONOSPACE_TAG_END, "is_mono"}
) do
    local set, settings_key = table.unpack(set_settings_key)
    for x in keys(set) do
        _sequence_to_settings_key[x] = settings_key
    end
end

local _sub = utf8.sub
local _insert = table.insert
local _concat = table.concat
local _find = string.find -- safe as non-utf8 because only used on control sequences
local _max = math.max
local _min = math.min
local _floor = math.floor
local _ceil = math.ceil
local _rt_palette = rt.Palette
local _rt_color_unpack = rt.color_unpack

--- @brief
function rt.Label:_measure_glyph(glyph, is_mono)
    if is_mono == nil then is_mono = false end

    local font
    if not is_mono then
        font = self._font:get_native(self._font_size, rt.FontStyle.BOLD_ITALIC)
    else
        font = self._font:get_native(self._font_size, rt.FontStyle.MONO_BOLD_ITALIC)
    end

    return font:getWidth(glyph)
end

local _font_style_to_mono_font_style = {
    [rt.FontStyle.REGULAR] = rt.FontStyle.MONO_REGULAR,
    [rt.FontStyle.ITALIC] = rt.FontStyle.MONO_ITALIC,
    [rt.FontStyle.BOLD] = rt.FontStyle.MONO_BOLD,
    [rt.FontStyle.BOLD_ITALIC] = rt.FontStyle.MONO_BOLD_ITALIC,
}

--- @brief [internal]
function rt.Label:_parse()
    self._glyphs = {}
    self._glyphs_only = meta.make_weak({})
    self._non_outlined_glyphs = meta.make_weak({})
    self._outlined_glyphs = meta.make_weak({})

    self._n_glyphs = 0
    self._n_characters = 0
    self._use_outline = false
    self._use_animation = false

    self._total_beats = 0
    local beat_weights = _syntax.BEAT_WEIGHTS

    local glyphs = self._glyphs
    local glyph_indices = self._glyph_indices

    local default_color = "FOREGROUND"
    local default_outline_color = "BLACK"

    local settings = {
        is_bold = false,
        is_italic = false,
        is_bold = false,
        is_italic = false,
        is_outlined = false,
        is_underlined = false,
        is_strikethrough = false,

        color = default_color,
        color_active = false,

        outline_color = default_outline_color,
        outline_color_active = false,

        is_mono = false,

        is_effect_noise = false,
        is_effect_rainbow = false,
        is_effect_shake = false,
        is_effect_wave = false
    }

    local at = function(i)
        return _sub(self._raw, i, i)
    end

    local i = 1
    local s = at(i)
    local current_word = {}

    local push_glyph = function()
        if #current_word == 0 then return end

        local style = rt.FontStyle.REGULAR
        if settings.is_bold and settings.is_italic then
            style = rt.FontStyle.BOLD_ITALIC
        elseif settings.is_bold then
            style = rt.FontStyle.BOLD
        elseif settings.is_italic then
            style = rt.FontStyle.ITALIC
        end

        local font = self._font
        if settings.is_mono == true then
            style = _font_style_to_mono_font_style[style]
        end

        local color_r, color_g, color_b = _rt_color_unpack(_rt_palette[settings.color])
        local outline_color_r, outline_color_g, outline_color_b = _rt_color_unpack(_rt_palette[settings.outline_color])

        local word = _concat(current_word)
        local to_insert = self:_glyph_new(
           word, font, style, settings.is_mono,
            color_r, color_g, color_b,
            outline_color_r, outline_color_g, outline_color_b,
            settings.is_underlined,
            settings.is_strikethrough,
            settings.is_outlined or settings.outline_color_active,
            settings.is_effect_shake,
            settings.is_effect_wave,
            settings.is_effect_rainbow,
            settings.is_effect_noise
        )

        _insert(glyphs, to_insert)

        if settings.is_outlined or settings.outline_color_active then
            _insert(self._outlined_glyphs, to_insert)
            self._use_outline = true
        else
            _insert(self._non_outlined_glyphs, to_insert)
        end

        if settings.is_effect_shake or settings.is_effect_wave or settings.is_effect_rainbow or settings.is_effect_noise then
            self._use_animation = true
        end

        _insert(self._glyphs_only, to_insert)

        self._n_characters = self._n_characters + to_insert.n_visible_characters
        self._n_glyphs = self._n_glyphs + 1

        for j = 1, utf8.len(word) do
            local weight = beat_weights[utf8.sub(word, j, j)]
            if weight == nil then weight = 1 end
            self._total_beats = self._total_beats + weight
        end

        current_word = {}
    end

    local function throw_parse_error(reason)
        rt.error("In rt.Label._parse: Error at position `" .. tostring(i) .. "`: " .. reason)
    end

    local function step(n)
        i = i + n
        s = at(i)
    end

    local n_characters = utf8.len(self._raw)
    while i <= n_characters do
        if s == _syntax.ESCAPE_CHARACTER then
            step(1)
            _insert(current_word, s)
            step(1)
            goto continue;
        elseif s == " " then
            push_glyph()
            _insert(glyphs, _syntax.SPACE)
            self._total_beats = self._total_beats + (beat_weights[_syntax.SPACE] or 1)
        elseif s == "\n" then
            push_glyph()
            _insert(glyphs, _syntax.NEWLINE)
            self._total_beats = self._total_beats + (beat_weights[_syntax.NEWLINE] or 1)
        elseif s == "\t" then
            push_glyph()
            _insert(glyphs, _syntax.TAB)
            self._total_beats = self._total_beats + (beat_weights[_syntax.TAB] or 1)
        elseif s == _syntax.BEAT then
            push_glyph() -- remove?
            _insert(glyphs, _syntax.BEAT)
            self._total_beats = self._total_beats + (beat_weights[_syntax.BEAT] or 1)
        elseif s == "<" then
            push_glyph()

            -- get tag
            local sequence = {}
            local sequence_i = 0
            local sequence_s
            local is_closing_tag = false
            repeat
                if i + sequence_i > n_characters then
                    throw_parse_error("malformed tag, `" .. _concat(sequence) .. "` reached end of text")
                end

                sequence_s = at(i + sequence_i)
                if sequence_s == "/" then
                    is_closing_tag = true
                end

                _insert(sequence, sequence_s)
                sequence_i = sequence_i + 1
            until sequence_s == ">"

            sequence = _concat(sequence)

            local settings_key = _sequence_to_settings_key[sequence]
            if settings_key ~= nil then
                if is_closing_tag then
                    if settings[settings_key] == false then
                        throw_parse_error("trying to close region with `" .. sequence .. "`, but not such region is open")
                    end

                    settings[settings_key] = false
                else
                    if settings[settings_key] == true then
                        throw_parse_error("trying to open region with `" .. sequence .. "`, but such a region is already open")
                    end

                    settings[settings_key] = true
                end
            else
                if is_closing_tag then -- manually parse color tags
                    local found = false
                    for other in keys(_syntax.COLOR_TAG_END) do
                        if sequence == other then
                            settings.color = default_color
                            settings.color_active = false
                            found = true
                            break
                        end
                    end

                    if not found then
                        for other in keys(_syntax.OUTLINE_COLOR_TAG_END) do
                            if sequence == other then
                                settings.outline_color = default_outline_color
                                settings.outline_color_active = false
                                found = true
                                break
                            end
                        end
                    end

                    if not found then
                        throw_parse_error("unrecognized tag `" .. sequence .. "`")
                    end
                else
                    -- parse out color string
                    local found, new_color
                    for tag in keys(_syntax.COLOR_TAG_START) do
                        found, _, new_color = _find(sequence, tag)
                        if found ~= nil then
                            if _rt_palette[new_color] == nil then
                                throw_parse_error("malformed color tag: color `" .. new_color .. "` unknown")
                            end

                            settings.color = new_color
                            settings.color_active = true
                            break
                        end
                    end

                    if found == nil then
                        for tag in keys(_syntax.OUTLINE_COLOR_TAG_START) do
                            found, _, new_color = _find(sequence, tag)
                            if found ~= nil then
                                if _rt_palette[new_color] == nil then
                                    throw_parse_error("malformed outline color tag: color `" .. new_color .. "` unknown")
                                end

                                settings.outline_color = new_color
                                settings.outline_color_active = true
                                break
                            end
                        end
                    end

                    if found == nil then
                        throw_parse_error("unrecognized tag `" .. sequence .. "`")
                    end
                end
            end

            step(sequence_i - 1)
        else
            _insert(current_word, s)
        end
        step(1)
        ::continue::
    end
    push_glyph()

    if settings.is_bold then throw_parse_error("reached end of text, but bold region is still open") end
    if settings.is_italic then throw_parse_error("reached end of text, but italic region is still open") end
    if settings.color_active then throw_parse_error("reached end of text, but colored region is still open") end
    if settings.outline_color_active then throw_parse_error("reached end of text, but outline color region is still open") end
    if settings.is_effect_shake then throw_parse_error("reached end of text, but effect shake region is still open") end
    if settings.is_effect_wave then throw_parse_error("reached end of text, but effect wave region is still open") end
    if settings.is_effect_rainbow then throw_parse_error("reached end of text, but effect rainbow region is still open") end
    if settings.is_effect_noise then throw_parse_error("reached end of text, but effect noise region is still open") end
    if settings.is_underlined then throw_parse_error("reached end of text, but effect underlined region is still open") end
    if settings.is_strikethrough then throw_parse_error("reached end of text, but effect strikethrough region is still open") end
    if settings.is_outlined then throw_parse_error("reached end of text, but effect outline region is still open") end

    -- estimate size before wrapping
    local max_width = 0
    local width = 0
    local n_rows = 1

    local space_w = self:_measure_glyph(_syntax.SPACE, false)
    local mono_space_w = self:_measure_glyph(_syntax.SPACE, true)

    local tab_w = self:_measure_glyph(_syntax.TAB, false)
    local mono_tab_w = self:_measure_glyph(_syntax.TAB, true)

    local last_glyph_was_mono = false
    for glyph in values(self._glyphs) do
        if glyph == _syntax.SPACE then
            width = width + ternary(last_glyph_was_mono, mono_space_w, space_w)
            last_glyph_was_mono = false
        elseif glyph == _syntax.TAB then
            width = width + ternary(last_glyph_was_mono, mono_tab_w, tab_w)
            last_glyph_was_mono = false
        elseif glyph == _syntax.NEWLINE then
            max_width = _max(max_width, width)
            width = 0
            n_rows = n_rows + 1
            last_glyph_was_mono = false
        elseif glyph == _syntax.BEAT then
            -- noop
        else
            width = width + glyph.width
            last_glyph_was_mono = glyph.is_mono
        end
    end

    self._width = _max(max_width, width)
    self._height = n_rows * self._font:get_native(self._font_size, rt.FontStyle.BOLD_ITALIC):getHeight()
    if self._n_visible_characters == -1 then
        self._n_visible_characters = n_characters
    end
end

--- @brief [internal]
function rt.Label:_glyph_set_n_visible_characters(glyph, n)
    glyph.n_visible_characters = n
    if glyph.is_underlined or glyph.is_strikethrough then
        local new_width = glyph.font:getWidth(string.sub(glyph.text, 1, glyph.n_visible_characters))

        if glyph.is_underlined then
            glyph.underline_bx = glyph.x + _padding + new_width
        end

        if glyph.is_strikethrough then
            glyph.strikethrough_bx = glyph.x + _padding + new_width
        end
    end
end

--- @brief [internal]
function rt.Label:_apply_wrapping()
    local current_line_width = 0
    local max_line_w = 0

    local bold_italic = self._font:get_native(self._font_size, rt.FontStyle.BOLD_ITALIC)
    local space_w = self:_measure_glyph(_syntax.SPACE, false)
    local mono_space_w = self:_measure_glyph(_syntax.SPACE, true)
    local tab_w = self:_measure_glyph(_syntax.TAB, true)
    local mono_tab_w = self:_measure_glyph(_syntax.TAB, false)
    local line_height = bold_italic:getHeight()

    local glyph_x, glyph_y = 0, 0
    local max_w = self._bounds.width
    local row_i = 1
    local is_first_word = true

    local line_spacing = 0

    local row_widths = {}
    local row_w = 0
    local max_glyph_x = 0
    local newline = function()
        max_glyph_x = _max(max_glyph_x, glyph_x)
        _insert(row_widths, glyph_x)
        if is_first_word ~= true then
            glyph_x = 0
            glyph_y = glyph_y + line_height + line_spacing
            row_i = row_i + 1
        end
    end

    local min_x, max_x, min_y, max_y = math.huge, -math.huge, math.huge, -math.huge
    local min_outline_y, max_outline_y = math.huge, -math.huge
    local max_outline_row_w = -math.huge

    local last_glyph_was_mono = false

    local last_glyph_was_underlined = false
    local last_glyph_underline_bx = -math.huge

    local last_glyph_was_strikethrough = false
    local last_glyph_strikethrough_bx = -math.huge

    local last_r, last_g, last_b

    for glyph in values(self._glyphs) do
        if glyph == _syntax.SPACE then
            if glyph_x ~= 0 then -- skip pre-trailing whitespaces
                glyph_x = glyph_x + ternary(last_glyph_was_mono, mono_space_w, space_w)
                row_w = row_w + space_w
            end
            if glyph_x > max_w then newline() end
            last_glyph_was_mono = false
        elseif glyph == _syntax.TAB then
            glyph_x = glyph_x + ternary(last_glyph_was_mono, mono_tab_w, tab_w)
            row_w = row_w + tab_w
            if glyph_x > max_w then newline() end
            last_glyph_was_mono = false
        elseif glyph == _syntax.NEWLINE then
            newline()
            last_glyph_was_underlined = false
            last_glyph_was_strikethrough = false
            last_r, last_g, last_b = nil, nil, nil
        elseif glyph == _syntax.BEAT then
            -- noop
        else
            if glyph_x + glyph.width >= max_w then
                newline()
                last_glyph_was_underlined = false
                last_glyph_was_strikethrough = false
                last_r, last_g, last_b = nil, nil, nil
            end

            glyph.x = math.floor(glyph_x)
            glyph.y = math.floor(glyph_y)
            glyph.row_index = row_i

            if glyph.is_outlined then
                min_outline_y = _min(min_outline_y, glyph.y)
                max_outline_y = _max(max_outline_y, glyph.y + glyph.height)
            end

            local color_matches = true
            if last_r ~= nil and last_g ~= nil and last_b ~= nil then
                color_matches = last_r == glyph.color[1] and last_g == glyph.color[2] and last_b == glyph.color[3]
            end

            if glyph.is_underlined or glyph.is_strikethrough then
                local font = glyph.font
                local underline_y = font:getBaseline() + 0.5 * font:getHeight() + font:getDescent() + 4 -- experimentally determined
                local strikethrough_y = font:getBaseline()

                if glyph.is_underlined then
                    if last_glyph_was_underlined and color_matches then
                        glyph.underline_ax = last_glyph_underline_bx
                    else
                        glyph.underline_ax = glyph.x + _padding
                    end
                    glyph.underline_ay = _ceil(glyph.y + underline_y)
                    glyph.underline_bx = glyph.x + glyph.width + _padding
                    glyph.underline_by = glyph.underline_ay
                end

                if glyph.is_strikethrough then
                    if last_glyph_was_strikethrough and color_matches then
                        glyph.strikethrough_ax = last_glyph_strikethrough_bx
                    else
                        glyph.strikethrough_ax = glyph.x + _padding
                    end
                    glyph.strikethrough_ay = _ceil(glyph.y + strikethrough_y)
                    glyph.strikethrough_bx = glyph.x + glyph.width + _padding
                    glyph.strikethrough_by = glyph.strikethrough_ay
                end
            end

            min_x = _min(min_x, glyph.x)
            min_y = _min(min_y, glyph.y)
            max_x = _max(max_x, glyph.x + glyph.width)
            max_y = _max(max_y, glyph.y + glyph.height)

            glyph_x = glyph_x + glyph.width

            last_glyph_was_mono = glyph.is_mono
            last_glyph_was_underlined = glyph.is_underlined and color_matches

            if glyph.is_underlined and color_matches then
                last_glyph_underline_bx = glyph.underline_bx - _padding
            else
                last_glyph_underline_bx = -math.huge
            end

            last_glyph_was_strikethrough = glyph.is_strikethrough
            if glyph.is_strikethrough and color_matches then
                last_glyph_strikethrough_bx = glyph.strikethrough_bx - _padding
            else
                last_glyph_strikethrough_bx = -math.huge
            end

            last_r, last_g, last_b = table.unpack(glyph.color)
        end

        min_x = math.min(min_x, glyph_x) -- consider non-glyphs for size
        max_x = math.max(max_x, glyph_x)

        is_first_word = false
    end
    _insert(row_widths, glyph_x)

    if max_w == math.huge then
        max_w = self._width
    end

    -- update justify offsets
    for glyph in values(self._glyphs_only) do
        glyph.justify_center_offset = (max_w - row_widths[glyph.row_index]) / 2
        glyph.justify_right_offset = (max_w - row_widths[glyph.row_index])
    end

    self._width = max_x - min_x
    self._height = line_height * row_i
    self._n_lines = row_i

    self._texture_offset_x = -_padding
    self._texture_offset_y = -_padding
    local outline_texture_w = self._width + 2 * _padding
    local outline_texture_h = self._height + 2 * _padding

    if outline_texture_w < 1 then outline_texture_w = 1 end
    if outline_texture_h < 1 then outline_texture_h = 1 end

    self._justify_left_offset = 0
    self._justify_center_offset = (self._bounds.width - self._width) * 0.5
    self._justify_right_offset = (self._bounds.width - self._width)

    if self._justify_center_offset < 0 then self._justify_center_offset = 0 end
    if self._justify_right_offset < 0 then self._justify_right_offset = 0 end

    self._texture_width = outline_texture_w
    self._texture_height = outline_texture_h
    self._texture = rt.RenderTexture(outline_texture_w, outline_texture_h, rt.GameState:get_msaa_quality(), _texture_format)
    self:_update_n_visible_characters()
end

--- @brief [internal]
function rt.Label:_update_n_visible_characters()
    local n_characters_drawn = 0
    for glyph in values(self._glyphs_only) do
        if n_characters_drawn > self._n_visible_characters then
            self:_glyph_set_n_visible_characters(glyph, 0)
        else
            self:_glyph_set_n_visible_characters(glyph, self._n_visible_characters - n_characters_drawn)
        end
        n_characters_drawn = n_characters_drawn + glyph.n_characters
    end
end

--- @brief
--- @return Boolean, Number, Number is_done, n_visible_rows, n_characters
function rt.Label:update_n_visible_characters_from_elapsed(elapsed, n_characters_per_second)
    if self:get_is_realized() ~= true then self:realize() end

    if n_characters_per_second == nil then n_characters_per_second = rt.settings.label.scroll_speed * rt.GameState:get_text_speed() end

    local so_far = elapsed
    local step = 1 / n_characters_per_second
    local n_visible = 0
    local weights = _syntax.BEAT_WEIGHTS
    local max_row = 0
    for glyph in values(self._glyphs) do
        if meta.is_table(glyph) then
            if so_far <= 0 then
                self:_glyph_set_n_visible_characters(glyph, 0)
            else
                local text = glyph.text
                local n_seen = 1
                for i = 1, glyph.n_characters do
                    local weight = weights[string.sub(glyph.text, i, i)]
                    if weight == nil then
                        so_far = so_far - step
                    else
                        so_far = so_far - weight * step
                    end

                    n_visible = n_visible + 1
                    n_seen = n_seen + 1
                    if so_far < 0 then break end
                end
                self:_glyph_set_n_visible_characters(glyph, n_seen)
                max_row = math.max(max_row, glyph.row_index)
            end
        else
            local weight = weights[glyph]
            if weight ~= nil then
                so_far = so_far - weight * step
            end
        end
    end


    local is_done = elapsed > self._total_beats * (1 / n_characters_per_second)
    self:_update_texture()
    local rest_delta = so_far
    return is_done, max_row, so_far
end

--- @brief [internal]
function rt.Label:_update_texture()
    if self._n_glyphs == 0 or self._texture == nil then return end

    love.graphics.push("all")
    love.graphics.reset()
    love.graphics.setBlendMode("alpha")

    love.graphics.setCanvas(self._texture._native)
    love.graphics.clear(0, 0, 0, 0)
    love.graphics.setShader(_draw_outline_shader)
    _draw_outline_shader:send("elapsed", self._elapsed)
    _draw_outline_shader:send("font_size", self._font:get_actual_size(self._font_size))

    local justify_mode = self._justify_mode
    if justify_mode == rt.JustifyMode.CENTER then
        love.graphics.translate(-1 * self._justify_center_offset, 0)
    elseif justify_mode == rt.JustifyMode.RIGHT then
        love.graphics.translate(-1 * self._justify_right_offset, 0)
    end

    -- draw outlines
    love.graphics.setLineWidth(3) -- line outline
    for glyph in values(self._outlined_glyphs) do
        _draw_outline_shader:send("n_visible_characters", glyph.n_visible_characters)
        _draw_outline_shader:send("is_effect_wave", glyph.is_effect_wave)
        _draw_outline_shader:send("is_effect_noise", glyph.is_effect_noise)
        _draw_outline_shader:send("is_effect_shake", glyph.is_effect_shake)
        _draw_outline_shader:send("outline_color", glyph.outline_color)

        local justify_offset = 0
        if justify_mode == rt.JustifyMode.CENTER then
            justify_offset = glyph.justify_center_offset
        elseif justify_mode == rt.JustifyMode.RIGHT then
            justify_offset = glyph.justify_right_offset
        end

        local r, g, b, a = table.unpack(glyph.outline_color)
        love.graphics.setColor(r, g, b, a)
        love.graphics.draw(glyph.outline_glyph,
            _floor(glyph.x + _padding + justify_offset),
            _floor(glyph.y + _padding)
        )

        if glyph.is_underlined then
            love.graphics.line(glyph.underline_ax, glyph.underline_ay, glyph.underline_bx, glyph.underline_by)
        end

        if glyph.is_strikethrough then
            love.graphics.line(glyph.strikethrough_ax, glyph.strikethrough_ay, glyph.strikethrough_bx, glyph.strikethrough_by)
        end
    end

    -- draw glyphs
    love.graphics.setShader(_draw_text_shader)
    _draw_text_shader:send("elapsed", self._elapsed)
    _draw_text_shader:send("font_size", self._font:get_actual_size(self._font_size))
    _draw_text_shader:send("opacity", 1)

    love.graphics.setLineWidth(2)
    for glyph in values(self._glyphs_only) do
        _draw_text_shader:send("n_visible_characters", glyph.n_visible_characters)
        _draw_text_shader:send("is_effect_rainbow", glyph.is_effect_rainbow)
        _draw_text_shader:send("is_effect_noise", glyph.is_effect_noise)
        _draw_text_shader:send("is_effect_wave", glyph.is_effect_wave)
        _draw_text_shader:send("is_effect_shake", glyph.is_effect_shake)

        local justify_offset = 0
        if justify_mode == rt.JustifyMode.CENTER then
            justify_offset = glyph.justify_center_offset
        elseif justify_mode == rt.JustifyMode.RIGHT then
            justify_offset = glyph.justify_right_offset
        end

        love.graphics.push()
        love.graphics.translate(justify_offset, 0)

        local r, g, b, a = table.unpack(glyph.color)
        love.graphics.setColor(r, g, b, a)
        love.graphics.draw(glyph.glyph,
            _floor(glyph.x + _padding ),
            _floor(glyph.y + _padding)
        )

        if glyph.is_underlined then
            love.graphics.line(glyph.underline_ax, glyph.underline_ay, glyph.underline_bx, glyph.underline_by)
        end

        if glyph.is_strikethrough then
            love.graphics.line(glyph.strikethrough_ax, glyph.strikethrough_ay, glyph.strikethrough_bx, glyph.strikethrough_by)
        end
        love.graphics.pop()
    end

    love.graphics.setShader(nil)
    love.graphics.setCanvas(nil)
    love.graphics.pop()
end

