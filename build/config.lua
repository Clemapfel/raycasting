require "common.log"
require "common.player_sprint_mode"
require "common.msaa_quality"
require "common.vsync_mode"

require "love.filesystem"

bd.config = {}
bd.config.default_path = "build/default_settings.ini"
bd.config.values = {} -- entry values after config was loaded
bd.config.default_values = {}

--- @brief get the parsed value
function bd.config.get_value(key)
    local entry = bd.config.values[key]
    if entry == nil then
        rt.error("In bd.config.get_value: unknown key `", key, "`")
        return nil
    else
        return entry
    end
end

--- @brief
function bd.config.get_default_value(key)
    local entry = bd.config.default_values[key]
    if entry == nil then
        rt.error("In bd.config.get_value: unknown key `", key, "`")
        return nil
    else
        return entry
    end
end

--- @brief
function bd.get_config()
    return bd.config.values
end

--- @brief
function bd.get_default_config()
    return bd.config.default_values
end

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
        window_resizable = BOOLEAN(true),

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
            0, 0.5
        ),

        trigger_deadzone = FLOAT_RANGE(0,
            0, 0.5
        ),

        controller_vibration_strength = FLOAT_RANGE(1, 0, 1),
    }
end

--- @brief check if a config entry has the correct format
bd.config._validate_entry = function(key, value)
    local throw = function(...)
        rt.critical("In bd.config._validate_entry: ", ...)
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
        rt.assert(false, "In ow.config._validate_entry: unknown entry type `", to_string(entry.type), "`")
        return false, nil
    end

    return true, value
end

local _line_separator = "\n"
local _key_value_separator = "="
local _comment = "#"

bd.config.parse_from_string = function(str)
    local out = {}

    local line_pattern = "([^" .. _line_separator .. "]*)" .. _line_separator
    local comment_strip_pattern = _comment .. "[^" .. _line_separator .. "]*"
    local key_value_pattern = "^%s*([^%s" .. _key_value_separator .. _comment .. "][^" .. _key_value_separator .. _comment .. "]-)%s*" .. _key_value_separator .. "%s*(.-)%s*$"
    -- "^%s*([^%s=#][^=#]-)%s*=%s*([^#\n]-) *%s*$"
    -- white space, key, white space, equal, white space, value, whitespace, newline
    -- ignore anything after # until next \n

    if string.at(str, #str) ~= "\n" then str = str .. "\n" end
    for line in string.gmatch(str, line_pattern) do
        local key, value = string.match(string.gsub(line, comment_strip_pattern, ""), key_value_pattern)
        if key == nil or key == "" or value == nil or value == "" then goto next end

        local success = false
        success, value = bd.config._validate_entry(key, value)

        if not success then goto next end

        out[key] = value
        ::next::
    end

    setmetatable(out, {
        __index = function(_, key)
            rt.error("In bd.config: trying to access key `", key, "`, but it does not exist")
        end,

        __newindex = function(_, key)
            rt.error("In bd.config: trying to create key `", key, "`, but it does not exist")
        end
    })

    return out
end

do -- load default config
    for key, entry in pairs(bd.config.entries) do
        if not bd.config._validate_entry(key, entry.default) then
            rt.error("In config.lua: default value for entry `", key, "` is invalid")
        end
    end

    local path = bd.config.default_path
    local success, file_or_error = pcall(love.filesystem.read, path)

    if not success then
        rt.error("In bd.parse_config: unable to open config file at `", path, "`")
    else
        bd.config.default_values = bd.config.parse_from_string(file_or_error)
        bd.config.values = table.deepcopy(bd.config.default_values)
    end
end