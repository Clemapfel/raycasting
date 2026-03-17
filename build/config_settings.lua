local BOOLEAN_TYPE = "Boolean"
local BOOLEAN = function(default)
    return {
        type = BOOLEAN_TYPE,
        default = default
    }
end

local ENUM_TYPE = "Enum"
local ENUM = function(default, ...)
    return {
        type = ENUM_TYPE,
        default = default,
        values = { ... }
    }
end

local FLOAT_RANGE_TYPE = "FloatRange"
local FLOAT_RANGE = function(default, lower, upper)
    return {
        type = FLOAT_RANGE_TYPE,
        default = default,
        lower = math.min(lower, upper),
        upper = math.max(lower, upper)
    }
end

local INTEGER_RANGE_TYPE = "IntegerRange"
local INTEGER_RANGE = function(default, lower, upper)
    return {
        type = INTEGER_RANGE_TYPE,
        default = default,
        lower = math.min(lower, upper),
        upper = math.max(lower, upper)
    }
end

do
    local window_min_w, window_min_h = 400, 300
    local window_max_w, window_max_h = window_min_w, window_min_h
    do
        for i = 1, love.window.getDisplayCount() do
            local w, h = love.window.getDesktopDimensions(i)
            window_max_w = math.max(window_max_w, w)
            window_max_h = math.max(window_max_h, h)
        end
    end

    local renderers = {}
    do
        local os = love.system.getOS()
        if os == "OS X" then
            renderers["metal"] = true
        else
            renderers["metal"] = false
        end

        renderers["vulkan"] = true
        renderers["opengl"] = true
    end

    local height = 600
    local aspect_ratio = 16 / 9

    local use_performance_mode = false
    local performance_ternary = function(on_true, on_false)
        if use_performance_mode == true then
            return on_true
        else
            return on_false
        end
    end

    bd.config.entries = {
        -- should window initialize in fullscreen mode
        is_fullscreen = BOOLEAN(false),

        -- full screen type
        fullscreen_type = ENUM("desktop", "desktop", "exclusive"),

        -- should window have title bar
        is_borderless = BOOLEAN(true),

        -- initial window width
        window_width = INTEGER_RANGE(
            height * aspect_ratio,
            0, window_max_w
        ),

        -- initial window height
        window_height = INTEGER_RANGE(
            height,
            0, window_max_h
        ),

        -- if window can be resized
        is_resizable = BOOLEAN(true),

        -- if dpi scale should be applied, also sets `highdpi`
        use_dpi_scale = BOOLEAN(false),

        -- if the console should be visible when the game starts
        is_console_visible = BOOLEAN(true),

        -- which renderers are allowed
        allow_opengl = BOOLEAN(renderers["opengl"]),
        allow_vulkan = BOOLEAN(renderers["vulkan"]),
        allow_metal = BOOLEAN(renderers["metal"]),

        -- whether to use sRGB for the backbuffer
        use_gamma_correction = BOOLEAN(false),

        -- vsync mode
        vsync = ENUM(rt.VSyncMode.ADAPTIVE,
            rt.VSyncMode.OFF,
            rt.VSyncMode.ON,
            rt.VSyncMode.ADAPTIVE
        ),

        -- performance mode
        performance_mode_enabled = BOOLEAN(use_performance_mode),

        -- graphics
        msaa = ENUM(performance_ternary(rt.MSAAQuality.OFF, rt.MSAAQuality.GOOD),
            rt.MSAAQuality.OFF,
            rt.MSAAQuality.GOOD,
            rt.MSAAQuality.BETTER,
            rt.MSAAQuality.BEST
        ),

        is_hdr_enabled = BOOLEAN(performance_ternary(false, true)),
        is_bloom_enabled = BOOLEAN(performance_ternary(false, true)),

        -- screen shake
        is_screen_shake_enabled = BOOLEAN(true),

        -- non-diagetic overlay
        draw_debug_information = BOOLEAN(true),
        draw_speedrun_splits = BOOLEAN(true),

        -- should system console be shown
        show_console = BOOLEAN(true),

        -- audio
        sound_effect_level = FLOAT_RANGE(1, 0, 1),
        music_level = FLOAT_RANGE(1, 0, 1),

        -- accessibility
        is_color_blind_mode_enabled = BOOLEAN(false),
        text_speed = FLOAT_RANGE(1, 0, 1),

        -- controls
        player_sprint_mode = ENUM(rt.PlayerSprintMode.HOLD_TO_SPRINT,
            rt.PlayerSprintMode.HOLD_TO_SPRINT,
            rt.PlayerSprintMode.HOLD_TO_WALK
        ),

        is_input_buffering_enabled = BOOLEAN(true),

        double_press_threshold = FLOAT_RANGE(0.5,
            0, 1
        ),

        joystick_deadzone = FLOAT_RANGE(0.05,
            0, 0.95
        ),

        trigger_deadzone = FLOAT_RANGE(0,
            0, 0.95
        ),

        controller_vibration_strength = FLOAT_RANGE(1, 0, 1),
    }
