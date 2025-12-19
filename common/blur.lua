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
    love.graphics.setCanvas({ self._texture_a, stencil = true })
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


--[[

local M = {}

-- Compute 1D Gaussian weights for indices 0..radius (unnormalized),
-- then normalize so sum over -radius..radius equals 1.
function M.gaussian1DWeights(radius, sigma)
    assert(radius and radius >= 1 and radius % 2 == 0, "radius must be a positive even integer")
    if not sigma or sigma <= 0 then
        sigma = 0.3 * radius + 0.5
    end

    local w = {}
    local twoSigma2 = 2.0 * sigma * sigma

    -- Unnormalized weights for i=0..radius
    for i = 0, radius do
        w[i] = math.exp(-(i * i) / twoSigma2)
    end

    -- Normalize over symmetric range -radius..radius
    local sum = w[0]
    for i = 1, radius do
        sum = sum + 2.0 * w[i]
    end
    for i = 0, radius do
        w[i] = w[i] / sum
    end

    return w, sigma
end

function M.makeLinearSamplingKernelFromRadius(radius, sigma)
    local w
    w, sigma = M.gaussian1DWeights(radius, sigma)

    local pairs = math.floor(radius / 2)
    local kernel_size = pairs + 1

    local weights_out = {}
    local offsets_out = {}

    -- Center entry
    weights_out[1] = w[0]
    offsets_out[1] = 0.0

    -- Combine pairs: (1,2), (3,4), ..., (2*pairs-1, 2*pairs)
    for i = 1, pairs do
        local a = 2 * i - 1
        local b = 2 * i
        local wa = w[a]
        local wb = w[b]
        local combined = wa + wb

        local pos = (a * wa + b * wb) / combined

        -- CRITICAL: These weights will be applied TWICE in the shader
        -- (once for positive offset, once for negative offset)
        -- So we store the combined weight as-is
        weights_out[i + 1] = combined
        offsets_out[i + 1] = pos
    end

    -- Verify normalization (should equal 1.0)
    local total = weights_out[1]
    for i = 2, kernel_size do
        total = total + 2.0 * weights_out[i]  -- *2 because shader samples both directions
    end

    print(string.format("Kernel size %d (sigma=%.1f): total weight = %.10f",
        kernel_size, sigma, total))

    return weights_out, offsets_out, sigma
end

function M.makeKernelForSize(kernel_size, sigma)
    local radius = 2 * (kernel_size - 1)
    return M.makeLinearSamplingKernelFromRadius(radius, sigma)
end

function M.makeAllKernels(sigma_by_size)
    local out = {}
    for _, ks in ipairs({3, 5, 7, 9, 11, 13, 15, 17, 19}) do
        local sigma = sigma_by_size and sigma_by_size[ks] or nil
        local w, o, s = M.makeKernelForSize(ks, sigma)
        out[ks] = { weights = w, offsets = o, sigma = s }
    end
    return out
end
]]--