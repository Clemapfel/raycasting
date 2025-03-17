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
        _strength = 1, -- Integer
        _texture_w = width,
        _texture_h = height,
        _texture_a = rt.RenderTexture(width, height, ...):get_native(),
        _texture_b = rt.RenderTexture(width, height, ...):get_native(),
        _a_or_b = true,
        _blur_applied = false
    })
end

local _before
local lg = love.graphics

--- @brief
function rt.Blur:bind()
    _before = love.graphics.getCanvas()
    lg.setCanvas(self._texture_a)
    self._blur_applied = false
end

--- @brief
function rt.Blur:unbind()
    lg.setCanvas(_before)
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
function rt.Blur:_apply_blur()
    if self._blur_strength > 0 then
        lg.push()

        _blur_shader_horizontal:send("texture_size", { self._texture_w, self._texture_h })
        _blur_shader_vertical:send("texture_size", { self._texture_w, self._texture_h })
        local a, b = self._texture_a, self._texture_b
        for i = 1, math.ceil(self._blur_strength) do
            lg.setShader(_blur_shader_horizontal)
            lg.setCanvas(a)
            lg.draw(b)

            lg.setShader(_blur_shader_vertical)
            lg.setCanvas(b)
            lg.draw(a)
        end

        lg.setCanvas(nil)
        lg.pop()
    end
end

--- @brief
function rt.Blur:draw(...)
    if self._blur_applied == false then
        self:_apply_blur()
        self._blur_applied = true
    end

    love.graphics.setColor(1, 1, 1, 1)
    lg.draw(self._texture_b)
end

