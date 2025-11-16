require "common.texture"
require "common.image"

rt._render_texture_dummy = love.graphics.newCanvas(1, 1)

-- @class rt.RenderTextureArray
--- @param width Number
--- @param height Number
--- @param depth Number
--- @param msaa Number?
--- @param format rt.TextureFormat?
--- @param is_compue boolean?
rt.RenderTextureArray = meta.class("RenderTextureArray", rt.Texture)

--- @brief
function rt.RenderTextureArray:instantiate(width, height, depth, msaa, format, is_compute, use_mipmaps)
    msaa = msaa or 0
    meta.install(self, {
        _native = love.graphics.newArrayImage(width or 1, height or 1, depth or 1, {
            msaa = msaa or 0,
            format = format, -- if nil, love default
            computewrite = is_compute or true,
            mipmaps = use_mipmaps and "auto" or "none",
            readable = true,
            type = "array"
        }),
        _width = width,
        _height = height,
        _depth = depth,
        _is_valid = true
    })
    self:set_scale_mode(rt.TextureScaleMode.LINEAR)
    self:set_wrap_mode(rt.TextureWrapMode.CLAMP)
end

--- @brief
function rt.RenderTextureArray:get_size()
    local width, height = self._native:getDimensions()
    local depth = self._native:getLayerCount()
    return width, height, depth
end

--- @brief
function rt.RenderTextureArray:bind(layer_i)
    if layer_i == nil then layer_i = 1 end
    love.graphics.push("all")
    self._before = love.graphics.getCanvas()
    if self._before == self._native then self._before = nil end
    love.graphics.setCanvas({ { self._native, layer = layer_i or 1 }, stencil = true })
end

--- @brief unbind texture
function rt.RenderTextureArray:unbind()
    if self._before ~= nil then
        love.graphics.setCanvas({ self._before, stencil = true })
    else
        love.graphics.setCanvas(nil)
    end

    self._before = nil
    love.graphics.pop()
end

--- @brief
function rt.RenderTextureArray:free()
    if self._is_valid == false then return end
    rt.assert(self._native:release(), "RenderTextureArray was already released")
    self._is_valid = false
end
