--- @class rt.VSyncMode
rt.VSyncMode = meta.enum("VSyncMode", {
    ADAPTIVE = "adaptive",
    OFF = "off",
    ON = "on"
})

if rt.graphics == nil then rt.graphics = {} end

--- @brief
function rt.graphics.vsync_mode_to_native(mode)
    local mapping = {
        [rt.VSyncMode.OFF] = 0,
        [rt.VSyncMode.ON] = 1,
        [rt.VSyncMode.ADAPTIVE] = -1
    }

    local mapped = mapping[mode]
    if mapped == nil then
        rt.error("In rt.graphics.vsync_mode_to_native: unknown mode `", mode, "`")
    end

    return mapped
end