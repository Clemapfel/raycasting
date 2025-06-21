--- @class rt.StencilMode
rt.StencilMode = meta.enum("StencilMode", {
    REPLACE = "replace",
    INCREMENT = "increment",
    DECREMENT = "decrement"
})

rt.graphics._stencil_value = 1 -- reset by in SceneManager
function rt.graphics.get_stencil_value()
    local out = rt.graphics._stencil_value
    rt.graphics._stencil_value = rt.graphics._stencil_value + 1
    return out
end

--- @brief
function rt.graphics.stencil(new_value, stencil, mode)
    if mode == nil then mode = rt.StencilMode.REPLACE end
    local mask_r, mask_g, mask_b, mask_a = love.graphics.getColorMask()
    love.graphics.setStencilState(mode, "always", new_value)
    love.graphics.setColorMask(false)
    if type(stencil) == "function" then stencil() else stencil:draw() end
    love.graphics.setColorMask(true)
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

local _stencil_stack = {}
local _stencil_stack_depth = 0

local function _bind_mode(mode, value)
    love.graphics.setStencilState("keep", (mode or "always"), (value or 0))
    love.graphics.setColorMask(true)
end

--- @brief
function rt.graphics.set_stencil_compare_mode(mode, value)
    if mode == nil and _stencil_stack_depth > 0 then
        table.remove(_stencil_stack, _stencil_stack_depth)
        _stencil_stack_depth = _stencil_stack_depth - 1

        if _stencil_stack_depth == 0 then
            _bind_mode(nil, nil)
        else
            _bind_mode(table.unpack(_stencil_stack[_stencil_stack_depth]))
        end
    else
        table.insert(_stencil_stack, { mode, value })
        _stencil_stack_depth = _stencil_stack_depth + 1
        _bind_mode(mode, value)
    end
end

function rt.graphics.get_stencil()
    return rt.graphics._current_stencil_mode, rt.graphics._current_stencil_value
end