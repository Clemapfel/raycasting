if rt.graphics == nil then rt.graphics = {} end

function rt.graphics.get_stencil_value()
    local out = rt.graphics._stencil_value
    if out == nil then
        out = 2
        rt.graphics._stencil_value = 2
    end

    rt.graphics._stencil_value = rt.graphics._stencil_value + 1
    if rt.graphics._stencil_value > 254 then rt.graphics._stencil_value = 2 end
    return out
end

--- @enum rt.StencilDrawMode
rt.StencilDrawMode = {
    KEEP = "keep",
    REPLACE = "replace",
    INCREMENT = "increment",
    DECREMENT = "decrement"
}
rt.StencilDrawMode = meta.enum("StencilDrawMode", rt.StencilDrawMode)

--- @enum rt.StencilCompareMode
rt.StencilCompareMode = {
    EQUAL = "equal",
    NOT_EQUAL = "notequal",
    LESS_THAN = "less",
    LESS_THAN_OR_EQUAL = "lequal",
    GREATER_THAN = "greater",
    GREATER_THAN_OR_EQUAL = "gequal",
    ALWAYS = "always"
}
rt.StencilCompareMode = meta.enum("StencilCompareMode", rt.StencilCompareMode)

--- @enum rt.StencilMode
rt.StencilMode = {
    DRAW = "draw",
    TEST = "test"
}
rt.StencilMode = meta.enum("StencilMode", rt.StencilMode)

--- @brief
function rt.graphics.set_stencil_mode(value, mode, draw_or_compare_mode)
    if value == nil then
        love.graphics.setStencilState("keep", "always", value)
        love.graphics.setColorMask(true)
        rt.graphics._stencil_mode_active = false
        return
    end

    if DEBUG then
        meta.assert(value, mt.Number)
        if draw_or_compare_mode ~= nil then
            if mode == rt.StencilMode.TEST then
                meta.assert_argument_type(draw_or_compare_mode, rt.StencilCompareMode, 3)
            elseif mode == rt.StencilMode.DRAW then
                meta.assert_argument_type(draw_or_compare_mode, rt.StencilDrawMode, 3)
            end
        end
    end

    local replace_mode, test_mode, mask
    if mode == rt.StencilMode.TEST then
        replace_mode = rt.StencilDrawMode.KEEP
        test_mode = draw_or_compare_mode or rt.StencilCompareMode.EQUAL
        mask = true
        rt.graphics._stencil_mode_active = false
    elseif mode == rt.StencilMode.DRAW then
        replace_mode = draw_or_compare_mode or rt.StencilDrawMode.REPLACE
        test_mode = rt.StencilCompareMode.ALWAYS
        mask = false
        rt.graphics._stencil_mode_active = true
    end

    love.graphics.setStencilState(replace_mode, test_mode, value)
    love.graphics.setColorMask(mask)
end

function rt.graphics.clear_stencil()
    love.graphics.clear(false, true, false)
end
