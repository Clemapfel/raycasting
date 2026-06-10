rt.settings.version = {
    major = 0,
    minor = 1
}

--- @brief
rt.get_version = function()
    return rt.settings.version.major, rt.settings.version.minor
end