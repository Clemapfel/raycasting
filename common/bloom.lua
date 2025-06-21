--- @class rt.Bloom
rt.Bloom = meta.class("Bloom")

local _downsample_shader, _upsample_shader

--- @brief
function rt.Bloom:instantiate(width, height, ...)
    if _downsample_shader == nil then _downsample_shader = rt.Shader("common/bloom_downsample.glsl") end
    if _upsample_shader == nil then _upsample_shader = rt.Shader("common/bloom_upsample.glsl") end

    self._bloom_strength = 1
    self._textures = {}
    self._meshes = {}
    do -- init textures
        local w, h = width, height
        local level = 1
        local max_levels = 6
        while (w > 1 or h > 1) and level <= max_levels do
            local mesh = rt.MeshRectangle(0, 0, w, h)
            local texture = rt.RenderTexture(w, h, ...)
            mesh:set_texture(texture)
            texture:set_wrap_mode(rt.TextureWrapMode.CLAMP)
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
function rt.Bloom:bind()
    self._textures[1]:bind()
end

--- @brief
function rt.Bloom:unbind()
    self._textures[1]:unbind()
    self._update_needed = true
end

--- @brief
function rt.Bloom:set_bloom_strength(strength)
    self._bloom_strength = math.clamp(strength, 0, 1)
    self._update_needed = true
end

--- @brief
function rt.Bloom:get_bloom_strength(strength)
    return self._bloom_strength
end

function rt.Bloom:_apply_bloom()
    local lg = love.graphics
    local num_levels = #self._textures

    lg.push()
    lg.origin()

    -- downsample
    for level = 2, num_levels do
        local source = self._textures[level - 1]
        local destination = self._textures[level]
        local mesh = self._meshes[level]

        _downsample_shader:bind()
        _downsample_shader:send("texel_size", { 1 / destination:get_width(), 1 / destination:get_height()})
        _downsample_shader:send("bloom_strength", self._bloom_strength)

        destination:bind()
        lg.clear(0, 0, 0, 0)

        mesh:set_texture(source)
        mesh:draw()

        destination:unbind()
    end

    -- upsample
    for level = num_levels, 2, -1 do
        local source = self._textures[level]
        local destination = self._textures[level - 1]
        local mesh = self._meshes[level - 1]

        _upsample_shader:bind()

        local w, h = destination:get_width(), destination:get_height()
        _upsample_shader:send("texel_size", { 1 / source:get_width(), 1 / source:get_height()})
        _upsample_shader:send("bloom_strength", self._bloom_strength)
        _upsample_shader:send("current_mip", destination:get_native())

        destination:bind()

        if level - 1 > 1 then
            lg.clear(0, 0, 0, 0)
        end

        mesh:set_texture(source)
        mesh:draw()

        destination:unbind()
    end


    lg.setShader(nil)
    lg.setCanvas(nil)
    lg.pop()
end

--- @brief
function rt.Bloom:draw(...)
    if self._update_needed then
        self:_apply_bloom()
    end
    self._textures[1]:draw()
end
