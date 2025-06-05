VSYNC_ADAPTIVE = -1
VSYNC_OFF = 0
VSYNC_ON = 1

function love.conf(settings)
    --settings.graphics.renderers = {"opengl"}
    settings.window.msaa = 8
    settings.window.resizable = true
    settings.window.vsync = VSYNC_ON
    settings.window.usedpiscale = false
end



