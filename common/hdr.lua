require "common.texture_format"

rt.settings.hdr = {
    texture_format = rt.TextureFormat.RG11B10F
}

--- @class rt.HDR
rt.HDR = meta.class("HDR")

local _shader = rt.Shader("common/hdr_tonemap.glsl")

DEBUG_INPUT:signal_connect("keyboard_key_released", function(_, which)
    if which == "l" then
        _shader:recompile()
    end
end)

--- @brief
function rt.HDR:instantiate()
    self:reinitialize()
end

--- @brief
function rt.HDR:reinitialize(width, height, format)
    width = width or love.graphics.getWidth()
    height = height or love.graphics.getHeight()
    format = format or rt.settings.hdr.texture_format
    if self._texture == nil
        or self._texture:get_width() ~= width
        or self._texture:get_height() ~= height
        or self._texture:get_msaa() ~= rt.GameState:get_msaa_quality()
        or self._texture:get_format() ~= format
    then
        self._texture = rt.RenderTexture(
            width, height,
            rt.GameState:get_msaa_quality(),
            format
        )
    end
end

--- @brief
function rt.HDR:bind()
    self._texture:bind()
end

--- @brief
function rt.HDR:unbind()
    self._texture:unbind()
end

--- @brief
function rt.HDR:draw()
    _shader:bind()
    love.graphics.setColor(1, 1, 1, 1)
    self._texture:draw()
    _shader:unbind()
end