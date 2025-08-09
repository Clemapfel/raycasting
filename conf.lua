require "common.common"

local GAME_NAME = "Chroma Drift"
local success = pcall(function()
    require "love.image"
    require "love.window"
    local data = love.image.newImageData("assets/favicon.png")
    love.window.setIcon(data)
end)

function love.conf(settings)
    --settings.graphics.renderers = {"opengl"}
    settings.window.msaa = 4
    settings.window.resizable = true
    settings.window.vsync = -1
    settings.window.usedpiscale = false
    settings.window.title = GAME_NAME

    for exclude in range(
        "touch",
        "sensor",
        "video"
    ) do
        settings.modules[exclude] = false
    end

    love.filesystem.setIdentity(GAME_NAME)
end



