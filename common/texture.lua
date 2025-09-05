require "common.drawable"
require "common.texture_format"
require "common.shader"

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

local _default_shader = rt.Shader("common/texture.glsl")

--- @overload rt.Drawable.draw
function rt.Texture:draw(...)
    local default_shader_bound = false
    if love.graphics.getShader() == nil then
        _default_shader:bind()
        default_shader_bound = true
    end

    love.graphics.draw(self._native, ...)

    if default_shader_bound == true then
        _default_shader:unbind()
    end
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
