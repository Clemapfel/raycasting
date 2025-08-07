require "common.texture_format"

--- @class rt.Image
rt.Image = meta.class("Image")

--- @brief
function rt.Image:instantiate(data_or_w, h, format)
    if type(data_or_w) == "userdata" and data_or_w:typeOf("ImageData") then
        self._native = data_or_w
    else
        meta.assert(data_or_w, "Number", h, "Number")
        self._native = love.image.newImageData(data_or_w, h, format)
    end
end

--- @brief
function rt.Image:get(x, y)
    return self._native:getPixel(x - 1, y - 1)
end

--- @brief
function rt.Image:set(x, y, r, g, b, a)
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
