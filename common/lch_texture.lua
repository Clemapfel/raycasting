require "common.texture"
require "common.image"

rt.settings.lch_texture = {
    texture_format = rt.TextureFormat.RGB10A2,
    lightness_default = 0.8,
    chroma_default = 1,
    hue_default = 0
}

--- @class rt.LCHTexture
rt.LCHTexture = meta.class("LCHTexture")

local _atlas = {}

--[[
// shader usage
uniform sampler3D lch_texture;
vec3 lch_to_rgb(vec3 lch) {
    return texture3D(lch_texture, lch).rgb;
}
]]

--- @brief
function rt.LCHTexture:instantiate(n_lightness_steps, n_chroma_steps, n_hue_steps)
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
    if _atlas[n_lightness_steps] == nil then _atlas[n_lightness_steps] = {} end
    if _atlas[n_lightness_steps][n_chroma_steps] == nil then _atlas[n_lightness_steps][n_chroma_steps] = {} end

    local cached = _atlas[n_lightness_steps][n_chroma_steps][n_hue_steps]
    if cached == nil then
        self:_initialize()
        _atlas[n_lightness_steps][n_chroma_steps][n_hue_steps] = self._texture
    else
        self._texture = cached
    end
end

--- @brief
function rt.LCHTexture:_initialize()
    local lightness_default = rt.settings.lch_texture.lightness_default
    local chroma_default = rt.settings.lch_texture.chroma_default
    local hue_default = rt.settings.lch_texture.hue_default

    local layers = {}
    for hue_step = 1, self._n_hue_steps do
        local layer = rt.Image(self._n_lightness_steps, self._n_chroma_steps, rt.settings.lch_texture.texture_format)

        for chroma_step = 1, self._n_chroma_steps do
            for lightness_step = 1, self._n_lightness_steps do
                local lightness, chroma, hue

                if self._n_lightness_steps > 1 then
                    lightness = (lightness_step - 1) / (self._n_lightness_steps - 1)
                else
                    lightness = lightness_default
                end

                if self._n_chroma_steps > 1 then
                    chroma = (chroma_step - 1) / (self._n_chroma_steps - 1)
                else
                    chroma = chroma_default
                end

                if self._n_hue_steps > 1 then
                    hue = (hue_step - 1) / (self._n_hue_steps - 1)
                else
                    hue = hue_default
                end

                local r, g, b, a = rt.lcha_to_rgba(lightness, chroma, hue, 1)
                layer:set(lightness_step, chroma_step, r, g, b, a) -- sic, 1-based index
            end
        end

        table.insert(layers, layer:get_native())
    end

    self._texture = love.graphics.newVolumeImage(layers, {
        msaa = 0,
        format = rt.settings.lch_texture.texture_format,
        readable = true
    })

    self._texture:setFilter(rt.TextureScaleMode.LINEAR)
    self._texture:setWrap(
        rt.TextureWrapMode.CLAMP,  -- lightness
        rt.TextureWrapMode.CLAMP,  -- chroma
        rt.TextureWrapMode.REPEAT  -- hue
    )
end

--- @brief
function rt.LCHTexture:get_native()
    return self._texture
end

--- @brief
function rt.LCHTexture:get_size()
    return self._texture
end

