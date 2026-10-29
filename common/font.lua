rt.settings.font = {
    default = nil,
    title_font = nil,
    love_default = love.graphics.getFont(),
    asset_prefix = "assets/fonts/"
}

--- @class rt.Font
rt.Font = meta.class("Font")

--- @enum rt.FontSize
rt.FontSize = {
    MAX = 0.5,
    ENORMOUS = 0.2,
    GIGANTIC = 0.15,
    HUGE = 60 / rt.settings.native_height,
    LARGER = 50 / rt.settings.native_height,
    LARGE = 40 / rt.settings.native_height,
    BIG = 30 / rt.settings.native_height,
    REGULAR = 20 / rt.settings.native_height,
    SMALL = 16 / rt.settings.native_height,
    TINY = 12 / rt.settings.native_height
}
rt.FontSize = meta.enum("FontSize", rt.FontSize)

--- @enum rt.FontStyle
rt.FontStyle = {
    REGULAR = "REGULAR",
    ITALIC = "ITALIC",
    BOLD = "BOLD",
    BOLD_ITALIC = "BOLD_ITALIC",
    MONO_REGULAR = "MONO_REGULAR",
    MONO_ITALIC = "MONO_ITALIC",
    MONO_BOLD = "MONO_BOLD",
    MONO_BOLD_ITALIC = "MONO_BOLD_ITALIC",
}
rt.FontStyle = meta.enum("FontStyle", rt.FontStyle)

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
        regular_path, mt.String,
        bold_path, mt.String,
        italic_path, mt.String,
        bold_italic_path, mt.String
    )

    self._font_style_to_path = {
        [rt.FontStyle.REGULAR] = regular_path,
        [rt.FontStyle.ITALIC] = italic_path,
        [rt.FontStyle.BOLD] = bold_path,
        [rt.FontStyle.BOLD_ITALIC] = bold_italic_path,
        [rt.FontStyle.MONO_REGULAR] = mono_regular_path,
        [rt.FontStyle.MONO_ITALIC] = mono_italic_path,
        [rt.FontStyle.MONO_BOLD] = mono_bold_path,
        [rt.FontStyle.MONO_BOLD_ITALIC] = mono_bold_italic_path
    }

    self._font_style_to_fallback = {
        [rt.FontStyle.REGULAR] = {},
        [rt.FontStyle.ITALIC] = {},
        [rt.FontStyle.BOLD] = {},
        [rt.FontStyle.BOLD_ITALIC] = {},
        [rt.FontStyle.MONO_REGULAR] = {},
        [rt.FontStyle.MONO_ITALIC] = {},
        [rt.FontStyle.MONO_BOLD] = {},
        [rt.FontStyle.MONO_BOLD_ITALIC] = {}
    }

    self._line_spacing = 1 -- fraction
end

local _sdf = true
local _no_sdf = false

-- cache font by size
local _atlas = {}

local function _new_font(path, size, sdf, fallbacks)
    if sdf == nil then sdf = _sdf end

    if _atlas[path] == nil then _atlas[path] = {} end
    if _atlas[path][size] == nil then _atlas[path][size] = meta.make_weak({}) end

    local native = _atlas[path][size][sdf]
    if native == nil then
        native = love.graphics.newFont(path, size, {
            sdf = sdf,
            hinting = "normal"
        })
        _atlas[path][size][sdf] = native
    end

    if fallbacks ~= nil and #fallbacks > 0 then
        local native_fallbacks = {}
        for fallback_path in values(fallbacks) do
            if _atlas[fallback_path] == nil then _atlas[fallback_path] = {} end
            if _atlas[fallback_path][size] == nil then _atlas[fallback_path][size] = meta.make_weak({}) end

            local fallback_native = _atlas[fallback_path][size][sdf]
            if fallback_native == nil then
                fallback_native = love.graphics.newFont(fallback_path, size, {
                    sdf = sdf,
                    hinting = "normal"
                })

                _atlas[fallback_path][size][sdf] = fallback_native
            end

            table.insert(native_fallbacks, fallback_native)
        end

        native:setFallbacks(table.unpack(native_fallbacks))
    end

    return native
