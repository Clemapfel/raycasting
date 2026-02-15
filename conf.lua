DEBUG = true -- overriden by build script

local VSYNC_ADAPTIVE = -1
local VSYNC_OFF = 0
local VSYNC_ON = 1

function love.conf(settings)

    --settings.graphics.renderers = {"opengl"}

    local height = 600
    local aspect_ratio = 16 / 9

    settings.window.width = height * aspect_ratio
    settings.window.height = height
    settings.window.msaa = 4
    settings.window.resizable = true
    settings.window.vsync = VSYNC_ADAPTIVE
    settings.window.usedpiscale = true
    settings.window.borderless = false
    settings.window.fullscreen = false

    -- non-overridable settings

    settings.window.stencil = true
    settings.window.depth = true

    for _, exclude in pairs({
        "touch",
        "sensor",
        "video"
    }) do
        settings.modules[exclude] = false
    end

    local game_name = "Chroma Drift"
    settings.window.title = game_name
    love.filesystem.setIdentity(game_name)

    -- disable debug on release
    if not DEBUG then
        _G._setfenv = setfenv or debug.setfenv
        debug = nil
    end
end



