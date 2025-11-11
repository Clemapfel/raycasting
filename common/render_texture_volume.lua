require "common.texture"
require "common.image"

rt._render_texture_dummy = love.graphics.newCanvas(1, 1)

-- @class rt.RenderTextureVolume
--- @param width Number
--- @param height Number
--- @param depth Number
--- @param msaa Number?
--- @param format rt.TextureFormat?
--- @param is_compue boolean?
rt.RenderTextureVolume = meta.class("RenderTextureVolume", rt.Texture)

--- @brief
function rt.RenderTextureVolume:instantiate(width, height, depth, msaa, format, is_compute, use_mipmaps)
    msaa = msaa or 0
    meta.install(self, {
        _native = love.graphics.newCanvas(width or 1, height or 1, {
            msaa = msaa or 0,
            format = format, -- if nil, love default
            computewrite = is_compute or true,
            mipmaps = use_mipmaps and "auto" or "none",
            readable = true,
            type = "volume"
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
function rt.RenderTextureVolume:get_size()
    local width, height = self._native:getDimensions()
    local depth = self._native:getDepth()
    return width, height, depth
end

--- @brief
function rt.RenderTextureVolume:bind()
    love.graphics.push("all")
    self._before = love.graphics.getCanvas()
    if self._before == self._native then self._before = nil end
    love.graphics.setCanvas({ self._native, stencil = true })
end

--- @brief unbind texture
function rt.RenderTextureVolume:unbind()
    if self._before ~= nil then
        love.graphics.setCanvas({ self._before, stencil = true })
    else
        love.graphics.setCanvas(nil)
    end
    self._before = nil
    love.graphics.pop()
end

--- @brief
function rt.RenderTextureVolume:free()
    if self._is_valid == false then return end
    rt.assert(self._native:release(), "RenderTextureVolume was already released")
end