end

--- @brief
function rt.Font:get_native(size, style, sdf)
    meta.assert(
        size, mt.Union(rt.FontSize, mt.Number),
        style, mt.Optional(rt.FontStyle),
        sdf, mt.Optional(mt.Boolean)
    )

    if style == nil then style = rt.FontStyle.REGULAR end

    local actual_size = meta.is_enum_value(size, rt.FontSize) and self:get_actual_size(size) or size
    local path = self._font_style_to_path[style]

    local sdf_out = _new_font(path, actual_size, _sdf, self._font_style_to_fallback[style])
    local no_sdf_out = _new_font(path, actual_size, _no_sdf, self._font_style_to_fallback[style])

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
    meta.assert(size, mt.Union(rt.FontSize, mt.Number))
    local max = 14 / rt.SceneManager:get_downscaling_factor()
    if meta.is_enum_value(size, rt.FontSize) then
        return math.max(math.ceil(size * rt.SceneManager:get_height()), 14 / rt.SceneManager:get_downscaling_factor())
    else
        return math.max(math.ceil(size), max)
    end
end

--- @brief
function rt.Font:measure(font_size_or_pt, str)
    meta.assert(font_size_or_pt, mt.Union(rt.FontSize, mt.Number), str, mt.String)

    local native = self:get_native(font_size_or_pt)
    return native:getWidth(str), native:getHeight()
end

--- @brief
function rt.Font:get_line_height(font_size)
    meta.assert(font_size, rt.FontSize)
    return self:get_native(font_size):getHeight()
end

--- @brief
function rt.Font:set_line_spacing(fraction)
    self._line_spacing = fraction
end

--- @brief
function rt.Font:get_line_spacing()
    return self._line_spacing
end

--- @brief
function rt.Font:add_fallbacks(...)
    for i = 1, select("#", ...), 2 do
        local style = select(i + 0, ...)
        local path = select(i + 1, ...)
        meta.assert_argument_type(style, rt.FontStyle, i + 0)
        meta.assert_argument_type(path, mt.String, i + 1)
        if not bd.exists(path) then
            rt.error("In rt.Font.add_fallbacks: file at `", path, "` does not exist")
        end

        table.insert(self._font_style_to_fallback[style], path)
    end

    return self
end

local prefix = rt.settings.font.asset_prefix

-- load default font
rt.settings.font.default = rt.Font(
    prefix .. "DejaVuSans/DejaVuSans-Regular.ttf",
    prefix .. "DejaVuSans/DejaVuSans-Bold.ttf",
    prefix .. "DejaVuSans/DejaVuSans-Italic.ttf",
    prefix .. "DejaVuSans/DejaVuSans-BoldItalic.ttf",
    prefix .. "DejaVuSansMono/DejaVuSansMono-Regular.ttf",
    prefix .. "DejaVuSansMono/DejaVuSansMono-Bold.ttf",
    prefix .. "DejaVuSansMono/DejaVuSansMono-Italic.ttf",
    prefix .. "DejaVuSansMono/DejaVuSansMono-BoldItalic.ttf"
):add_fallbacks(
    rt.FontStyle.REGULAR,     prefix .. "NotoSans/NotoSans-Regular.ttf",
    rt.FontStyle.BOLD,        prefix .. "NotoSans/NotoSans-Bold.ttf",
    rt.FontStyle.ITALIC,      prefix .. "NotoSans/NotoSans-Italic.ttf",
    rt.FontStyle.BOLD_ITALIC, prefix .. "NotoSans/NotoSans-BoldItalic.ttf",

    rt.FontStyle.REGULAR,     prefix .. "NotoSansMath/NotoSansMath-Regular.ttf",

    rt.FontStyle.REGULAR,     prefix .. "NotoSansJP/NotoSansJP-Regular.ttf",
    rt.FontStyle.BOLD,        prefix .. "NotoSansJP/NotoSansJP-Bold.ttf"
)

rt.settings.font.title_font = rt.Font(
    prefix .. "Baloo2/Baloo2-Bold.ttf",
    prefix .. "Baloo2/Baloo2-ExtraBold.ttf"
)