if rt == nil then rt = {} end
rt.Log = {}

io.stdout:setvbuf("no") -- force flush to console immediately

local _prefix_label = "[rt]"
local _prefix_format = {
    bold = false,
    italic = false
}

local _frame_index_format = {
    bold = false,
    italic = false
}

local _message_prefix = "[LOG]"
local _message_format = {
    color = "green",
    bold = true
}

local _warning_prefix = "[WARNING]"
local _warning_format = {
    color = "yellow",
    bold = true
}

local _critical_prefix = "[CRITICAL]"
local _critical_format = {
    color = "red",
    bold = true
}

local _error_prefix = "[ERROR]"
local _error_format = nil

local _fatal_prefix = "[FATAL]"
local _fatal_format = {
    color = "red",
    bold = true
}

local _dump_prefix = "[DUMP]"
local _dump_format = nil

local _message_hooks = {}

--- @brief
local function _print(channel, message_t, prefix, config)
    local type = prefix
    local _to_tag = {
        black         = "\027[30m",
        red           = "\027[31m",
        green         = "\027[32m",
        yellow        = "\027[33m",
        blue          = "\027[34m",
        magenta       = "\027[35m",
        cyan          = "\027[36m",
        white         = "\027[37m",
        gray          = "\027[90m",
        light_black   = "\027[90m", -- same as gray
        light_red     = "\027[91m",
        light_green   = "\027[92m",
        light_yellow  = "\027[93m",
        light_blue    = "\027[94m",
        light_magenta = "\027[95m",
        light_cyan    = "\027[96m",
        light_white   = "\027[97m",

        normal        = "\027[0m",
        default       = "\027[39m",
        bold          = "\027[1m",
        italic        = "\027[3m",
        underlined    = "\027[4m",
        reverse       = "\027[7m",
        nothing       = "",
    }

    local message = table.concat(message_t, " ")

    -- colors
    if config ~= nil then
        local to_concat = {}
        if config.color ~= nil then
            local tag = _to_tag[config.color]
            if tag == nil then
                rt.error("In prinstyled: unsupported color `", config.color, "`")
            end
            table.insert(to_concat, tag)
        end

        for _, which in pairs({
            "normal", "bold", "italic", "underline", "reverse"
        }) do
            if config[which] == true then
                table.insert(to_concat, _to_tag[which])
            end
        end

        table.insert(to_concat, prefix)
        table.insert(to_concat, _to_tag.normal)

        prefix = table.concat(to_concat)
    end

    -- current line
    local info = debug.getinfo(4, "Sl")
    if info ~= nil and info.short_src ~= nil and info.currentline ~= nil then
        prefix = table.concat({
            prefix, " ", info.short_src, ":", info.currentline, ": "
        })
    end

    local styled = prefix .. message .. "\n"



    if DEBUG and channel == io.stderr then
        error(styled)
    else
        channel:write(styled)
        channel:flush()
    end

    for _, hook in ipairs(_message_hooks) do
        hook(message)
    end

    if rt.Log._worker ~= nil and rt.Log._main_to_worker ~= nil then
        rt.Log._main_to_worker:push({
            type = type,
            value = message
        })
    end
end

--- @brief
function rt.Log.message(...)
    _print(
        io.stdout,
        { ... },
        _message_prefix,
        _message_format
    )
end

--- @brief
function rt.Log.warning(...)
    _print(
        io.stdout,
        { ... },
        _warning_prefix,
        _warning_format
    )
end

--- @brief
function rt.Log.critical(...)
    _print(
        io.stdout,
        { ... },
        _critical_prefix,
        _critical_format
    )
end

--- @brief
function rt.Log.error(...)
    _print(
        io.stderr,
        { ... },
        _error_prefix,
        _error_format
    )
end

--- @brief
function rt.Log.fatal(...)
    _print(
        io.stderr,
        { ... },
        _fatal_prefix,
        _fatal_format
    )
end

--- @brief
function rt.Log.assert(condition, ...)
    if condition ~= true then
        rt.Log.error(...)
    end
end

