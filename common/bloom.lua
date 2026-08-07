rt.settings.bloom = {
    default_blur_strength = 1.5,
    default_composite_strength = 0.11,
    msaa = 2,
    texture_format = rt.TextureFormat.RG11B10F,
}

--- @class rt.Bloom
rt.Bloom = meta.class("Bloom")

local _downsample_shader, _upsample_shader
local _tonemap_shader = rt.Shader("common/bloom_tone_map.glsl")

--- @brief
function rt.Bloom:instantiate(width, height)
    self._bloom_strength = rt.settings.bloom.default_blur_strength

    local quality = rt.GameState:get_bloom_quality()
    self._bloom_quality = quality

    local kernel_size, skip_downscale, skip_upscale;

    if quality == rt.BloomQuality.LOWEST then
        kernel_size, skip_downscale, skip_upscale = 3, true, true
    elseif quality == rt.BloomQuality.LOW then
        kernel_size, skip_downscale, skip_upscale = 3, true, false
    elseif quality == rt.BloomQuality.NORMAL then
        kernel_size, skip_downscale, skip_upscale = 5, true, false
    elseif quality == rt.BloomQuality.BETTER then
        kernel_size, skip_upscale, skip_upscale = 5, false, false
    elseif quality == rt.BloomQuality.BEST then
        kernel_size, skip_upscale, skip_downscale = 7, true, false
    end

    self._kernel_size = kernel_size
    self._skip_downscale = skip_downscale
    self._skip_upscale = skip_upscale

    _downsample_shader = rt.Shader("common/bloom_downsample.glsl", { KERNEL_SIZE = self._kernel_size })
    _upsample_shader = rt.Shader("common/bloom_upsample.glsl", { KERNEL_SIZE = self._kernel_size })

    self._textures = {}
    self._meshes = {}
    do -- init textures
        local w, h = width, height
        local level = 1
        while (w > 8 or h > 8) do
        local mesh = rt.MeshRectangle(0, 0, w, h)
        local texture = rt.RenderTexture(w, h, {
            msaa = rt.settings.bloom.msaa,
            format = rt.settings.bloom.texture_format,
            is_compute = level == 1,
            has_stencil = true,
            has_depth = true
        })

        mesh:set_texture(texture)
        texture:set_wrap_mode(rt.TextureWrapMode.ZERO)
        texture:set_scale_mode(rt.TextureScaleMode.LINEAR, rt.TextureScaleMode.LINEAR)
        table.insert(self._textures, texture)
        table.insert(self._meshes, mesh)

        level = level + 1
        w = math.max(1, math.floor(w / 2))
        h = math.max(1, math.floor(h / 2))
        end
    end

    self._update_needed = true
    self._flush_manually = false
end

local _before
local lg = love.graphics

--- @brief
function rt.Bloom:bind()
    if self._bloom_quality ~= rt.GameState:get_bloom_quality() then
        self:instantiate(self._width, self._height)
    end

    love.graphics.push("all")
    self._textures[1]:bind()
end

--- @brief
function rt.Bloom:unbind()
    self._textures[1]:unbind()
    love.graphics.pop()
    self._update_needed = true
end

--- @brief
function rt.Bloom:flush()
    if self._update_needed and not self._flush_manually then
        self:_apply_bloom()
        self._update_needed = false
    end
end

--- @brief
function rt.Bloom:set_bloom_strength(strength)
    self._bloom_strength = math.max(strength, 0)
    self._update_needed = true
end

--- @brief
function rt.Bloom:get_bloom_strength(strength)
    return self._bloom_strength
end

function rt.Bloom:_apply_bloom()
    local n_levels = #self._textures

    local manual_copy = function(from_level, to_level)
        local from = self._textures[from_level]
        local to = self._textures[to_level]

        love.graphics.push()
        to:bind()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.scale(
            to:get_width() / from:get_width(),
            to:get_width() / from:get_width()
        )
        from:draw()
        to:unbind()
        love.graphics.pop()
    end

    love.graphics.push("all")
    love.graphics.reset()

    local downsample_n_manual = ternary(self._skip_downscale, 1, 0)
    local upscale_n_manual = ternary(self._skip_upscale, 1, 0)

    -- one non-shader downsample step that uses antialiased scaling for blur
    -- this save an expensive screens-sized texture 25-tap
    for to_level = 2, 2 + downsample_n_manual do
        manual_copy(to_level - 1, to_level)
    end

    -- downsample
    _downsample_shader:bind()
    for level = 2 + downsample_n_manual, n_levels do
        local source = self._textures[level - 1] -- Table<love.Canvas>
        local destination = self._textures[level]
        local mesh = self._meshes[level]

        _downsample_shader:send("texel_size", { 1 / destination:get_width(), 1 / destination:get_height()})

        destination:bind()
        love.graphics.clear(0, 0, 0, 0)

        mesh:set_texture(source)
        mesh:draw()

        destination:unbind()
    end

    _downsample_shader:unbind()

    -- upsample
    _upsample_shader:bind()
    _upsample_shader:send("bloom_strength", self._bloom_strength)
    love.graphics.setBlendMode("add", "premultiplied")

    for level = n_levels, 2 + upscale_n_manual, -1 do
        local source = self._textures[level]
        local destination = self._textures[level - 1]
        local mesh = self._meshes[level - 1]

        _upsample_shader:send("texel_size", { 1 / destination:get_width(), 1 / destination:get_height()})

        destination:bind()

        mesh:set_texture(source)
        mesh:draw()

        destination:unbind()
    end
    _upsample_shader:unbind()

    for level = 2 + upscale_n_manual, 2, -1 do
        manual_copy(level, level - 1)
    end

    love.graphics.pop()
end

--- @brief
function rt.Bloom:composite(strength)
    if strength == nil then strength = rt.settings.bloom.default_composite_strength end
    love.graphics.push("all")
    love.graphics.setBlendMode("add", "premultiplied")
    love.graphics.setColor(strength, strength, strength, strength)

    self:draw_internal()

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

--- @brief
function rt.Bloom:draw_internal()
    self:flush()

    if rt.GameState:get_is_hdr_enabled() then
        love.graphics.draw(self._textures[1]:get_native())
    else
        _tonemap_shader:bind()
        love.graphics.draw(self._textures[1]:get_native())
        _tonemap_shader:unbind()
    end
end

--- @brief
function rt.Bloom:get_texture()
    return self._textures[1]
end

--- @brief
function rt.Bloom:draw()
    local r, g, b, a = love.graphics.getColor()

    love.graphics.push("all")
    love.graphics.setColor(r, g, b, a)
    self:draw_internal()
    love.graphics.pop()
end

--- @brief
function rt.Bloom:get_size()
    return self._textures[1]:get_size()
end

--- @brief
function rt.Bloom:get_width()
    return self._textures[1]:get_width()
end

--- @brief
function rt.Bloom:get_height()
    return self._textures[1]:get_height()
end

--- @brief
function rt.Bloom:get_should_flush_manually()
    return self._flush_manually
end

--- @brief
function rt.Bloom:set_should_flush_manually(b)
    meta.assert(b, mt.Boolean)
    self._flush_manually = b
end

--- @brief
function rt.Bloom:reset()
    love.graphics.push("all")
    for texture in values(self._textures) do
        texture:bind()
        love.graphics.clear(0, 0, 0, 0)
        texture:unbind()
    end
    love.graphics.pop()
    self._update_needed = true
end
