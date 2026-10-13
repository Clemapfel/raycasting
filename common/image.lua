require "common.texture_format"

--- @class rt.Image
rt.Image = meta.class("Image")

--- @enum ImageEncodingFormat
rt.ImageEncodingFormat = {
    PNG = "png",
    TARGA = "tga",
    EXR = "exr"
}
rt.ImageEncodingFormat = meta.enum("ImageEncodingFormat", rt.ImageEncodingFormat)

--- @brief
function rt.Image:instantiate(width_or_userdata, height, format)

    require "common.debugger"
    if meta.is_userdata(width_or_userdata) then
        local userdata = width_or_userdata
        meta.assert(
            userdata, mt.UserData,
            height, mt.Nil,
            format, mt.Nil
        )

        rt.assert(meta.is_function(userdata.typeOf) and userdata:typeOf("ImageData") == true, "Argument #1 is not a `love.ImageData`")
        self._native = userdata
    else
        local width = width_or_userdata
        if format == nil then format = rt.TextureFormat.NORMAL end
        meta.assert(
            width, mt.Number,
            height, mt.Number,
            format, rt.TextureFormat
        )
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
function rt.Image:save_to(path, encoding_format)
    if encoding_format == nil then encoding_format = rt.ImageEncodingFormat.PNG end
    meta.assert(path, mt.String, encoding_format, rt.ImageEncodingFormat)
    self._native:encode(encoding_format, path)
end

--- @brief
function rt.Image:create_texture()
    return rt.Texture(love.graphics.newImage(self._native))
end
