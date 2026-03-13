
--- @class rt.MSAAQuality
rt.MSAAQuality = meta.enum("MSAAQuality", {
    OFF = "off",
    GOOD = "good",
    BETTER = "better",
    BEST = "best"
})

--- @brief
function rt.graphics.msaa_quality_to_native(quality)
    local mapping = {
        [rt.MSAAQuality.OFF] = 0,
        [rt.MSAAQuality.GOOD] = 2,
        [rt.MSAAQuality.BETTER] = 4,
        [rt.MSAAQuality.BEST] = 8
    }

    return math.min(
        mapping[quality],
        love.graphics.getSystemLimits().texturemsaa or 8
    )
end