end

--- @brief check if a config entry has the correct format
bd.config.validate_settings_entry = function(key, value)
    local throw = function(...)
        rt.critical("In bd.config.validate_settings_entry: ", ...)
    end

    value = string.match(tostring(value), '^"(.-)"$') or value -- strip `"`

    local to_number = function(value)
        local success, number_or_error = pcall(tonumber, value)
        if success == true then
            return number_or_error
        else
            return nil
        end
    end

    local to_string = function(value)
        if value == "nil" then
            return "nil"
        else
            return tostring(value)
        end
    end

    local to_boolean = function(value)
        if value == true or value == "true" or to_number(value) == 1 then
            return true
        elseif value == false or value == "false" or to_number(value) == 0 then
            return false
        end
    end

    local entry = bd.config.entries[key]
    if entry == nil then
        throw("unrecognized settings key `", key, "`")
        return false, nil
    end

    if entry.type == BOOLEAN_TYPE then
        value = to_boolean(value)
        if not (value == true or value == false) then
            throw("for key `", key, "`, expected `true` or `false`, got `", value, "`")
            return false, nil
        end
    elseif entry.type == ENUM_TYPE then
        local as_number = to_number(value)
        local as_string = tostring(value)

        local is_valid = false
        for _, enum_value in ipairs(entry.values) do
            if value == enum_value or as_number == enum_value or as_string == enum_value then
                is_valid = true
                break
            end
        end

        if not is_valid then
            local to_throw = {
                "for key `", key, "`, expected one of "
            }

            for i, enum_value in ipairs(entry.values) do
                table.insert(to_throw, "`")
                table.insert(to_throw, to_string(enum_value))
                table.insert(to_throw, "`")
                if i ~= #entry.values then
                    table.insert(to_throw, ", ")
                end
            end

            table.insert(to_throw, "; got `")
            table.insert(to_throw, tostring(value))
            table.insert(to_throw, "`")

            throw(table.concat(to_throw))
            return false, nil
        end
    elseif entry.type == INTEGER_RANGE_TYPE then
        value = to_number(value)

        -- findent nearest valid integer if float
        if math.fmod(value, 1) ~= 0 then
            for round in range(math.round, math.floor, math.ceil) do
                if round(value) >= entry.lower and round(value) <= entry.upper then
                    value = round(value)
                    break
                end
            end
        end

        if math.fmod(value, 1) ~= 0 or value < entry.lower or value > entry.upper then
            throw("for key `", key, "` expected integer in range [", entry.lower, ", ", entry.upper, "], got `", value, "`")
            return false, nil
        end
    elseif entry.type == FLOAT_RANGE_TYPE then
        value = to_number(value)
        if value < entry.lower or value > entry.upper then
            throw("for key `", key, "` expected float in range [", entry.lower, ", ", entry.upper, "], got `", value, "`")
            return false, nil
        end
    else
        rt.assert(false, "In ow.config.validate_settings_entry: unknown entry type `", to_string(entry.type), "`")
        return false, nil
    end

    return true, value
end

bd.config.parse_settings_from_string = function(str)
    local out = {}
    local parsed = bd.config._string_to_table(str)

    for key, value in pairs(parsed) do
        local success = false
        success, value = bd.config.validate_settings_entry(key, value)

        if not success then goto next end
        out[key] = value
        ::next::
    end

    return bd.config._make_immutable(out)
end

do -- load default config
    for key, entry in pairs(bd.config.entries) do
        if not bd.config.validate_settings_entry(key, entry.default) then
            rt.error("In config.lua: default value for entry `", key, "` is invalid")
        end
    end

    local path = rt.settings.config.default_settings_path
    local success, file_or_error = pcall(love.filesystem.read, path)

    if not success then
        rt.error("In bd.parse_config: unable to open config file at `", path, "`: ", file_or_error)
    else
        bd.config.default_settings = bd.config.parse_settings_from_string(file_or_error)
        bd.config.settings = table.deepcopy(bd.config.default_settings)
    end
end