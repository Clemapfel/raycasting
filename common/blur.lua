--- @class rt.Blur
rt.Blur = meta.class("Blur")

-- valid kernel sizes
local _kernels = {
    --{ size = 19, sigma = 11.3 },
    --{ size = 17, sigma = 10.1 },
    --{ size = 15, sigma = 8.9 },
    --{ size = 13, sigma = 7.7 },
    { size = 11, sigma = 6.5 },
    { size = 9,  sigma = 5.3 },
    { size = 7,  sigma = 4.1 },
    { size = 5,  sigma = 2.9 },
    { size = 3,  sigma = 1.7 },
}

local _shaders = {}
for entry in values(_kernels) do
    local kernel_size = entry.size
    _shaders[kernel_size] = {
        horizontal =  rt.Shader("common/blur.glsl", {
            HORIZONTAL_OR_VERTICAL = 1,
            KERNEL_SIZE = kernel_size
        }),

        vertical = rt.Shader("common/blur.glsl", {
            HORIZONTAL_OR_VERTICAL = 0,
            KERNEL_SIZE = kernel_size
        })
    }
end

--- @brief
function rt.Blur:instantiate(width, height, ...)
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
        _is_bound = false
    })
end

local lg = love.graphics

--- @brief
function rt.Blur:bind()
    if self._is_bound == true then
        rt.error("In rt.Blur: trying to bind canvas, but it is already bound. Was `unbind` called correctly?")
    end
    love.graphics.push("all")
    self._is_bound = true
    love.graphics.setCanvas({ self._texture_a, stencil = true, depth = true })
    self._blur_applied = false
end

--- @brief
function rt.Blur:unbind()
    self._is_bound = false
    love.graphics.pop("all")
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
    meta.assert(strength, mt.Number)
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
    love.graphics.push("all")
    if self._blur_strength > 0 then
        love.graphics.push()
        love.graphics.origin()

        love.graphics.setCanvas({ self._texture_b, stencil = true })
        love.graphics.origin()
        love.graphics.clear(0, 0, 0, 0)
        love.graphics.setCanvas(nil)

        local target_sigma = self._blur_strength

        local chosen, n_passes
        for entry in values(_kernels) do
            if entry.sigma < target_sigma then
                chosen = entry
                break
            end
        end

        if chosen == nil then
            chosen = _kernels[#_kernels]
        end

        n_passes = math.max(1, math.floor((target_sigma / chosen.sigma)^2))

        local entry = _shaders[chosen.size]
        local shader_a = entry.horizontal
        local shader_b = entry.vertical

        shader_a:send("texture_size", { self._texture_w, self._texture_h })
        shader_b:send("texture_size", { self._texture_w, self._texture_h })

        local a, b = self._texture_a, self._texture_b

        for i = 1, n_passes do
            love.graphics.setShader(shader_a:get_native())
            love.graphics.setCanvas(a)
            love.graphics.draw(b)

            love.graphics.setShader(shader_b:get_native())
            love.graphics.setCanvas(b)
            love.graphics.draw(a)
        end

        love.graphics.setCanvas(nil)
        love.graphics.setShader(nil)
        love.graphics.pop()
    end

    love.graphics.pop()
end

--- @brief
function rt.Blur:draw(...)
    local before = love.graphics.getShader()

    love.graphics.push("all")
    if self._blur_applied == false then
        self:_apply_blur()
        self._blur_applied = true
    end

    love.graphics.pop("all")
    love.graphics.setShader(before)
    love.graphics.draw(self._texture_a, ...)
end

--- @brief
function rt.Blur:get_texture()
    if self._blur_applied == false then
        self:_apply_blur()
        self._blur_applied = true
    end

    return self._texture_a
end


--- @brief
function rt.Blur:get_size()
    return self._texture_w, self._texture_h
end

--- @brief
function rt.Blur:get_width()
    return self._texture_w
end

--- @brief
function rt.Blur:get_height()
    return self._texture_h
end
