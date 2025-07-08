--- @class rt.StencilMode
rt.StencilReplaceMode = meta.enum("StencilReplaceMode", {
    KEEP = "keep",
    REPLACE = "replace",
    INCREMENT = "increment",
    DECREMENT = "decrement"
})

function rt.graphics.get_stencil_value()
    local out = rt.graphics._stencil_value
    if out == nil then
        out = 2
        rt.graphics._stencil_value = 2
    end

    rt.graphics._stencil_value = rt.graphics._stencil_value + 1
    return out
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

rt.StencilMode = meta.enum("StencilMode", {
    DRAW = "draw",
    TEST = "Test"
})

local _draw_to_backbuffer = true
local _canvas_shader

function rt.graphics.set_stencil_mode(value, mode, draw_or_compare_mode)
    if value == nil then
        love.graphics.setStencilState("keep", "always", value)
        love.graphics.setColorMask(_draw_to_backbuffer)
        rt.graphics._stencil_mode_active = false
        return
    end

    meta.assert(value, "Number")
    if draw_or_compare_mode ~= nil then
        if mode == rt.StencilMode.TEST then
            meta.assert_enum_value(draw_or_compare_mode, rt.StencilCompareMode)
        elseif mode == rt.StencilMode.DRAW then
            meta.assert_enum_value(draw_or_compare_mode, rt.StencilReplaceMode)
        end
    end

    local replace_mode, test_mode, mask
    if mode == rt.StencilMode.TEST then
        replace_mode = rt.StencilReplaceMode.KEEP
        test_mode = draw_or_compare_mode or rt.StencilCompareMode.EQUAL
        mask = _draw_to_backbuffer
        rt.graphics._stencil_mode_active = false
    elseif mode == rt.StencilMode.DRAW then
        replace_mode = draw_or_compare_mode or rt.StencilReplaceMode.REPLACE
        test_mode = rt.StencilCompareMode.ALWAYS
        mask = not _draw_to_backbuffer
        rt.graphics._stencil_mode_active = true
    end

    love.graphics.setStencilState(replace_mode, test_mode, value)
    love.graphics.setColorMask(mask)
end

function rt.graphics.clear_stencil()
    love.graphics.clear(false, true, false)
end

local _stencil_stack = {}
local _stencil_stack_depth = 0
