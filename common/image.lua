require "common.texture_format"

--- @class rt.Image
rt.Image = meta.class("Image")

--- @brief
function rt.Image:instantiate(width, height, format)
    if format == nil then format = rt.TextureFormat.NORMAL end
    meta.assert(
        width, mt.Union(mt.Number, mt.UserData),
        height, mt.Number,
        format, mt.Optional(rt.TextureFormat)
    )

    local first = width
    if meta.is_userdata(first) and meta.is_function(first.typeOf) and first:typeOf("ImageData") == true then
        self._native = first
    else
        meta.assert(width, mt.Number)
        self._native = love.image.newImageData(width, height, format)
    end
end

--- @brief
function rt.Image:get(x, y)
    return self._native:getPixel(x - 1, y - 1)
end

--- @brief
function rt.Image:set(x, y, r, g, b, a)
    if r == nil then r = 0 end
    if g == nil then g = 0 end
    if b == nil then b = 0 end
    if a == nil then a = 1 end
    self._native:setPixel(x - 1, y - 1, r, g, b, a)
end

--- @brief
function rt.Image:get_native()
    return self._native
end

--- @brief
function rt.Image:get_data()
    return self._native:getFFIPointer()
end

--- @brief
function rt.Image:get_size()
    return self._native:getDimensions()
end

--- @brief
function rt.Image:get_width()
    return select(1, self:get_size())
end

--- @brief
function rt.Image:get_height()
    return select(2, self:get_size())
end

--- @brief
function rt.Image:save_to(path)
    self._native:encode("png", path)
end

--- @brief
function rt.Image:create_texture()
    return rt.Texture(love.graphics.newImage(self._native))
end
