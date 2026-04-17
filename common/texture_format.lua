
--- @enum rt.TextureFormat
rt.TextureFormat = {
    --                                    | #components | bits/pixel | range
    R8                = "r8",          -- | 1           | 8          | [0, 1]
    R16               = "r16",         -- | 1           | 16         | [0, 1]
    R16F              = "r16f",        -- | 1           | 16         | [-65504, +65504]
    R32F              = "r32f",        -- | 1           | 32         | [-3.4028235e38, 3.4028235e38]
    R8I               = "r8i",         -- | 1           | 8          | [-128, 127]
    R8UI              = "r8ui",        -- | 1           | 8          | [0, 255]
    R16I              = "r16i",        -- | 1           | 16         | [-32768, 32767]
    R16UI             = "r16ui",       -- | 1           | 16         | [0, 65535]
    R32I              = "r32i",        -- | 1           | 32         | [-2147483648, 2147483647]
    R32UI             = "r32ui",       -- | 1           | 32         | [0, 4294967295]
    RG8               = "rg8",         -- | 2           | 16         | [0, 1]
    RG16              = "rg16",        -- | 2           | 32         | [0, 1]
    RG16F             = "rg16f",       -- | 2           | 32         | [-65504, +65504]
    RG32F             = "rg32f",       -- | 2           | 64         | [-3.4028235e38, 3.4028235e38]
    RG8I              = "rg8i",        -- | 2           | 16         | [-128, 127]
    RG8UI             = "rg8ui",       -- | 2           | 16         | [0, 255]
    RG16I             = "rg16i",       -- | 2           | 32         | [-32768, 32767]
    RG16UI            = "rg16ui",      -- | 2           | 32         | [0, 65535]
    RG32I             = "rg32i",       -- | 2           | 64         | [-2147483648, 2147483647]
    RG32UI            = "rg32ui",      -- | 2           | 64         | [0, 4294967295]
    RGB565            = "rgb565",      -- | 3           | 16         | [0, 1]
    RG11B10F          = "rg11b10f",    -- | 3           | 32         | [0, 65024]
    NORMAL            = "normal",      -- | 4           | 32         | [0, 1]
    RGBA8             = "rgba8",       -- | 4           | 32         | [0, 1]
    SRGBA8            = "srgba8",      -- | 4           | 32         | [0, 1]
    RGBA16            = "rgba16",      -- | 4           | 64         | [0, 1]
    RGBA16F           = "rgba16f",     -- | 4           | 64         | [-65504, +65504]
    RGBA32F           = "rgba32f",     -- | 4           | 128        | [-3.4028235e38, 3.4028235e38]
    RGBA4             = "rgba4",       -- | 4           | 16         | [0, 1]
    RGB5A1            = "rgb5a1",      -- | 4           | 16         | [0, 1]
    RGB10A2           = "rgb10a2",     -- | 4           | 32         | [0, 1]
    RGBA8I            = "rgba8i",      -- | 4           | 32         | [-128, 127]
    RGBA8UI           = "rgba8ui",     -- | 4           | 32         | [0, 255]
    RGBA16I           = "rgba16i",     -- | 4           | 64         | [-32768, 32767]
    RGBA16UI          = "rgba16ui",    -- | 4           | 64         | [0, 65535]
    RGBA32I           = "rgba32i",     -- | 4           | 128        | [-2147483648, 2147483647]
    RGBA32UI          = "rgba32ui",    -- | 4           | 128        | [0, 4294967295]

    STENCIL8          = "stencil8",    -- | 1           | 8          | [0, 255]
    DEPTH16           = "depth16",     -- | 1           | 16         | [0, 1]
    DEPTH24           = "depth24",     -- | 1           | 24         | [0, 1]
    DEPTH32F          = "depth32f",    -- | 1           | 32         | [0, 1]
    DEPTH24_STENCIL8  = "depth24stencil8",   -- | 2    | 32         | [0, 1], [0, 255]
    DEPTH32F_STENCIL8 = "depth32fstencil8",  -- | 2    | 40         | [0, 1], [0, 255]
}

