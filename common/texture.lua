require "common.drawable"

--- @class rt.TextureScaleMode
rt.TextureScaleMode = meta.enum("TextureScaleMode", {
    LINEAR = "linear",
    NEAREST = "nearest"
})

--- @class rt.TextureWrapMode
rt.TextureWrapMode = meta.enum("TextureWrapMode", {
    ZERO = "clampzero",
    ONE = "clampone",
    CLAMP = "clamp",
    REPEAT = "repeat",
    MIRROR = "mirroredrepeat"
})

--- @class rt.TextureFormat
rt.TextureFormat = {
    --                         | #  | Size | Range
    --                         |----|------|-----------------
    NORMAL = "normal",      -- | 4  | 32   | [0, 1]
    R8 = "r8",              -- | 1  | 8    | [0, 1]
    RG8 = "rg8",            -- | 2  | 16   | [0, 1]
    RGBA8 = "rgba8",        -- | 4  | 32   | [0, 1]
    SRGBA8 = "srgba8",      -- | 4  | 32   | [0, 1]
    R16 = "r16",            -- | 1  | 16   | [0, 1]
    RG16 = "rg16",          -- | 2  | 32   | [0, 1]
    RGBA16 = "rgba16",      -- | 4  | 64   | [0, 1]
    R16F = "r16f",          -- | 1  | 16   | [-65504, +65504]
    RG16F = "rg16f",        -- | 2  | 32   | [-65504, +65504]
    RGBA16F = "rgba16f",    -- | 4  | 64   | [-65504, +65504]
    R32F = "r32f",          -- | 1  | 32   | [-3.4028235e38, 3.4028235e38]
    RG32F = "rg32f",        -- | 2  | 64   | [-3.4028235e38, 3.4028235e38]
    RGBA32F = "rgba32f",    -- | 4  | 128  | [-3.4028235e38, 3.4028235e38]
    RGBA4 = "rgba4",        -- | 4  | 16   | [0, 1]
    RGB5A1 = "rgb5a1",      -- | 4  | 16   | [0, 1]
    RGB565 = "rgb565",      -- | 3  | 16   | [0, 1]
    RGB10A2 = "rgb10a2",    -- | 4  | 32   | [0, 1]
    RG11B10F = "rg11b10f",  -- | 3  | 32   | [0, 65024]
    R8I = "r8i",            -- | 1  | 8    | [-128, 127]
    RG8I = "rg8i",          -- | 2  | 16   | [-128, 127]
    RGBA8I = "rgba8i",      -- | 4  | 32   | [-128, 127]
    R8UI = "r8ui",          -- | 1  | 8    | [0, 255]
    RG8UI = "rg8ui",        -- | 2  | 16   | [0, 255]
    RGBA8UI = "rgba8ui",    -- | 4  | 32   | [0, 255]
    R16I = "r16i",          -- | 1  | 16   | [-32768, 32767]
    RG16I = "rg16i",        -- | 2  | 32   | [-32768, 32767]
    RGBA16I = "rgba16i",    -- | 4  | 64   | [-32768, 32767]
    R16UI = "r16ui",        -- | 1  | 16   | [0, 65535]
    RG16UI = "rg16ui",      -- | 2  | 32   | [0, 65535]
    RGBA16UI = "rgba16ui",  -- | 4  | 64   | [0, 65535]
    R32I = "r32i",          -- | 1  | 32   | [-2147483648, 2147483647]
    RG32I = "rg32i",        -- | 2  | 64   | [-2147483648, 2147483647]
    RGBA32I = "rgba32i",    -- | 4  | 128  | [-2147483648, 2147483647]
    R32UI = "r32ui",        -- | 1  | 32   | [0, 4294967295]
    RG32UI = "rg32ui",      -- | 2  | 64   | [0, 4294967295]
    RGBA32UI = "rgba32ui",  -- | 4  | 128  | [0, 4294967295]
    STENCIL8 = "stencil8",  -- | 1  | 8    | [0, 255]
    DEPTH16 = "depth16",    -- | 1  | 16   | [0, 1]
    DEPTH24 = "depth24",    -- | 1  | 24   | [0, 1]
    DEPTH32F = "depth32f",  -- | 1  | 32   | [0, 1]
    DEPTH24_STENCIL8 = "depth24stencil8",  -- | 2  | 32   | [0, 1], [0, 255]
    DEPTH32F_STENCIL8 = "depth32fstencil8" -- | 2  | 40   | [0, 1], [0, 255]
}

--- @class rt.Texture
--- @param pathor_width String (or Number)
--- @param height Number (or nil)
rt.Texture = meta.class("Texture", rt.Drawable)

--- @brief
function rt.Texture:instantiate(...)
    if select("#", ...) > 0 then
        -- called directly, instead of as parent
        self._native = love.graphics.newImage(...)
        self:set_scale_mode(rt.TextureScaleMode.NEAREST)
        self:set_wrap_mode(rt.TextureWrapMode.CLAMP)
    end
end

--- @brief set scale mode
--- @param mode rt.TextureScaleMode
function rt.Texture:set_scale_mode(mode, other)
    if other == nil then other = mode end
    self._native:setFilter(mode, other)
end

--- @brief get scale mode
--- @return rt.TextureScaleMode
function rt.Texture:get_scale_mode()
    return self._native:getFilter()
end

--- @brief set wrap mode
--- @param mode rt.TextureWrapMode
function rt.Texture:set_wrap_mode(mode_x, mode_y)
    if mode_y == nil then mode_y = mode_x end
    self._native:setWrap(mode_x, mode_y)
end

--- @brief get wrap mode
--- @return rt.TextureWrapMode
function rt.Texture:get_wrap_mode()
    return self._native:getWrap()
end

--- @brief get resolution
--- @return (Number, Number)
function rt.Texture:get_size()
    return self._native:getWidth(), self._native:getHeight()
end

--- @brief get width
--- @return Number
function rt.Texture:get_width()
    return self._native:getWidth()
end

--- @brief get height
--- @return Number
function rt.Texture:get_height()
    return self._native:getHeight()
end

--- @overload rt.Drawable.draw
function rt.Texture:draw(x, y, r, g, b, a)
    if r == nil then
        love.graphics.setColor(1, 1, 1, 1)
    else
        if r == nil then r = 1 end
        if g == nil then g = 1 end
        if b == nil then b = 1 end
        if a == nil then a = 1 end
        love.graphics.setColor(r, g, b, a)
    end

    love.graphics.draw(self._native, x, y)
end

--- @brief
function rt.Texture:release()
    self._native:release()
end

--- @brief
function rt.Texture:get_native()
    return self._native
end

if love.getVersion() >= 12 then
    --- @overload
    function rt.Texture:download()
        return love.graphics.readbackTexture(self._native)
    end
end
