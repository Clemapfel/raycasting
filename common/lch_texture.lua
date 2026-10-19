require "common.texture"
require "common.image"
require "common.compute_shader"
require "common.render_texture"

rt.settings.lch_texture = {
    texture_format = rt.TextureFormat.RGB10A2,
    lightness_default = 0.8,
    chroma_default = 1,
    hue_default = 0,
    work_group_size = 8
}

--- @class rt.LCHTexture
rt.LCHTexture = meta.class("LCHTexture")

local _shader = nil
local _cache = nil
local _cache_size_x, _cache_size_y, _cache_size_z = 0, 0, 0

--[[
// shader usage
uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture(lch_texture, lch).rgb;
}
]]

function rt.LCHTexture:instantiate(n_lightness_steps, n_chroma_steps, n_hue_steps)
    local work_group_size = rt.settings.lch_texture.work_group_size
    if _shader == nil then
        require "common.noise_texture"

        _shader = rt.ComputeShader("common/lch_texture.glsl", {
            WORK_GROUP_SIZE_X = work_group_size,
            WORK_GROUP_SIZE_Y = work_group_size,
            WORK_GROUP_SIZE_Z = work_group_size,
            TEXTURE_FORMAT = rt.graphics.texture_format_to_glsl_identifier(rt.settings.lch_texture.texture_format)
        })
    end

    meta.assert(
        n_lightness_steps, mt.Number,
        n_chroma_steps, mt.Number,
        n_hue_steps, mt.Number
    )

    local max_steps = love.graphics.getSystemLimits().texturesize
    max_steps = math.floor(max_steps / work_group_size) * work_group_size

    local function round(n)
        n = math.ceil(n / work_group_size) * work_group_size
        return math.clamp(n, work_group_size, max_steps)
    end

    n_lightness_steps = round(n_lightness_steps)
    n_chroma_steps = round(n_chroma_steps)
    n_hue_steps = round(n_hue_steps)

    if n_lightness_steps > _cache_size_x
        or n_chroma_steps > _cache_size_y
        or n_hue_steps > _cache_size_z
    then
        _cache_size_x = math.max(_cache_size_x, n_lightness_steps)
        _cache_size_y = math.max(_cache_size_y, n_chroma_steps)
        _cache_size_z = math.max(_cache_size_z, n_hue_steps)
        rt.LCHTexture._initialize_cache(_cache_size_x, _cache_size_y, _cache_size_z)
    end
end

--- @brief
function rt.LCHTexture._initialize_cache(size_x, size_y, size_z)
    _cache = rt.RenderTextureVolume(size_x, size_y, size_z, {
        msaa = 0,
        format = rt.settings.lch_texture.texture_format,
        is_compute = true
    })
    _cache:set_scale_mode(rt.TextureScaleMode.LINEAR)
    _cache:set_wrap_mode(
        rt.TextureWrapMode.CLAMP,  -- lightness
        rt.TextureWrapMode.CLAMP,  -- chroma
        rt.TextureWrapMode.REPEAT  -- hue
    )

    local work_group_size = rt.settings.noise_texture.work_group_size
    _shader:send("lightness_default", rt.settings.lch_texture.lightness_default)
    _shader:send("chroma_default", rt.settings.lch_texture.chroma_default)
    _shader:send("hue_default", rt.settings.lch_texture.hue_default)
    _shader:send("output_texture", _cache)
    _shader:dispatch(
        size_x / work_group_size,
        size_y / work_group_size,
        size_z / work_group_size
    )
end

--- @brief
function rt.LCHTexture:get_native()
    return _cache:get_native()
end

--- @brief
function rt.LCHTexture:get_size()
    return _cache:get_size()
end

