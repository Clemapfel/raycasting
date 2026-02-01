rt.settings.bloom = {
    default_blur_strength = 1.2,
    default_composite_strength = 0.1,
    msaa = 0,
    texture_format = rt.TextureFormat.RG11B10F,
}

--- @class rt.Bloom
rt.Bloom = meta.class("Bloom")

local _downsample_shader = rt.Shader("common/bloom_downsample.glsl")
local _upsample_shader = rt.Shader("common/bloom_upsample.glsl")
local _tonemap_shader = rt.Shader("common/bloom_tone_map.glsl")

--- @brief
function rt.Bloom:instantiate(width, height, padding)
    self._bloom_strength = rt.settings.bloom.default_blur_strength

    self._padding = padding or 0
    width = width + 2 * padding
    height = height + 2 * padding

    self._textures = {}
    self._meshes = {}
    do -- init textures
        local w, h = width, height
        local level = 1
        while (w > 8 or h > 8) do
            local mesh = rt.MeshRectangle(0, 0, w, h)
            local texture = rt.RenderTexture(w, h, rt.settings.bloom.msaa, rt.settings.bloom.texture_format)
            mesh:set_texture(texture)
            texture:set_wrap_mode(rt.TextureWrapMode.CLAMP)
            texture:set_scale_mode(rt.TextureScaleMode.LINEAR, rt.TextureScaleMode.LINEAR)
            table.insert(self._textures, texture)
            table.insert(self._meshes, mesh)

            level = level + 1
            w = math.max(1, math.floor(w / 2))
            h = math.max(1, math.floor(h / 2))
        end
    end

    self._update_needed = true
end

local _before
local lg = love.graphics

--- @brief
function rt.Bloom:_bind_padding()
    -- why is this not necessary?
    --love.graphics.translate(-self._padding, -self._padding)
end

--- @brief
function rt.Bloom:bind()
    love.graphics.push("all")
    self:_bind_padding()
    self._textures[1]:bind()
end

--- @brief
function rt.Bloom:unbind()
    self._textures[1]:unbind()
    love.graphics.pop()
    self._update_needed = true
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
    local lg = love.graphics
    local n_levels = #self._textures

    love.graphics.push("all")
    love.graphics.origin()

    -- downsample
    for level = 2, n_levels do
        local source = self._textures[level - 1]
        local destination = self._textures[level]
        local mesh = self._meshes[level]

        _downsample_shader:bind()
        _downsample_shader:send("texel_size", { 1 / destination:get_width(), 1 / destination:get_height()})

        destination:bind()
        love.graphics.clear(0, 0, 0, 0)

        mesh:set_texture(source)
        mesh:draw()

        destination:unbind()

        _downsample_shader:unbind()
    end

    -- upsample
    for level = n_levels, 2, -1 do
        local source = self._textures[level]
        local destination = self._textures[level - 1]
        local mesh = self._meshes[level - 1]

        _upsample_shader:bind()

        _upsample_shader:send("texel_size", { 1 / destination:get_width(), 1 / destination:get_height()})
        _upsample_shader:send("bloom_strength", self._bloom_strength)
        _upsample_shader:send("current_mip", destination:get_native())

        destination:bind()

        if level - 1 > 1 then
            love.graphics.clear(0, 0, 0, 0)
        end

        mesh:set_texture(source)
        mesh:draw()

        destination:unbind()

        _upsample_shader:unbind()
    end

    love.graphics.pop()
end

--- @brief
function rt.Bloom:composite(strength)
    if strength == nil then strength = rt.settings.bloom.default_composite_strength end
    love.graphics.push("all")
    self:_bind_padding()
    love.graphics.setBlendMode("add", "premultiplied")
    love.graphics.setColor(strength, strength, strength, strength)

    self:draw_internal()

    love.graphics.setBlendMode("alpha")
    love.graphics.pop()
end

--- @brief
function rt.Bloom:draw_internal()
    if self._update_needed then
        self:_apply_bloom()
        self._update_needed = false
    end

    if rt.GameState:get_is_hdr_enabled() then
        love.graphics.draw(self._textures[1]:get_native())
    else
        _tonemap_shader:bind()
        love.graphics.draw(self._textures[1]:get_native())
        _tonemap_shader:unbind()
    end
end

--- @brief
function rt.Bloom:draw()
    local r, g, b, a = love.graphics.getColor()

    love.graphics.push("all")
    self:_bind_padding()
    love.graphics.setColor(r, g, b, a)
    self:draw_internal()
    love.graphics.pop()
end

--- @brief
function rt.Bloom:get_size()
    return self._textures[1]:get_size()
end