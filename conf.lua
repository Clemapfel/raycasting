DEBUG = true -- overriden by build script

require "include"
function love.conf(settings)
    require "common.msaa_quality"
    require "common.vsync_mode"
    require "common.player_sprint_mode"

    require "build.config"
    local config = bd.get_config()

    local to_exclude = {}
    if config.allow_opengl == false then
        table.insert(to_exclude, "opengl")
    end

    if config.allow_vulkan == false then
        table.insert(to_exclude, "vulkan")
    end

    if config.allow_metal == false then
        table.insert(to_exclude, "Metal")
    end

    settings.graphics.renderers = nil -- keep default
    settings.graphics.excluderenderers = to_exclude

    settings.window.width = config.window_width
    settings.window.height = config.window_height
    settings.window.fullscreen = config.is_fullscreen
    settings.window.fullscreentype = config.fullscreen_type
    settings.window.resizable = config.is_resizable
    settings.window.stencil = true
    settings.window.depth = true
    settings.window.gammacorrect = config.use_gamma_correction

    if config.is_fullscreen then
        settings.window.borderless = true
    else
        settings.window.borderless = config.is_borderless
    end

    do
        local mapping = {
            [rt.VSyncMode.OFF] = 0,
            [rt.VSyncMode.ON] = 1,
            [rt.VSyncMode.ADAPTIVE] = -1
        }

        settings.window.vsync = mapping[config.vsync]
    end

    do
        local mapping = {
            [rt.MSAAQuality.OFF] = 0,
            [rt.MSAAQuality.GOOD] = 2,
            [rt.MSAAQuality.BETTER] = 4,
            [rt.MSAAQuality.BEST] = 8
        }

        settings.window.msaa = math.min(mapping[config.msaa], 8)
    end

    settings.window.usedpiscale = config.use_dpi_scale
    settings.console = config.show_console

    settings.window.title = "Chroma Drift"
    settings.identity = "chroma_drift"
    settings.appendidentity = false -- prioritze source dir over save dir for file i/o

    for _, exclude in pairs({
        "touch",
        "sensor",
        "video"
    }) do
        settings.modules[exclude] = false
    end
end



