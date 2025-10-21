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
--usage: love.graphics.setBlendState(rgb_operation, alpha_operation, rgb_source_factor, alpha_source_factor, rgb_destination_factor, alpha_destination_factor)

--- @brief set blend mode
--- @brief set blend mode
function rt.graphics.set_blend_mode(blend_mode_rgb, blend_mode_alpha)
    if blend_mode_rgb == nil and blend_mode_alpha == nil then
        love.graphics.setBlendMode("alpha")
        return
    end

    if blend_mode_rgb == nil then blend_mode_rgb = rt.BlendMode.NORMAL end
    if blend_mode_alpha == nil then blend_mode_alpha = rt.BlendMode.NORMAL end

    local rgb_operation, rgb_source_factor, rgb_destination_factor
    local alpha_operation, alpha_source_factor, alpha_destination_factor

    -- Map RGB blend mode
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
        rt.error("Invalid blend mode: ", blend_mode_rgb)
        return
    end

    -- Map Alpha blend mode
    if blend_mode_alpha == rt.BlendMode.NONE then
        alpha_operation = rt.BlendOperation.ADD
        alpha_source_factor = rt.BlendFactor.ZERO
        alpha_destination_factor = rt.BlendFactor.ONE
    elseif blend_mode_alpha == rt.BlendMode.NORMAL then
        alpha_operation = rt.BlendOperation.ADD
        alpha_source_factor = rt.BlendFactor.ONE
        alpha_destination_factor = rt.BlendFactor.ONE_MINUS_SOURCE_ALPHA
    elseif blend_mode_alpha == rt.BlendMode.ADD then
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
        rt.error("Invalid blend mode: ", blend_mode_alpha)
        return
    end

    if rgb_operation and alpha_operation then
        love.graphics.setBlendState(
            rgb_operation, alpha_operation,
            rgb_source_factor, alpha_source_factor,
            rgb_destination_factor, alpha_destination_factor
        )
    else
        rt.error("Failed to set blend mode due to invalid parameters.")
    end
end