--- @brief
function rt.Log.dump()
    local ffi = jit and require("ffi")

    -- query all connected controllers / joysticks
    local joysticks = {}
    for i, joystick in ipairs(love.joystick.getJoysticks()) do
        local vendor_id, product_id, product_version = joystick:getDeviceInfo()
        local entry = {
            index = i,
            name = joystick:getName(),
            guid = joystick:getGUID(),
            id = joystick:getID(),
            vendor_id = vendor_id,
            product_id = product_id,
            product_version = product_version,
            is_connected = joystick:isConnected(),
            is_gamepad = joystick:isGamepad(),
            axis_count = joystick:getAxisCount(),
            button_count = joystick:getButtonCount(),
            hat_count = joystick:getHatCount(),
            is_vibration_supported = joystick:isVibrationSupported(),
            vibration = { joystick:getVibration() },
            gamepad_mappings = joystick:isGamepad() and joystick:getGamepadMappingString() or nil,
            gamepad_axes = {},
            gamepad_buttons = {}
        }

        if joystick:isGamepad() then
            for _, axis in ipairs({
                "leftx", "lefty", "rightx", "righty",
                "triggerleft", "triggerright"
            }) do
                local input_type, input_index, hat_direction = joystick:getGamepadMapping(axis)
                entry.gamepad_axes[axis] = {
                    type = input_type,
                    index = input_index,
                    hat_direction = hat_direction
                }
            end

            for _, button in ipairs({
                "a", "b", "x", "y",
                "back", "guide", "start",
                "leftstick", "rightstick", "leftshoulder", "rightshoulder",
                "dpup", "dpdown", "dpleft", "dpright"
            }) do
                local input_type, input_index, hat_direction = joystick:getGamepadMapping(button)
                entry.gamepad_buttons[button] = {
                    type = input_type,
                    index = input_index,
                    hat_direction = hat_direction
                }
            end
        end

        table.insert(joysticks, entry)
    end

    -- names of all audio recording devices
    local recording_device_names = {}
    local recording_devices = love.audio.getRecordingDevices()
    for _, device in ipairs(recording_devices) do
        table.insert(recording_device_names, device:getName())
    end

    return {
        date = os.date("%d_%m_%y"),
        time = os.date("%H_%M_%S"),
        unix_time = os.time(),
        timezone_offset = os.date("%z"),
        timezone_name = os.date("%Z"),

        version = {
            love_version = love.getVersion(),
            love_config = _G.CONFIG,
            rt_version = _G.VERSION,
            rt_config = bd.get_config(),
            lua_version = _VERSION,
        },

        jit = jit and {
            version = jit.version,
            version_num = jit.version_num,
            status = jit.status(),
            os = jit.os,
            arch = jit.arch
        } or "disabled",

        ffi = ffi and {
            abi_32bit = ffi.abi("32bit"),
            abi_64bit = ffi.abi("64bit"),
            abi_little_endian = ffi.abi("le"),
            abi_big_endian = ffi.abi("be"),
            abi_fpu = ffi.abi("fpu"),
            abi_soft_float = ffi.abi("softfp"),
            abi_hard_float = ffi.abi("hardfp"),
            abi_eabi = ffi.abi("eabi"),
            abi_win = ffi.abi("win"),
            abi_gc64 = ffi.abi("gc64")
        } or "disabled",

        graphics = {
            texture_formats = love.graphics.getTextureFormats({ canvas = false }),
            render_texture_formats = love.graphics.getTextureFormats({ canvas = true }),
            renderer_info = love.graphics.getRendererInfo(),
            supported = love.graphics.getSupported(),
            system_limits = love.graphics.getSystemLimits(),
            texture_types = love.graphics.getTextureTypes(),
            is_gamma_correct = love.graphics.isGammaCorrect(),
            dpi_scale = love.graphics.getDPIScale(),
            pixel_width = love.graphics.getPixelWidth(),
            pixel_height = love.graphics.getPixelHeight(),

            stats = love.graphics.getStats(),
            stack_depth = love.graphics.getStackDepth(),

            default_filter = { love.graphics.getDefaultFilter() },
            line_style = love.graphics.getLineStyle(),
            line_join = love.graphics.getLineJoin(),
            line_width = love.graphics.getLineWidth(),
            blend_mode = { love.graphics.getBlendMode() },
            color_mask = { love.graphics.getColorMask() },
            scissor = { love.graphics.getScissor() },
            has_active_canvas = love.graphics.getCanvas and love.graphics.getCanvas() ~= nil or false,
            default_font_dpi_scale = love.graphics.getFont():getDPIScale(),
        },

        window = (function()
            local width, height, flags = love.window.getMode()
            local safe_x, safe_y, safe_w, safe_h = love.window.getSafeArea()
            local pos_x, pos_y, pos_display = love.window.getPosition()
            local fullscreen, fullscreen_type = love.window.getFullscreen()
            local icon = love.window.getIcon()
            local title = love.window.getTitle()

            local displays = {}
            for i = 1, love.window.getDisplayCount() do
                local desktop_width, desktop_height = love.window.getDesktopDimensions(i)
                local usable_x, usable_y, usable_w, usable_h = love.window.getSafeArea and love.window.getSafeArea() or nil
                table.insert(displays, {
                    name = love.window.getDisplayName(i),
                    desktop_width = desktop_width,
                    desktop_height = desktop_height,
                    orientation = love.window.getDisplayOrientation(i),
                    fullscreen_modes = love.window.getFullscreenModes(i)
                })
            end

            return {
                displays = displays,
                display_count = love.window.getDisplayCount(),

                width = width,
                height = height,
                flags = flags,

                position = {
                    x = pos_x,
                    y = pos_y,
                    display = pos_display
                },

                safe_area = {
                    x = safe_x,
                    y = safe_y,
                    width = safe_w,
                    height = safe_h
                },

                fullscreen = fullscreen,
                fullscreen_type = fullscreen_type,
                vsync = love.window.getVSync(),
                title = title,
                has_icon = icon ~= nil,
                dpi_scale = love.window.getDPIScale(),
                from_pixels_width = (love.window.fromPixels(width)),
                to_pixels_width = (love.window.toPixels(width)),

                is_open = love.window.isOpen(),
                is_visible = love.window.isVisible(),
                is_maximized = love.window.isMaximized(),
                is_minimized = love.window.isMinimized(),
                has_focus = love.window.hasFocus(),
                has_mouse_focus = love.window.hasMouseFocus(),
                is_display_sleep_enabled = love.window.isDisplaySleepEnabled()
            }
        end)(),

        system = {
            os = love.system.getOS(),
            power_info = love.system.getPowerInfo(),
            processor_count = love.system.getProcessorCount(),
        },

        mouse = {
            is_cursor_supported = love.mouse.isCursorSupported(),
            relative_mode = love.mouse.getRelativeMode(),
            is_grabbed = love.mouse.isGrabbed(),
            is_visible = love.mouse.isVisible(),
        },

        keyboard = {
            has_text_input = love.keyboard.hasTextInput(),
            has_key_repeat = love.keyboard.hasKeyRepeat(),

            scancode_to_key = (function()
                local probe = {}
                for _, scancode in ipairs({
                    "q", "w", "e", "r", "t", "y", "u", "i", "o", "p",
                    "a", "s", "d", "f", "g", "h", "j", "k", "l",
                    "z", "x", "c", "v", "b", "n", "m",
                    "1", "2", "3", "4", "5", "6", "7", "8", "9", "0",
                    ",", ".", "/", ";", "'", "[", "]", "-", "=", "`", "\\",
                    "nonusbackslash"
                }) do
                    probe[scancode] = love.keyboard.getKeyFromScancode(scancode)
                end
                return probe
            end)()
        },

        joystick = {
            joystick_count = love.joystick.getJoystickCount(),
            joysticks = joysticks,
        },

        sensor = {
            has_accelerometer = love.sensor.hasSensor("accelerometer"),
            has_gyroscope = love.sensor.hasSensor("gyroscope")
        },

        audio = {
            is_effects_supported = love.audio.isEffectsSupported(),
            max_source_effects = love.audio.getMaxSourceEffects(),
            max_scene_effects = love.audio.getMaxSceneEffects(),
            distance_model = love.audio.getDistanceModel(),
            doppler_scale = love.audio.getDopplerScale(),
            volume = love.audio.getVolume(),
            active_source_count = love.audio.getActiveSourceCount(),
            recording_device_count = #recording_devices,
            recording_device_names = recording_device_names,
        },

        filesystem = {
            identity = love.filesystem.getIdentity(),
            is_fused = love.filesystem.isFused(),
            are_symlinks_enabled = love.filesystem.areSymlinksEnabled(),
            require_path = love.filesystem.getRequirePath(),
            c_require_path = love.filesystem.getCRequirePath(),

            --[[
            -- omit identifying information
            save_directory = love.filesystem.getSaveDirectory(),
            appdata_directory = love.filesystem.getAppdataDirectory(),
            user_directory = love.filesystem.getUserDirectory(),
            working_directory = love.filesystem.getWorkingDirectory(),
            source_base_directory = love.filesystem.getSourceBaseDirectory(),
            source = love.filesystem.getSource()
            ]]
        },

        timer = {
            timer_precision = love.timer.getTime(),
            fps = love.timer.getFPS(),
            average_delta = love.timer.getAverageDelta(),
        }
    }