--- @brief get fallback for texture format if platform does not support it
rt.graphics.texture_format_get_fallback = function(format, is_canvas)
    local fallback_chains = {
        NORMAL            = { },
        R8                = { "r8", "rg8", "rgba8" },
        RG8               = { "rg8", "rgba8" },
        RGBA8             = { "rgba8" },
        SRGBA8            = { "srgba8", "rgba8" },
        R8I               = { "r8i", "rg8i", "rgba8i" },
        RG8I              = { "rg8i", "rgba8i" },
        RGBA8I            = { "rgba8i" },
        R8UI              = { "r8ui", "rg8ui", "rgba8ui" },
        RG8UI             = { "rg8ui", "rgba8ui" },
        RGBA8UI           = { "rgba8ui" },
        STENCIL8          = { "stencil8" },
        RGBA4             = { "rgba4", "rgb5a1", "rgb565", "rgba8" },
        RGB5A1            = { "rgb5a1", "rgba4", "rgb565", "rgba8" },
        RGB565            = { "rgb565", "rgba4", "rgb5a1", "rgba8" },
        R16               = { "r16", "r16f", "rg16", "rg16f", "rgba16", "rgba16f" },
        R16F              = { "r16f", "r16", "rg16f", "rg16", "rgba16f", "rgba16" },
        R16I              = { "r16i", "rg16i", "rgba16i" },
        R16UI             = { "r16ui", "rg16ui", "rgba16ui" },
        DEPTH16           = { "depth16", "depth24", "depth32f" },
        RG16              = { "rg16", "rg16f", "rgba16", "rgba16f" },
        RG16F             = { "rg16f", "rg16", "rgba16f", "rgba16" },
        RG16I             = { "rg16i", "rgba16i" },
        RG16UI            = { "rg16ui", "rgba16ui" },
        R32F              = { "r32f", "rg32f", "rgba32f" },
        R32I              = { "r32i", "rg32i", "rgba32i" },
        R32UI             = { "r32ui", "rg32ui", "rgba32ui" },
        RGB10A2           = { "rgb10a2", "rgba16", "rgba16f" },
        RG11B10F          = { "rg11b10f", "rgba16f", "rgba32f" },
        DEPTH24           = { "depth24", "depth32f", "depth16" },
        DEPTH32F          = { "depth32f", "depth24", "depth16" },
        DEPTH24_STENCIL8  = { "depth24stencil8", "depth32fstencil8" },
        RGBA16            = { "rgba16", "rgba16f" },
        RGBA16F           = { "rgba16f", "rgba16" },
        RGBA16I           = { "rgba16i" },
        RGBA16UI          = { "rgba16ui" },
        RG32F             = { "rg32f", "rgba32f" },
        RG32I             = { "rg32i", "rgba32i" },
        RG32UI            = { "rg32ui", "rgba32ui" },
        DEPTH32F_STENCIL8 = { "depth32fstencil8", "depth24stencil8" },
        RGBA32F           = { "rgba32f" },
        RGBA32I           = { "rgba32i" },
        RGBA32UI          = { "rgba32ui" }
    }

    local supported = love.graphics.getTextureFormats({ canvas = is_canvas })
    if supported[format] == true then return format end

    local resolved = nil
    for format_string in values(fallback_chains[format]) do
        if supported[format_string] == true then
            resolved = format_string
            break
        end
    end

    if resolved == nil
        and not string.contains(format, "stencil")
        and not string.contains(format, "depth")
    then
        resolved = "normal"
    end

    -- if no fallback found, may error on newCanvas
    if resolved == nil then
        rt.critical("In rt.TextureFormat: not fallback for texture `", format, "` available")
        return format
    else
        return resolved
    end
end

-- automatically reassign texture formats
for name, format in pairs(rt.TextureFormat) do
    rt.TextureFormat[name] = rt.graphics.texture_format_get_fallback(format, true)
end
rt.TextureFormat = meta.enum("TextureFormat", rt.TextureFormat)

--- @brief
rt.graphics.texture_format_to_glsl_identifier = function(x)
    local _texture_format_to_glsl_identifier = {
        ["srgba8"] = "rgba8",
        ["rgba4"] = "rgba8",
        ["rgb5a1"] = "rgba8",
        ["rgb565"] = "rgba8",
        ["rgb10a2"] = "rgb10_a2",
        ["rg11b10f"] = "r11f_g11f_b10f",
        ["normal"] = "rgba8",
    }

    return _texture_format_to_glsl_identifier[x] or x
end