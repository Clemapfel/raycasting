local log = {}
log._message_hook = function(message)
    -- noop
    return true
end

local _prefix_label = "[rt]"
local _prefix_format = {
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
local _error_format = nil -- because _G.error does not support formatting

--- @brief [internal]
local function _printstyled(message, config)
    if config == nil then
        return message
    end

    local to_tag = {
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

    local to_print = {}

    if config.color ~= nil then
        local tag = to_tag[config.color]
        if tag == nil then
            rt.error("In prinstyled: unsupported color `", config.color, "`")
        end
        table.insert(to_print, tag)
    end

    for _, which in pairs({
        "normal", "bold", "italic", "underline", "reverse"
    }) do
        if config[which] == true then
            table.insert(to_print, to_tag[which])
        end
    end

    table.insert(to_print, message)
    table.insert(to_print, to_tag.normal)
    return table.concat(to_print)
end

local _to_string = function(x)
    if x == nil then
        return "nil"
    else
        return tostring(x)
    end
end

--- @brief
function log.message(...)
    local to_print = {}

    table.insert(to_print, _printstyled(_prefix_label, _prefix_format))
    table.insert(to_print, _printstyled(_message_prefix, _message_format))
    table.insert(to_print, " ")

    for i = 1, select("#", ...) do
        local word = select(i, ...)
        table.insert(to_print, _to_string(word))
    end
    table.insert(to_print, "\n")

    local message = table.concat(to_print)
    local should_print = true
    if log._message_hook ~= nil then
        should_print = log._message_hook(message)
    end

    if should_print == true then
        io.write(message)
        io.flush()
    end
end

--- @brief
function log.warning(...)
    local to_print = {}

    table.insert(to_print, _printstyled(_prefix_label, _prefix_format))
    table.insert(to_print, _printstyled(_warning_prefix, _warning_format))
    table.insert(to_print, " ")

    for i = 1, select("#", ...) do
        table.insert(to_print, _to_string(select(i, ...)))
    end
    table.insert(to_print, "\n")

    local message = table.concat(to_print)
    local should_print = true
    if log._message_hook ~= nil then
        should_print = log._message_hook(message)
    end

    if should_print == true then
        io.write(message)
        io.flush()
    end
end

--- @brief
function log.critical(...)
    local to_print = {}

    table.insert(to_print, _printstyled(_prefix_label, _prefix_format))
    table.insert(to_print, _printstyled(_critical_prefix, _critical_format))
    table.insert(to_print, " ")

    for i = 1, select("#", ...) do
        table.insert(to_print, _to_string(select(i, ...)))
    end
    table.insert(to_print, "\n")

    local message = table.concat(to_print)
    local should_print = true
    if log._message_hook ~= nil then
        should_print = log._message_hook(message)
    end

    if should_print == true then
        io.write(message)
        io.flush()
    end
end

--- @brief
function log.error(...)
    local to_print = {}

    table.insert(to_print, _printstyled(_prefix_label, _prefix_format))
    table.insert(to_print, _printstyled(_error_prefix, nil)) -- sic, error does not support tty pretty printing
    table.insert(to_print, " ")

    for i = 1, select("#", ...) do
        table.insert(to_print, _to_string(select(i, ...)))
    end
    table.insert(to_print, "\n")

    local message = table.concat(to_print)
    local should_print = true
    if log._message_hook ~= nil then
        should_print = log._message_hook(message)
    end

    if should_print == true then
        _G.error(message)
    end
end

--- @brief
function log.assert(condition, ...)
    if condition ~= true then
        local to_print = {}

        table.insert(to_print, _printstyled(_prefix_label, _prefix_format))
        table.insert(to_print, _printstyled(_error_prefix, nil)) -- sic, error does not support tty pretty printing
        table.insert(to_print, " ")

        for i = 1, select("#", ...) do
            table.insert(to_print, _to_string(select(i, ...)))
        end
        table.insert(to_print, "\n")

        local message = table.concat(to_print)
        local should_print = true
        if log._message_hook ~= nil then
            should_print = log._message_hook(message)
        end

        if should_print == true then
            _G.assert(condition, message)
        end
    end
end

--- @brief
function log.setMessageHook(hook)
    if hook ~= nil then
        _G.assert(type(hook) == "function", "In log.setMessageHook: expected `function`, got `" .. type(hook) .. "`")
    end
    log._message_hook = hook
end

rt.log = log.message
rt.warning = log.warning
rt.critical = log.critical
rt.error = log.error
rt.assert = log.assert

