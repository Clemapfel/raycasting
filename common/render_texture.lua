require "common.texture"

rt._render_texture_dummy = love.graphics.newCanvas(1, 1)

-- @class rt.RenderTexture
--- @param width Number
--- @param height Number
--- @param msaa Number?
--- @param format rt.TextureFormat?
--- @param is_compue boolean?
rt.RenderTexture = meta.class("RenderTexture", rt.Texture)

--- @brief
function rt.RenderTexture:instantiate(width, height, msaa, format, is_compute)
    if width == nil and height == nil then
        meta.install(self, {
            _native = rt._render_texture_dummy,
            _width = 1,
            _height = 1,
            _is_valid = false,
        })
        return
    end

    msaa = msaa or 0
    meta.install(self, {
        _native = love.graphics.newCanvas(width or 1, height or 1, {
            msaa = msaa or false,
            format = format,
            computewrite = is_compute or false
        }),
        _width = width,
        _height = height,
        _is_valid = true
    })
    self:set_scale_mode(rt.TextureScaleMode.NEAREST)
    self:set_wrap_mode(rt.TextureWrapMode.CLAMP)
end

--- @brief bind texture as render target, needs to be unbound manually later
function rt.RenderTexture:bind()
    self._before = love.graphics.getCanvas()
    if self._before == self._native then self._before = nil end
    love.graphics.setCanvas({ self._native, stencil = true })
end

--- @brief unbind texture
function rt.RenderTexture:unbind()
    if self._before ~= nil then
        love.graphics.setCanvas({ self._before, stencil = true })
    else
        love.graphics.setCanvas(nil)
    end
    self._before = nil
end

--- @brief
function rt.RenderTexture:as_image()
    if love.getVersion() >= 12 then
        return rt.Image(love.graphics.readbackTexture(self._native))
    else
        return rt.Image(self._native:newImageData())
    end
end

--- @brief
function rt.RenderTexture:free()
    if self._is_valid == false then return end
    assert(self._native:release(), "RenderTexture was already released")
end
