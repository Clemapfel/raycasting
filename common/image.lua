require "common.texture_format"

--- @class rt.Image
rt.Image = meta.class("Image")

--- @brief
function rt.Image:instantiate(...)
    local first = select(1, ...)
    if first ~= nil and meta.is_function(first.typeOf) and first.typeOf("ImageData") == true then
        self._native = first
    else
        self._native = love.image.newImageData(...)
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

--- @brief
function rt.Image:save_to(path)
    self._native:encode("png", path)
end
