rt.settings.noise_texture = {
    work_group_size = 8
}

--- @class rt.NoiseTexture
rt.NoiseTexture = meta.class("NoiseTexture")

local _n_scales_to_texture_format = {
    [1] = rt.TextureFormat.R8,
    [2] = rt.TextureFormat.RG8,
    [3] = rt.TextureFormat.RGB10A2,
    [4] = rt.TextureFormat.RGBA8
}

local _texture_format_to_shader = {}

--- @class rt.NoiseType
rt.NoiseType = meta.enum("NoiseType", {
    GRADIENT = 0x0,
    WORLEY = 0x1
})

--- @brief
function rt.NoiseTexture:instantiate(size_x, size_y, size_z, ...)
    meta.assert_typeof(size_x, "Number", size_y, "Number", size_z, "Number")

    self._types = {
        rt.NoiseType.GRADIENT,
        rt.NoiseType.GRADIENT,
        rt.NoiseType.GRADIENT,
        rt.NoiseType.GRADIENT
    }

    self._scales = { 1, 1, 1, 1 }

    local component_i = 1
    for i = 1, select("#", ...), 2 do
        local type = select(i, ...)
        local scale = select(i + 1, ...)
        meta.assert_enum_value(type, rt.NoiseType, 3 + i)
        meta.assert_typeof(scale, "Number", 3 + i + 1)
        self._types[component_i] = type
        self._scales[component_i] = scale
        component_i = component_i + 1
    end
    self._n_components = component_i - 1

    local texture_format = _n_scales_to_texture_format[self._n_components]
    assert(texture_format ~= nil)

    self._texture = rt.RenderTextureVolume(size_x, size_y, size_z, 0, texture_format)
    self._texture:set_wrap_mode(
        rt.TextureWrapMode.MIRROR,
        rt.TextureWrapMode.MIRROR,
        rt.TextureWrapMode.REPEAT
    )

    local work_group_size = rt.settings.noise_texture.work_group_size
    if _texture_format_to_shader[texture_format] == nil then
        _texture_format_to_shader[texture_format] = rt.ComputeShader("common/noise_texture.glsl", {
            TEXTURE_FORMAT = texture_format,
            WORK_GROUP_SIZE_X = work_group_size,
            WORK_GROUP_SIZE_Y = work_group_size,
            WORK_GROUP_SIZE_Z = work_group_size
        })
    end

    self._shader = _texture_format_to_shader[texture_format]
    self._shader:send("scales", self._scales)
    self._shader:send("types", self._types)
    self._shader:send("n_components", self._n_components)
    self._shader:send("noise_texture", self._texture)
    self._shader:dispatch(
        math.ceil(size_x / work_group_size),
        math.ceil(size_y / work_group_size),
        math.ceil(size_z / work_group_size)
    )
end

--- @brief
function rt.NoiseTexture:get_native()
    return self._texture:get_native()
end

--- @brief
function rt.NoiseTexture:get_size()
    return self._texture:get_size()
end

local _draw_shader

--- @brief
function rt.NoiseTexture:draw()
    if _draw_shader == nil then _draw_shader = love.graphics.newShader([[
        uniform float elapsed;
        uniform sampler3D tex;
        vec4 effect(vec4 color, sampler2D _, vec2 texture_coords, vec2 screen_coords) {
             vec2 uv = texture_coords;
             return texture(tex, vec3(elapsed / 5, uv.x, uv.y));
        }
        ]])
    end

    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.setShader(_draw_shader)
    _draw_shader:send("elapsed", rt.SceneManager:get_elapsed())
    _draw_shader:send("tex", self._texture:get_native())
    local width, height, depth = self._texture:get_size()
    love.graphics.rectangle("fill", 0, 0, width, height)
    love.graphics.setShader(nil)
end