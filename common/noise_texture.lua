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

local _texture_format_to_shader = {} -- cached shaders
local _atlas = {} -- cached volume textures

--- @class rt.NoiseType
rt.NoiseType = meta.enum("NoiseType", {
    GRADIENT = 0x0,
    WORLEY = 0x1
})


--- @brief
function rt.NoiseTexture:instantiate(size_x, size_y, size_z, ...)
    meta.assert_typeof(size_x, "Number", size_y, "Number", size_z, "Number")

    local types  = { rt.NoiseType.GRADIENT, rt.NoiseType.GRADIENT, rt.NoiseType.GRADIENT, rt.NoiseType.GRADIENT }
    local scales = { 1, 1, 1, 1 }

    local n_components = 0
    for i = 1, select("#", ...), 2 do
        local noise_type = select(i, ...)
        local scale = select(i + 1, ...)
        meta.assert_enum_value(noise_type, rt.NoiseType, 3 + i)
        meta.assert_typeof(scale, "Number", 3 + i + 1)
        n_components = n_components + 1
        types[n_components]  = noise_type
        scales[n_components] = scale
    end
    if n_components == 0 then n_components = 1 end

    local texture_format = _n_scales_to_texture_format[n_components]
    assert(texture_format ~= nil)

    local work_group_size = rt.settings.noise_texture.work_group_size
    if _texture_format_to_shader[texture_format] == nil then
        _texture_format_to_shader[texture_format] = rt.ComputeShader("common/noise_texture.glsl", {
            TEXTURE_FORMAT    = texture_format,
            WORK_GROUP_SIZE_X = work_group_size,
            WORK_GROUP_SIZE_Y = work_group_size,
            WORK_GROUP_SIZE_Z = work_group_size
        })
    end

    -- cache key encodes all parameters that affect the computed texture
    local cache_key = { texture_format, "|",  size_x, "|", size_y, "|" , size_z }
    for i = 1, n_components do
        for x in range("|", types[i], "|", scales[i]) do
            table.insert(cache_key, x)
        end
    end

    cache_key = table.concat(cache_key)

    self._n_components = n_components
    self._types = types
    self._scales = scales

    if _atlas[cache_key] ~= nil then
        self._texture = _atlas[cache_key]
        self._shader = _texture_format_to_shader[texture_format]
        return
    end

    self._texture = rt.RenderTextureVolume(size_x, size_y, size_z, 0, texture_format)
    self._texture:set_wrap_mode(
        rt.TextureWrapMode.MIRROR,
        rt.TextureWrapMode.MIRROR,
        rt.TextureWrapMode.REPEAT
    )

    self._shader = _texture_format_to_shader[texture_format]
    self._shader:send("scales",      scales)
    self._shader:send("types",       types)
    self._shader:send("n_components", n_components)
    self._shader:send("noise_texture", self._texture)
    self._shader:dispatch(
        math.ceil(size_x / work_group_size),
        math.ceil(size_y / work_group_size),
        math.ceil(size_z / work_group_size)
    )

    _atlas[cache_key] = self._texture
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