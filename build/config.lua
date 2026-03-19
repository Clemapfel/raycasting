require "common.log"
require "common.error_handler"
require "common.player_sprint_mode"
require "common.msaa_quality"
require "common.vsync_mode"

require "love.filesystem"

rt.settings.config = {
    default_settings_path = "build/default_settings.ini",
    default_keybind_path = "build/default_keybinding.ini"
}

if bd.config == nil then
    --- @module config
    bd.config = {} 
end

bd.config.settings = {}
bd.config.default_settings = {}

bd.config.keybind_keyboard = {}
bd.config.default_keybind_keyboard = {}

bd.config.keybind_controller = {}
bd.config.default_keybind_controller = {}

--- @brief
function bd.get_config()
    return bd.config.settings
end

--- @brief
function bd.get_default_config()
    return bd.config.default_settings
end

--- @brief
function bd.get_keybind()
    return bd.config.keybind_keyboard, bd.config.keybind_controller
end

--- @brief
function bd.get_default_keybinding()
    return bd.config.default_keybind_keyboard, bd.config.default_keybind_controller
end

--- @brief
function bd.config.get_value(key)
    local entry = bd.config.settings[key]
    if entry == nil then
        rt.error("In bd.config.get_value: unknown key `", key, "`")
        return nil
    else
        return entry
    end
end

--- @brief
function bd.config.get_default_value(key)
    local entry = bd.config.default_settings[key]
    if entry == nil then
        rt.error("In bd.config.get_value: unknown key `", key, "`")
        return nil
    else
        return entry
    end
end

--- @brief
function bd.config.get_keyboard_binding(input_action)
    local entry = bd.config.keybind_keyboard[input_action .. "_keyboard"]
    if entry == nil then
        rt.error("In bd.config.get_keyboard_binding: unmapped input action `", input_action, "`")
    end

    return entry
end

--- @brief
function bd.config.get_default_keyboard_binding(input_action)
    local entry = bd.config.default_keybind_keyboard[input_action .. "_keyboard"]
    if entry == nil then
        rt.error("In bd.config.get_default_keyboard_binding: unmapped input action `", input_action, "`")
    end

    return entry
end

--- @brief
function bd.config.get_controller_binding(input_action)
    local entry = bd.config.keybind_controller[input_action .. "_controller"]
    if entry == nil then
        rt.error("In bd.config.get_controller_binding: unmapped input action `", input_action, "`")
    end

    return entry
end

--- @brief
function bd.config.get_default_controller_binding(input_action)
    local entry = bd.config.default_keybind_controller[input_action .. "_controller"]
    if entry == nil then
        rt.error("In bd.config.get_default_controller_binding: unmapped input action `", input_action, "`")
    end

    return entry
end

bd.config._string_to_table = function(str)
    local _line_separator = "\n"
    local _key_value_separator = "="
    local _comment = "#"
    local _element_separator = ","

    local line_pattern = "([^" .. _line_separator .. "]*)" .. _line_separator
    local comment_strip_pattern = _comment .. "[^" .. _line_separator .. "]*"
    local key_value_pattern = "^%s*([^%s" .. _key_value_separator .. _comment .. _element_separator .. "][^" .. _key_value_separator .. _comment .. _element_separator .. "]-)%s*" .. _key_value_separator .. "%s*(.-)%s*$"

    if string.at(str, #str) ~= "\n" then str = str .. "\n" end
    local result = {}
    for line in string.gmatch(str, line_pattern) do
        local key, value = string.match(string.gsub(line, comment_strip_pattern, ""), key_value_pattern)
        if key ~= nil and key ~= "" and value ~= nil and value ~= "" then
            if string.find(value, _element_separator) then
                local elements = {}
                for element in string.gmatch(value, "([^" .. _element_separator .. "]+)") do
                    local trimmed = string.match(element, "^%s*(.-)%s*$")
                    if trimmed ~= "" then
                        elements[#elements + 1] = trimmed
                    end
                end
                result[key] = #elements > 0 and elements or nil
            else
                result[key] = value
            end
        end
    end

    return result
end

bd.config._make_immutable = function(t)
    return setmetatable(t, {
        __index = function(_, key)
            rt.error("In bd.config: trying to access key `", key, "`, but it does not exist")
        end,

        __newindex = function(_, key)
            rt.error("In bd.config: trying to create key `", key, "`, but it does not exist")
        end
    })
end

-- load default settings
package.loaded["build.config_settings"] = nil
require("build.config_settings")

-- load default keybind
package.loaded["build.config_keybinding"] = nil
require("build.config_keybinding")
