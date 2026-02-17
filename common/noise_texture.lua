--- @class rt.NoiseTexture
rt.NoiseTexture = meta.class("NoiseTexture")

local _shader = rt.Shader("common/noise_texture.glsl")

local _n_scales_to_texture_format = {
    [1] = rt.TextureFormat.R8,
    [2] = rt.TextureFormat.RG8,
    [3] = rt.TextureFormat.RG11B10F,
    [4] = rt.TextureFormat.RGBA8
}

--- @class rt.NoiseType
rt.NoiseType = {
    GRADIENT = 0x0,
    WORLEY = 0x1,
    SIMPLEX = 0x2
}

rt.NoiseType = meta.enum("NoiseType", rt.NoiseType)

--- @brief
function rt.NoiseTexture:instantiate(width, ...)
    meta.assert_typeof(width, "Number", 1)
    self._width = width

    self._types = {
        rt.NoiseType.GRADIENT,
        rt.NoiseType.GRADIENT,
        rt.NoiseType.GRADIENT,
        rt.NoiseType.GRADIENT
    }
    self._scales = {
        1,
        1,
        1,
        1
    }

    local component_i = 1
    for i = 1, select("#", ...), 2 do
        local type = select(i, ...)
        local scale = select(i+1, ...)

        meta.assert_enum_value(type, rt.NoiseType, 1 + i)
        meta.assert_typeof(scale, "Number", 1 + i + 1)
        self._types[component_i] = type
        self._scales[component_i] = scale

        component_i = component_i + 1
    end

    self._n_components = component_i - 1

    self._texture = rt.RenderTexture(width, width, 0, _n_scales_to_texture_format[self._n_componens])
    self._texture:set_wrap_mode(rt.TextureWrapMode.REPEAT)
    local seed = meta.hash(self)
    love.graphics.push("all")
    love.graphics.reset()
    self._texture:bind()
    _shader:bind()
    _shader:send("seed", meta.hash(self) * math.pi)
    _shader:send("scales", self._scales)
    _shader:send("types", self._types)
    _shader:send("n_components", self._n_components)
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.rectangle("fill", 0, 0, width, width)
    _shader:unbind()
    self._texture:unbind()
    love.graphics.pop()
end

--- @brief
function rt.NoiseTexture:draw(...)
    if _temp == nil then _temp = love.graphics.newShader([[
    uniform float elapsed;
    vec4 effect(vec4 color, sampler2D tex, vec2 texture_coords, vec2 ___) {
        return texture(tex, texture_coords + elapsed / 5);
    }
    ]])
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.clear(0, 0, 0, 1)

    love.graphics.setShader(_temp)
    _temp:send("elapsed", rt.SceneManager:get_elapsed())
    self._texture:draw()
    love.graphics.setShader(nil)
end
