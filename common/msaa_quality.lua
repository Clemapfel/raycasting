
--- @class rt.MSAAQuality
rt.MSAAQuality = {
    OFF = "off",
    GOOD = "good",
    BETTER = "better",
    BEST = "best"
}
rt.MSAAQuality = meta.enum("MSAAQuality", rt.MSAAQuality)

--- @brief
function rt.graphics.msaa_quality_to_native(quality)
    local mapping = {
        [rt.MSAAQuality.OFF] = 0,
        [rt.MSAAQuality.GOOD] = 2,
        [rt.MSAAQuality.BETTER] = 4,
        [rt.MSAAQuality.BEST] = 8
    }

    local mapped = mapping[quality]
    if mapped == nil then
        rt.error("In rt.graphics.msaa_quality_to_native: unknown quality `", quality, "`")
    end

    return math.min(
        mapped,
        love.graphics.getSystemLimits().texturemsaa or 8
    )
end
