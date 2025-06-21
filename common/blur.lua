--- @class rt.Blur
rt.Blur = meta.class("Blur")

local _blur_shader_horizontal, _blur_shader_vertical

--- @brief
function rt.Blur:instantiate(width, height, ...)
    if _blur_shader_horizontal == nil then
        _blur_shader_horizontal = rt.Shader("common/blur.glsl", {
            HORIZONTAL_OR_VERTICAL = 1
        }):get_native()
    end

    if _blur_shader_vertical == nil then
        _blur_shader_vertical = rt.Shader("common/blur.glsl", {
            HORIZONTAL_OR_VERTICAL = 0
        }):get_native()
    end

    return meta.install(self, {
        _blur_strength = 1, -- Integer
        _texture_w = width,
        _texture_h = height,
        _texture_a = rt.RenderTexture(width, height, ...):get_native(),
        _texture_b = rt.RenderTexture(width, height, ...):get_native(),
        _a_or_b = true,
        _blur_applied = false,
        _blur_horizontally = true,
        _blur_vertically = true,
    })
end

local _before
local lg = love.graphics

--- @brief
function rt.Blur:bind()
    _before = love.graphics.getCanvas()
    lg.setCanvas({ self._texture_a, stencil = true })
    self._blur_applied = false
end

--- @brief
function rt.Blur:unbind()
    lg.setCanvas(nil)
end

--- @brief
function rt.Blur:set_blur_vertically(b)
    self._blur_vertically = b
end

--- @brief
function rt.Blur:set_blur_horizontally(b)
    self._blur_horizontally = b
end

--- @brief
function rt.Blur:set_blur_strength(strength)
    meta.assert(strength, "Number")
    local before = self._blur_strength
    self._blur_strength = math.max(strength, 0)
    if before ~= strength then
        self._blur_applied = false
    end
end

--- @brief
function rt.Blur:get_blur_strength(strength)
    return self._blur_strength
end

--- @brief
function rt.Blur:_apply_blur()
    if self._blur_strength > 0 then
        lg.push()
        lg.origin()

        lg.setCanvas({ self._texture_b, stencil = true })
        lg.origin()
        lg.clear(0, 0, 0, 0)
        lg.setCanvas(nil)

        _blur_shader_horizontal:send("texture_size", { self._texture_w, self._texture_h })
        _blur_shader_vertical:send("texture_size", { self._texture_w, self._texture_h })
        local a, b = self._texture_a, self._texture_b

        local shader_a, shader_b, strength
        if self._blur_vertically == true and self._blur_horizontally == false then
            shader_a, shader_b = _blur_shader_horizontal, _blur_shader_horizontal -- sic
            strength = 2
        elseif self._blur_horizontally == true and self._blur_vertically == false then
            shader_a, shader_b = _blur_shader_vertical, _blur_shader_vertical
            strength = 2
        else
            shader_a, shader_b = _blur_shader_horizontal, _blur_shader_vertical
            strength = 1
        end
        for i = 1, math.ceil(self._blur_strength) * strength do
            lg.setShader(shader_a)
            lg.setCanvas(a)
            lg.draw(b)

            lg.setShader(shader_b)
            lg.setCanvas(b)
            lg.draw(a)
        end

        lg.setCanvas(nil)
        lg.setShader(nil)
        lg.pop()
    end
end

--- @brief
function rt.Blur:draw(...)
    local before = lg.getShader()

    if self._blur_applied == false then
        self:_apply_blur()
        self._blur_applied = true
    end

    lg.setShader(before)
    lg.draw(self._texture_a, ...)
end

--- @brief
function rt.Blur:get_texture()
    if self._blur_applied == false then
        self:_apply_blur()
        self._blur_applied = true
    end

    return self._texture_a
end

