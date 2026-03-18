require "common.texture"
require "common.image"

rt.settings.hue_map_texture = {
    texture_format = rt.TextureFormat.RGB565
}

--- @class rt.HueMapTexture
rt.HueMapTexture = meta.class("HueMapTexture")

local _atlas = {}

--[[
// shader usage
uniform sampler2D hue_map;
vec4 color = texture(hue_map, vec2(hue, 0))
]]

--- @brief
function rt.HueMapTexture:instantiate(lightness, chroma, n_hue_steps)
    meta.assert(lightness, "Number", chroma, "Number", n_hue_steps, "Number")
    self._lightness = lightness
    self._chroma = chroma
    self._n_hue_steps = n_hue_steps

    -- caching
    if _atlas[lightness] == nil then _atlas[lightness] = {} end
    if _atlas[lightness][chroma] == nil then _atlas[lightness][chroma] = {} end

    local cached = _atlas[lightness][chroma][n_hue_steps]
    if cached == nil then
        self:_initialize()
        _atlas[lightness][chroma][n_hue_steps] = self._texture
    else
        self._texture = cached
    end
end

--- @brief
function rt.HueMapTexture:_initialize()
    local data = rt.Image(self._n_hue_steps, 1, rt.settings.hue_map_texture.texture_format)
    for i = 1, self._n_hue_steps do
        local r, g, b, a = rt.lcha_to_rgba(
            self._lightness,
            self._chroma,
            (i - 1) / self._n_hue_steps
        )

        data:set(i, 1, r, g, b, a)
    end

    self._texture = rt.Texture(data:get_native())
    self._texture:set_scale_mode(rt.TextureScaleMode.LINEAR)
end

--- @brief
function rt.HueMapTexture:get_native()
    return self._texture:get_native()
end

--- @brief
function rt.HueMapTexture:get_size()
    return self._texture:get_size()
end

