DEBUG = true -- overriden by build script
io.stdout:setvbuf("no") -- makes it so love2d error message is printed to console immediately

function love.conf(settings)

    settings.graphics.renderers = {"opengl"}
    settings.window.width = 800
    settings.window.height = 600
    settings.window.msaa = 4
    settings.window.resizable = true
    settings.window.vsync = -1
    settings.window.usedpiscale = false

    -- non-overridable settings

    local game_name = "Chroma Drift"
    settings.window.title = game_name
    love.filesystem.setIdentity(game_name)

    settings.window.stencil = true
    settings.window.depth = true

    for _, exclude in pairs({
        "touch",
        "sensor",
        "video"
    }) do
        settings.modules[exclude] = false
    end

    -- disable debug on release
    if not DEBUG then
        _G._setfenv = setfenv or debug.setfenv
        debug = nil
    end
end



