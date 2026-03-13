--- @class rt.VSyncMode
rt.VSyncMode = meta.enum("VSyncMode", {
    ADAPTIVE = "adaptive",
    OFF = "off",
    ON = "on"
})

--- @brief
function rt.graphics.vsync_mode_to_native(mode)
    local mapping = {
        [rt.VSyncMode.OFF] = 0,
        [rt.VSyncMode.ON] = 1,
        [rt.VSyncMode.ADAPTIVE] = -1
    }

    return mapping[mode]
end