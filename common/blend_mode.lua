--- @class rt.BlendMode
rt.BlendMode = meta.enum("BlendMode", {
    NONE = -1,
    NORMAL = 0,
    ADD = 1,
    SUBTRACT = 2,
    MULTIPLY = 3,
    MIN = 4,
    MAX = 5
})

--- @class rt.BlendOperation
rt.BlendOperation = meta.enum("BlendOperation", {
    ADD = "add",
    SUBTRACT = "subtract",
    REVERSE_SUBTRACT = "reversesubtract",
    MIN = "min",
    MAX = "max"
})

--- @class rt.BlendFactor
rt.BlendFactor = meta.enum("BlendFactor", {
    ZERO = "zero",
    ONE = "one",
    SOURCE_COLOR = "srccolor",
    ONE_MINUS_SOURCE_COLOR = "oneminussrccolor",
    SOURCE_ALPHA = "srcalpha",
    ONE_MINUS_SOURCE_ALPHA = "oneminussrcalpha",
    DESTINATION_COLOR = "dstcolor",
    ONE_MINUS_DESTINATION_COLOR = "oneminusdstcolor",
    DESTINATION_ALPHA = "dstalpha",
    ONE_MINUS_DESTINATION_ALPHA = "oneminusdstalpha"
})

--- @brief set blend mode
function rt.graphics.set_blend_mode(blend_mode_rgb, blend_mode_alpha)
    if blend_mode_rgb == nil then blend_mode_rgb = rt.BlendMode.NORMAL end
    if blend_mode_alpha == nil then blend_mode_alpha = rt.BlendMode.NORMAL end
    if love.getVersion() >= 12 then
        local rgb_operation, rgb_source_factor, rgb_destination_factor
        if blend_mode_rgb == rt.BlendMode.NONE then
            rgb_operation = rt.BlendOperation.ADD
            rgb_source_factor = rt.BlendFactor.ZERO
            rgb_destination_factor = rt.BlendFactor.ONE
        elseif blend_mode_rgb == rt.BlendMode.NORMAL then
            rgb_operation = rt.BlendOperation.ADD
            rgb_source_factor = rt.BlendFactor.SOURCE_ALPHA
            rgb_destination_factor = rt.BlendFactor.ONE_MINUS_SOURCE_ALPHA
        elseif blend_mode_rgb == rt.BlendMode.ADD then
            rgb_operation = rt.BlendOperation.ADD
            rgb_source_factor = rt.BlendFactor.ONE
            rgb_destination_factor = rt.BlendFactor.ONE
        elseif blend_mode_rgb == rt.BlendMode.SUBTRACT then
            rgb_operation = rt.BlendOperation.REVERSE_SUBTRACT
            rgb_source_factor = rt.BlendFactor.ONE
            rgb_destination_factor = rt.BlendFactor.ONE
        elseif blend_mode_rgb == rt.BlendMode.MULTIPLY then
            rgb_operation = rt.BlendOperation.ADD
            rgb_source_factor = rt.BlendFactor.DESTINATION_COLOR
            rgb_destination_factor = rt.BlendFactor.ZERO
        elseif blend_mode_rgb == rt.BlendMode.MIN then
            rgb_operation = rt.BlendOperation.MIN
            rgb_source_factor = rt.BlendFactor.ONE
            rgb_destination_factor = rt.BlendFactor.ONE
        elseif blend_mode_rgb == rt.BlendMode.MAX then
            rgb_operation = rt.BlendOperation.MAX
            rgb_source_factor = rt.BlendFactor.ONE
            rgb_destination_factor = rt.BlendFactor.ONE
        else
            rt.error("In rt.graphics.set_blend_mode: invalid rgb blend mode `" .. tostring(blend_mode_rgb) .. "`")
            return
        end

        local alpha_operation, alpha_source_factor, alpha_destination_factor
        if blend_mode_alpha == rt.BlendMode.NONE then
            alpha_operation = rt.BlendOperation.ADD
            alpha_source_factor = rt.BlendFactor.ZERO
            alpha_destination_factor = rt.BlendFactor.ONE
        elseif blend_mode_alpha == rt.BlendMode.NORMAL or blend_mode_alpha == rt.BlendMode.ADD then
            alpha_operation = rt.BlendOperation.ADD
            alpha_source_factor = rt.BlendFactor.ONE
            alpha_destination_factor = rt.BlendFactor.ONE
        elseif blend_mode_alpha == rt.BlendMode.SUBTRACT then
            alpha_operation = rt.BlendOperation.REVERSE_SUBTRACT
            alpha_source_factor = rt.BlendFactor.ONE
            alpha_destination_factor = rt.BlendFactor.ONE
        elseif blend_mode_alpha == rt.BlendMode.MULTIPLY then
            alpha_operation = rt.BlendOperation.ADD
            alpha_source_factor = rt.BlendFactor.DESTINATION_ALPHA
            alpha_destination_factor = rt.BlendFactor.ZERO
        elseif blend_mode_alpha == rt.BlendMode.MIN then
            alpha_operation = rt.BlendOperation.MIN
            alpha_source_factor = rt.BlendFactor.ONE
            alpha_destination_factor = rt.BlendFactor.ONE
        elseif blend_mode_alpha == rt.BlendMode.MAX then
            alpha_operation = rt.BlendOperation.MAX
            alpha_source_factor = rt.BlendFactor.ONE
            alpha_destination_factor = rt.BlendFactor.ONE
        else
            rt.error("In rt.graphics.set_blend_mode: invalid alpha blend mode `" .. tostring(blend_mode_alpha) .. "`")
            return
        end
        love.graphics.setBlendState(rgb_operation, alpha_operation, rgb_source_factor, alpha_source_factor, rgb_destination_factor, alpha_destination_factor)
    else
        local blend_mode = blend_mode_rgb
        if blend_mode == rt.BlendMode.NONE then
            love.graphics.setBlendMode("replace", "alphamultiply")
        elseif blend_mode == rt.BlendMode.NORMAL then
            love.graphics.setBlendMode("alpha", "alphamultiply")
        elseif blend_mode == rt.BlendMode.ADD then
            love.graphics.setBlendMode("add", "alphamultiply")
        elseif blend_mode == rt.BlendMode.SUBTRACT then
            love.graphics.setBlendMode("subtract", "alphamultiply")
        elseif blend_mode == rt.BlendMode.MULTIPLY then
            love.graphics.setBlendMode("multiply", "premultiplied")
        elseif blend_mode == rt.BlendMode.MIN then
            love.graphics.setBlendMode("darken", "premultiplied")
        elseif blend_mode == rt.BlendMode.MAX then
            love.graphics.setBlendMode("lighten", "premultiplied")
        else
            rt.error("In rt.graphics.set_blend_mode: invalid blend mode `" .. tostring(blend_mode) .. "`")
            return
        end
    end
end