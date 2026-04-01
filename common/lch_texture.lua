require "common.texture"
require "common.image"
require "common.compute_shader"
require "common.render_texture_volume"

rt.settings.lch_texture = {
    texture_format = rt.TextureFormat.RGB10A2,
    lightness_default = 0.8,
    chroma_default = 1,
    hue_default = 0
}

--- @class rt.LCHTexture
rt.LCHTexture = meta.class("LCHTexture")

local _atlas = {}
local _shader = nil

--[[
// shader usage
uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture(lch_texture, lch).rgb;
}
]]

--- @brief
function rt.LCHTexture:instantiate(n_lightness_steps, n_chroma_steps, n_hue_steps)
    if _shader == nil then
        require "common.noise_texture"
        local work_group_size = rt.settings.noise_texture.work_group_size

        _shader = rt.ComputeShader("common/lch_texture.glsl", {
            WORK_GROUP_SIZE_X = work_group_size,
            WORK_GROUP_SIZE_Y = work_group_size,
            WORK_GROUP_SIZE_Z = work_group_size,
            TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(rt.settings.lch_texture.texture_format)
        })
    end

    meta.assert(
        n_lightness_steps, "Number",
        n_chroma_steps, "Number",
        n_hue_steps, "Number"
    )

    local max_steps = love.graphics.getSystemLimits().texturesize - 1

    n_lightness_steps = math.clamp(n_lightness_steps, 1, max_steps)
    n_chroma_steps = math.clamp(n_chroma_steps, 1, max_steps)
    n_hue_steps = math.clamp(n_hue_steps, 1, max_steps)

    self._n_lightness_steps = n_lightness_steps
    self._n_chroma_steps = n_chroma_steps
    self._n_hue_steps = n_hue_steps

    -- caching
    local hash = string.paste(n_lightness_steps, "|", n_chroma_steps, "|", n_hue_steps)
    local cached = _atlas[hash]
    if cached == nil then
        self:_initialize()
        _atlas[hash] = self._texture
    else
        self._texture = cached
    end
end

--- @brief
function rt.LCHTexture:_initialize()
    local size_x, size_y, size_z = self._n_lightness_steps,
        self._n_chroma_steps,
        self._n_hue_steps

    self._texture = rt.RenderTextureVolume(size_x, size_y, size_z, 0, rt.settings.lch_texture.texture_format)
    self._texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
    self._texture:set_wrap_mode(
        rt.TextureWrapMode.CLAMP,  -- lightness
        rt.TextureWrapMode.CLAMP,  -- chroma
        rt.TextureWrapMode.REPEAT  -- hue
    )

    local work_group_size = rt.settings.noise_texture.work_group_size
    _shader:send("lightness_default", rt.settings.lch_texture.lightness_default)
    _shader:send("chroma_default", rt.settings.lch_texture.chroma_default)
    _shader:send("hue_default", rt.settings.lch_texture.hue_default)
    _shader:send("output_texture", self._texture)
    _shader:dispatch(
        size_x / work_group_size,
        size_y / work_group_size,
        size_z / work_group_size
    )
end

--- @brief
function rt.LCHTexture:get_native()
    return self._texture:get_native()
end

--- @brief
function rt.LCHTexture:get_size()
    return self._texture:get_size()
end

