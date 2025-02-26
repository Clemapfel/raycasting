--- @class rt.StencilMode
rt.StencilMode = meta.enum("StencilMode", {
    REPLACE = "replace",
    INCREMENT = "increment",
    DECREMENT = "decrement"
})

rt.graphics._stencil_value = 1
function rt.graphics.get_stencil_value()
    local out = rt.graphics._stencil_value
    rt.graphics._stencil_value = rt.graphics._stencil_value + 1
    return out
end

--- @brief
function rt.graphics.stencil(new_value, stencil, mode)
    if mode == nil then mode = rt.StencilMode.REPLACE end
    local mask_r, mask_g, mask_b, mask_a = love.graphics.getColorMask()
    love.graphics.setStencilState(mode, "always", new_value, 255)
    love.graphics.setColorMask(false, false, false, false)
    if type(stencil) == "function" then stencil() else stencil:draw() end
    love.graphics.setColorMask(mask_r, mask_g, mask_b, mask_a)
    love.graphics.setStencilState()
end

rt.StencilCompareMode = meta.enum("StencilCompareMode", {
    EQUAL = "equal",
    NOT_EQUAL = "notequal",
    LESS_THAN = "less",
    LESS_THAN_OR_EUAL = "lequal",
    GREATER_THAN = "greater",
    GREATER_THAN_OR_EQUAL = "gequal",
    ALWAYS = "always"
})

--- @brief
function rt.graphics.set_stencil_test(mode, value)
    love.graphics.setStencilState("keep", (mode or "always"), (value or 0))
    rt.graphics._current_stencil_test_mode = mode
    rt.graphics._current_stencil_test_value = value
end

function rt.graphics.get_stencil_test()
    return rt.graphics._current_stencil_test_mode, rt.graphics._current_stencil_test_value
end