end

rt.Log.add_message_hook = function(hook)
    table.insert(_message_hooks, hook)
end

-- convenience assignments
rt.log = rt.Log.message
rt.warning = rt.Log.warning
rt.critical = rt.Log.critical
rt.error = rt.Log.error
rt.fatal = rt.Log.fatal
rt.assert = rt.Log.assert

--- @brief
rt.Log.start_worker = function()
    if rt.Log._worker == nil then
        require "love.thread"
        rt.Log._worker = love.thread.newThread("common/log_worker.lua")
        rt.Log._main_to_worker = love.thread.newChannel()
        rt.Log._message_types = {
            MESSAGE = _message_prefix,
            WARNING = _warning_prefix,
            CRITICAL = _critical_prefix,
            ERROR = _error_prefix,
            FATAL = _fatal_prefix,
            DUMP = _dump_prefix,
            EXIT = "[EXIT]"
        }

        rt.Log._worker:start(rt.Log._main_to_worker, rt.Log._message_types)
        rt.Log._main_to_worker:push({
            type = rt.Log._message_types.DUMP,
            value = rt.Log.dump()
        })
    end
end

--- @brief
rt.Log.shutdown_worker = function()
    if rt.Log._worker ~= nil then
        rt.Log._main_to_worker:push({
            type = rt.Log._message_types.EXIT,
            value = "In rt.Log: regular shutdown requested"
        })
    end
end

--- @brief
rt.Log.get_worker = function()
    return rt.Log._worker
end


