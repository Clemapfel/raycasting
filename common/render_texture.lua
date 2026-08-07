require "common.texture"
require "common.image"

--- @enum rt.TextureType
rt.TextureType = {
    NORMAL = "2d",
    VOLUME = "volume",
    ARRAY = "array"
}
rt.TextureType = meta.enum("TextureType", rt.TextureType)

-- @class rt.RenderTexture
rt.RenderTexture = meta.class("RenderTexture", rt.Texture)

local _valid_settings_keys = {
    format = rt.TextureFormat,  -- texture format
    is_compute = mt.Boolean, -- is readable / writable in (compute) shader
    msaa = mt.Number,  -- msaa
    use_mipmaps = mt.Boolean, -- automatically generate mipmaps
    has_stencil = mt.Boolean, -- add same-size stencil buffer
    stencil_readable = mt.Boolean, -- stencil buffer is shader-readable
    has_depth = mt.Boolean,   -- add same-size depth buffer
    depth_readable = mt.Boolean, -- depth buffer is shader-readable

    type = rt.TextureType, -- Normal, Array, or Volume
    array_n_layers = mt.Number, -- if array texture: number of layers
    volume_depth = mt.Number -- if volume texture: depth
}

local _default_settings = {
    format = rt.TextureFormat.NORMAL,
    is_compute = false,
    msaa = 0,
    use_mipmaps = false,
    has_stencil = false,
    stencil_readable = false,
    has_depth = false,
    depth_readable = false,

    type = rt.TextureType.NORMAL,
    array_n_layers = 1,
    volume_depth = 1
}

--- @class rt.RenderTextureArray
rt.RenderTextureArray = function(width, height, n_layers, settings)
    if settings == nil then settings = table.deepcopy(_default_settings) end
    settings.type = rt.TextureType.ARRAY
    settings.array_n_layers = n_layers
    return rt.RenderTexture(width, height, settings)
end

--- @class rt.RenderTextureVolume
rt.RenderTextureVolume = function(width, height, depth, settings)
    if settings == nil then settings = table.deepcopy(_default_settings) end
    settings.type = rt.TextureType.VOLUME
    settings.volume_depth = depth
    return rt.RenderTexture(width, height, settings)
end

local _combine_depth_stencil = love.graphics.getTextureTypes(false).stencil8 ~= true

--- @brief
function rt.RenderTexture:instantiate(width, height, settings)
    if width == nil then width = 1 end
    if height == nil then height = 1 end
    if settings == nil then
        settings = _default_settings
    else
        for key, value in pairs(_default_settings) do
            if settings[key] == nil then settings[key] = value end
        end
    end

    meta.assert(width, mt.Number, height, mt.Number, settings, mt.Table)

    for key, value in pairs(settings) do
        local expected = _valid_settings_keys[key]
        if expected == nil then
            rt.error("In rt.RenderTexture.instantiate: unrecognized settings key `", key, "`")
        else
            if not meta.isa(value, expected) then
                rt.error("In rt.RenderTexture.instantiate: wrong type for settings key `", key, "`. expected `", expected, "`, got `", meta.typeof(value), "`")
            end
        end
    end

    rt.assert(width > 0 and not math.is_nan(width), "In rt.RenderTexture.instantiate: width `", width, "` is not a positive non-zero integer")
    rt.assert(height > 0 and not math.is_nan(height), "In rt.RenderTexture.instantiate: height `", height, "` is not a positive non-zero integer")

    local get_fallback = rt.graphics.texture_format_get_fallback

    local native_settings = {
        format = get_fallback(settings.format, true),
        msaa = settings.msaa,
        mipmaps = ternary(settings.use_mipmaps == true, "auto", "none"),
        readable = true,
        computewrite = settings.is_compute,
        type = settings.type,
        canvas = true
    }

    if settings.type == rt.TextureType.NORMAL then
        self._native = love.graphics.newTexture(width, height, native_settings)
    elseif settings.type == rt.TextureType.VOLUME then
        self._native = love.graphics.newTexture(width, height, settings.volume_depth, native_settings)
    elseif settings.type == rt.TextureType.ARRAY then
        self._native = love.graphics.newTexture(width, height, settings.array_n_layers, native_settings)
    end

    if _combine_depth_stencil
        or (settings.has_stencil == true and settings.has_depth == true)
    then
        if settings.has_stencil == true or settings.has_depth == true then
            self._depth_stencil = love.graphics.newCanvas(width, height, {
                format = get_fallback(rt.TextureFormat.DEPTH24_STENCIL8, true),
                msaa = native_settings.msaa,
                mipmaps = "none",
                readable = settings.stencil_readable == true or settings.depth_readable == true,
                computewrite = settings.stencil_readable == true or settings.depth_readable == true,
                canvas = native_settings.canvas
            })
        end
    else
        if settings.has_stencil == true then
            self._stencil = love.graphics.newCanvas(width, height, {
                format = get_fallback(rt.TextureFormat.STENCIL8, true),
                msaa = native_settings.msaa,
                mipmaps = "none",
                readable = settings.stencil_readable == true,
                computewrite = settings.stencil_readable == true,
                canvas = native_settings.canvas
            })
        elseif settings.has_depth == true then
            self._depth = love.graphics.newCanvas(width, height, {
                format = get_fallback(rt.TextureFormat.DEPTH16, true),
                msaa = native_settings.msaa,
                mipmaps = "none",
                readable = settings.depth_readable == true,
                computewrite = settings.depth_readable == true,
                canvas = native_settings.canvas,
                stencil = true
            })
        end
    end

    self._type = settings.type
