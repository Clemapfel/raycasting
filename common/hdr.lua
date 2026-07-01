require "common.texture_format"
require "common.internal_resolution"

rt.settings.hdr = {
    texture_format = rt.TextureFormat.RG11B10F
}

--- @class rt.HDR
rt.HDR = meta.class("HDR")

local _shader = rt.Shader("common/hdr_tonemap.glsl")

--- @brief
function rt.HDR:instantiate(...)
    self:reinitialize(...)
end

--- @brief
function rt.HDR:reinitialize(width, height)
    meta.assert(width, mt.Number, height, mt.Number)

    if self._texture == nil
        or self._texture:get_width() ~= width
        or self._texture:get_height() ~= height
        or self._texture:get_msaa() ~= rt.GameState:get_msaa_quality()
    then
        self._texture = rt.RenderTexture(
            width, height,
            rt.GameState:get_msaa_quality(),
            rt.settings.hdr.texture_format
        )

        self._mesh = rt.MeshRectangle(
            0, 0,
            love.graphics.getWidth(), love.graphics.getHeight()
        )

        self._mesh:set_texture(self._texture)
        self._mesh_width = love.graphics.getWidth()
        self._mesh_height = love.graphics.getHeight()
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
    if self._mesh == nil
        or self._mesh_width ~= love.graphics.getWidth()
        or self._mesh_height ~= love.graphics.getHeight()
    then
        self._mesh = rt.MeshRectangle(
            0, 0,
            love.graphics.getWidth(), love.graphics.getHeight()
        )

        self._mesh:set_texture(self._texture)
        self._mesh_width = love.graphics.getWidth()
        self._mesh_height = love.graphics.getHeight()
    end

    local use_hdr = rt.GameState:get_is_hdr_enabled()
    local use_mesh = rt.GameState:get_internal_resolution_scaling() ~= rt.InternalResolutionScaling.NONE

    love.graphics.push("all")
    love.graphics.origin()

    if use_hdr then
        _shader:bind()
    end

    love.graphics.setColor(1, 1, 1, 1)

    if use_mesh then
        self._mesh:draw()
    else
        self._texture:draw()
    end

    if use_hdr then
        _shader:unbind()
    end

    love.graphics.pop()
end

--- @brief
function rt.HDR:get_native()
    return self._texture:get_native()
end

--- @brief
function rt.HDR:get_msaa()
    return self._texture:get_msaa()
end

--- @brief
function rt.HDR:get_width()
    return self._texture:get_width()
end

--- @brief
function rt.HDR:get_height()
    return self._texture:get_height()
end

--- @brief
function rt.HDR:get_size()
    return self._texture:get_size()
end