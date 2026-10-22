local worker_to_main, MessageType = ...

-- no rt includes, log worker must be clean room

require "love.filesystem"
require "love.system"
io.stdout:setvbuf("no")

function exists(path)
    return love.filesystem.getInfo(path) ~= nil
end

function is_file(path)
    local info = love.filesystem.getInfo(path)
    return info ~= nil and info.type == "file"
end

function is_directory(path)
    local info = love.filesystem.getInfo(path)
    return info ~= nil and info.type == "file"
end

function create_directory(path)
    love.filesystem.createDirectory(path)
end

function open_file(path)
    local res, error_maybe = love.filesystem.newFile(path, "a")
    if res == nil then
        fatal("In rt.LogWorker: when trying to open file at `", path, "`. ", error_maybe)
    end
    return res
end

function join_path(...)
    return table.concat({ ... }, "/")
end

function get_save_directory()
    if love.filesystem.isFused() then
        return join_path(love.filesystem.getAppdataDirectory(), love.filesystem.getIdentity())
    else
        return join_path(love.filesystem.getAppdataDirectory(), "love", love.filesystem.getIdentity())
    end
end

function fatal(...)
    error(table.concat({ ... }))
end

do
    local escape_map = {
        ["\\"] = "\\\\",
        ["\""] = "\\\"",
        ["\b"] = "\\b",
        ["\f"] = "\\f",
        ["\n"] = "\\n",
        ["\r"] = "\\r",
        ["\t"] = "\\t",
    }

    local function escape(str)
        str = string.gsub(str, "[%c\"\\]", function(c)
            return escape_map[c] or string.format("\\u%04x", string.byte(c))
        end)
        return "\"" .. str .. "\""
    end

    local pretty_print = false -- use indents, for debugging only
    function serialize(v, indent, level)
        if pretty_print then
            indent = indent or "  "
        else
            indent = ""
        end
        level = level or 0

        local newline = pretty_print and "\n" or ""
        local colon = pretty_print and ": " or ":"
        local padding = pretty_print and string.rep(indent, level + 1) or ""
        local close_padding = pretty_print and string.rep(indent, level) or ""
        local sep = "," .. newline .. padding

        local current_type = type(v)
        if current_type == "table" then
            local n = #v
            local count = 0
            for _ in pairs(v) do
                count = count + 1
            end

            if count == 0 then
                return "[]"
            end

            local parts = {}
            if count == n then
                for i = 1, n do
                    parts[i] = serialize(v[i], indent, level + 1, pretty_print) or "null"
                end
                return "[" .. newline .. padding .. table.concat(parts, sep) .. newline .. close_padding .. "]"
            end

            for k, val in pairs(v) do
                local s = serialize(val, indent, level + 1, pretty_print)
                if s ~= nil then
                    parts[#parts + 1] = escape(tostring(k)) .. colon .. s
                end
            end
            return "{" .. newline .. padding .. table.concat(parts, sep) .. newline .. close_padding .. "}"
        elseif current_type == "string" then
            return escape(v)
        elseif current_type == "boolean" then
            return v and "true" or "false"
        elseif current_type == "number" then
            return tostring(v)
        else
            return nil
        end
    end
end

-- ### MAIN ###

local log_prefix = "logs"
if is_file(log_prefix) then
    fatal("In rt.LogWorker: file at `", join_path(get_save_directory(), log_prefix), "` already exists and is not a directory.")
end

if not exists(log_prefix) then
    create_directory(log_prefix)
end

local inverted = string.format("%011d", os.time())

local log_name = table.concat({
    inverted,
    os.date("%Y_%m_%d_%H_%M_%S", os.time()),
    love.system.getOS(),
}, "_") .. ".log"

local file = open_file(join_path(log_prefix, log_name))

while true do
    local message = worker_to_main:demand()
    if message.type == MessageType.EXIT then
        break
    else
        local success, error = pcall(function()
            if type(message.value) == "table" then
                file:write(message.type .. " " .. serialize(message.value) .. "\n")
            else
                file:write(message.type .. " " .. message.value .. "\n")
            end
            file:flush()
        end)

        if not success then
            -- try to recover in case of errors
            file = open_file(join_path(log_prefix, log_name))
            file:write(MessageType.ERROR .. " " .. error)
        end
    end
end

file:close()