end

--- @brief
function rt.RenderTexture:get_msaa()
    return self._native:getMSAA()
end

--- @brief set scale mode
function rt.Texture:set_scale_mode(mode, other, anisotropy)
    if other == nil then other = mode end

    meta.assert(
        mode, rt.TextureScaleMode,
        other, rt.TextureScaleMode,
        anisotropy, mt.Optional(mt.Number)
    )

    for texture in range(
        self._native,
        self._depth, -- automatically filters nils
        self._stencil,
        self._depth_stencil
    ) do
        texture:setFilter(mode, other, anisotropy)
    end
end

--- @brief set wrap mode
function rt.Texture:set_wrap_mode(mode_x, mode_y, mode_z)
    if mode_y == nil then mode_y = mode_x end
    if mode_z == nil then mode_z = mode_y end

    meta.assert(
        mode_x, rt.TextureWrapMode,
        mode_y, rt.TextureWrapMode,
        mode_z, rt.TextureWrapMode
    )

    for texture in range(
        self._native,
        self._depth,
        self._stencil,
        self._depth_stencil
    ) do
        texture:setWrap(mode_x, mode_y, mode_z)
    end
end

--- @brief
function rt.RenderTexture:get_size()
    if self._type == rt.TextureType.NORMAL then
        return self._native:getDimensions()
    elseif self._type == rt.TextureType.VOLUME then
        local w, h = self._native:getDimensions()
        local depth = self._native:getDepth()
        return w, h, depth
    elseif self._type == rt.TextureType.ARRAY then
        local w, h = self._native:getDimensions()
        local n_layers = self._native:getLayerCount()
        return w, h, n_layers
    end
end

--- @brief bind texture as render target, needs to be unbound manually later
function rt.RenderTexture:bind(array_layer_i)
    local to_bind
    if self._type == rt.TextureType.ARRAY
        or self._type == rt.TextureType.VOLUME
    then
        meta.assert(array_layer_i, mt.Number)
        to_bind = {
            self._native,
            layer = array_layer_i
        }
    else
        to_bind = self._native
    end

    love.graphics.push("all")
    if self._depth_stencil ~= nil then
        love.graphics.setCanvas({
            [1] = to_bind,
            depthstencil = self._depth_stencil
        })
    elseif self._stencil ~= nil then
        love.graphics.setCanvas({
            [1] = to_bind,
            depthstencil = self._stencil
        })
    elseif self._depth ~= nil then
        love.graphics.setCanvas({
            [1] = to_bind,
            depthstencil = self._depth
        })
    else
        love.graphics.setCanvas({
            [1] = to_bind
        })
    end
end

--- @brief unbind texture
function rt.RenderTexture:unbind()
    love.graphics.pop()
end

--- @brief
function rt.RenderTexture:replace_data(image)
    meta.assert(image, rt.Image)
    self._native:replacePixels(image:get_native())
end
