rt.settings.font = {
    default = nil,
    love_default = love.graphics.getFont()
}

--- @class rt.Font
rt.Font = meta.class("Font")

--- @class rt.FontSize
rt.FontSize = meta.enum("FontSize", {
    GIGANTIC = 0.15,
    HUGE = 60 / rt.settings.native_height,
    LARGE = 40 / rt.settings.native_height,
    BIG = 30 / rt.settings.native_height,
    REGULAR = 20 / rt.settings.native_height,
    SMALL = 16 / rt.settings.native_height,
    TINY = 12 / rt.settings.native_height
})

--- @class rt.FontStyle
rt.FontStyle = meta.enum("FontStyle", {
    REGULAR = "REGULAR",
    ITALIC = "ITALIC",
    BOLD = "BOLD",
    BOLD_ITALIC = "BOLD_ITALIC",
    MONO_REGULAR = "MONO_REGULAR",
    MONO_ITALIC = "MONO_ITALIC",
    MONO_BOLD = "MONO_BOLD",
    MONO_BOLD_ITALIC = "MONO_BOLD_ITALIC",
})

--- @brief
function rt.Font:instantiate(
    regular_path,
    bold_path,
    italic_path,
    bold_italic_path,
    mono_regular_path,
    mono_bold_path,
    mono_italic_path,
    mono_bold_italic_path
)
    if bold_path == nil then bold_path = regular_path end
    if italic_path == nil then italic_path = regular_path end
    if bold_italic_path == nil then bold_italic_path = italic_path end

    if mono_regular_path == nil then mono_regular_path = regular_path end
    if mono_bold_path == nil then mono_bold_path = mono_regular_path end
    if mono_italic_path == nil then mono_italic_path = mono_regular_path end
    if mono_bold_italic_path == nil then mono_bold_italic_path = mono_italic_path end

    meta.assert(
        regular_path, "String",
        bold_path, "String",
        italic_path, "String",
        bold_italic_path, "String"
    )

    self._font_style_to_path = {
        [rt.FontStyle.REGULAR] = regular_path,
        [rt.FontStyle.ITALIC] = italic_path,
        [rt.FontStyle.BOLD] = bold_path,
        [rt.FontStyle.BOLD_ITALIC] = bold_italic_path,
        [rt.FontStyle.MONO_REGULAR] = mono_regular_path,
        [rt.FontStyle.MONO_ITALIC] = mono_italic_path,
        [rt.FontStyle.MONO_BOLD] = mono_bold_path,
        [rt.FontStyle.MONO_BOLD_ITALIC] = mono_bold_italic_path,
    }

    self._size_to_cache = {}
    self._size_to_fallbacks = {}
    self._line_spacing = 1 -- fraction
end

local _new_font = function(path, size, sdf)
    return love.graphics.newFont(path, size, {
        hinting = "normal",
        sdf = sdf
    })
end

local _sdf = true
local _no_sdf = false

--- @brief
function rt.Font:get_native(size, style, sdf)
    meta.assert_enum_value(size, rt.FontSize, 1)

    if style == nil then style = rt.FontStyle.REGULAR end
    meta.assert_enum_value(style, rt.FontStyle, 2)

    if sdf == nil then sdf = false end
    meta.assert_typeof(sdf, "Boolean", 3)

    local actual_size = self:get_actual_size(size)
    local path = self._font_style_to_path[style]

    local entry = self._size_to_cache[actual_size]
    if entry == nil then
        entry = {}
        self._size_to_cache[actual_size] = entry
    end

    local native_entry = entry[style]
    local needs_fallbacks = false
    if native_entry == nil then
        native_entry = {
            sdf = _new_font(path, actual_size, _sdf),
            no_sdf = _new_font(path, actual_size, _no_sdf)
        }

        entry[style] = native_entry
        needs_fallbacks = true
    end

    local sdf_out = native_entry.sdf
    local no_sdf_out = native_entry.no_sdf

    local fallback_entry = self._size_to_fallbacks[actual_size]
    if fallback_entry == nil then
        fallback_entry = {
            sdf = {
                _new_font("assets/fonts/NotoSansMath/NotoSansMath-Regular.ttf", actual_size, _sdf),
            },

            no_sdf = {
                _new_font("assets/fonts/NotoSansMath/NotoSansMath-Regular.ttf", actual_size, _no_sdf),
            }
        }
        self._size_to_fallbacks = fallback_entry
    end

    if needs_fallbacks then
        sdf_out:setFallbacks(table.unpack(fallback_entry.sdf))
        no_sdf_out:setFallbacks(table.unpack(fallback_entry.no_sdf))
    end

    if sdf == nil then
        return sdf_out, no_sdf_out
    elseif sdf == true then
        return sdf_out
    else
        return no_sdf_out
    end
end

--- @brief
function rt.Font:get_actual_size(size)
    meta.assert_enum_value(size, rt.FontSize, 1)
    return math.max(math.ceil(size * love.graphics.getHeight(), 14))
end

--- @brief
function rt.Font:measure(font_size, str)
    meta.assert_enum_value(font_size, rt.FontSize, 1)
    meta.assert_typeof(str, "String", 2)
    local native = self:get_native(font_size)
    return native:getWidth(str), native:getHeight()
end

--- @brief
function rt.Font:set_line_spacing(fraction)
    self._line_spacing = fraction
end

--- @brief
function rt.Font:get_line_spacing()
    return self._line_spacing
end

-- load default font
rt.settings.font.default = rt.Font(
    "assets/fonts/DejaVuSans/DejaVuSans-Regular.ttf",
    "assets/fonts/DejaVuSans/DejaVuSans-Bold.ttf",
    "assets/fonts/DejaVuSans/DejaVuSans-Italic.ttf",
    "assets/fonts/DejaVuSans/DejaVuSans-BoldItalic.ttf",
    "assets/fonts/DejaVuSansMono/DejaVuSansMono-Regular.ttf",
    "assets/fonts/DejaVuSansMono/DejaVuSansMono-Bold.ttf",
    "assets/fonts/DejaVuSansMono/DejaVuSansMono-Italic.ttf",
    "assets/fonts/DejaVuSansMono/DejaVuSansMono-BoldItalic.ttf"
)