if table.unpack == nil then table.unpack = unpack end
assert(table.unpack ~= nil)

local _noop = function() return nil end

local _keys_iterator = function(t, k)
    local next_key, _ = next(t, k)
    return next_key
end

--- @brief iterate all keys of a table
function keys(t)
    if t == nil then return _noop end
    return _keys_iterator, t
end

--- @brief iterate all values of a table
function values(t)
    if t == nil then return _noop end
    local k, v
    return function()
        k, v = next(t, k)
        return v
    end
end

local function _range_iterator(state)
    local next_i, out = next(state, state[1])
    state[1] = next_i
    return out, state
end

--- @brief iterate vararg
function range(...)
    if select("#", ...) == 0 then return _noop end
    return _range_iterator, {1, ...}
end


--- @brief ternary
--- @param condition boolean
--- @param if_true any returned if condition == true
--- @param if_false any return if condition == false
function ternary(condition, if_true, if_false)
    if condition == true then
        return if_true
    elseif condition == false then
        return if_false
    else
        error("In ternary: argument #1 does not evaluate to boolean")
    end
end

--- @brief print, arguments are concatenated
--- @param vararg any
--- @return nil
function print(...)
    local values = {...}
    if string.len(values) == 0 then
        io.write("nil")
        return
    end

    for _, v in pairs({...}) do
        io.write(tostring(v))
    end
end

--- @brief print, arguments are concatenated with a newline in between each
--- @param vararg any
--- @return nil
function println(...)
    local n = select("#", ...)
    if n == 0 then
        io.write("nil\n")
        return
    end

    for i = 1, n do
        local value = select(i, ...)
        if value == nil then
            io.write("nil")
        else
            io.write(tostring(value))
        end
    end

    io.write("\n")
    io.flush()
end

--- @brief get number of elements in arbitrary object
--- @param x any
--- @return number
function table.sizeof(x)
    if type(x) == "table" then
        local n = 0
        for _ in pairs(x) do n = n + 1 end
        return n
    elseif type(x) == "string" then
        return #x
    elseif type(x) == "nil" then
        return 0
    else
        return 1
    end
end

--- @brief deepcopy table, fails for recursive tables
function table.deepcopy(t)
    if type(t) ~= "table" then return t end

    local function _deepcopy_inner(original, seen)
        if type(original) ~= 'table' then
            return original
        end

        if seen[original] then
            error("In deepcopy: table `" .. tostring(original) .. "` is recursive, it cannot be deepcopied")
            return {}
        end

        local copy = {}

        seen[original] = copy
        for k, v in pairs(original) do
            copy[_deepcopy_inner(k, seen)] = _deepcopy_inner(v, seen)
        end
        seen[original] = nil

        return copy
    end

    return _deepcopy_inner(t, {})
end

--- @brief is table empty
--- @param x any
--- @return boolean
function table.is_empty(x)
    if type(x) ~= "table" then
        return true
    else
        return next(x) == nil
    end
end

--- @brief create a table with n copies of object
--- @param x any
--- @param n Number
--- @return table
function table.rep(to_repeat, n)
    local out = table.new(n, 0)
    for i = 1, n do
        table.insert(out, to_repeat)
    end
    return out
end

--- @brief clear all values from table
--- @param t Table
--- @return nil
function table.clear(t)
    for key, _ in pairs(t) do
        t[key] = nil
    end
end

--- @brief
function table.first(t)
    for _, y in pairs(t) do
        return y
    end
end

function table.push(t, ...)
    for i = 1, select("#", ...) do
        table.insert(t, select(i, ...))
    end
end

function table.is_empty(t)
    return next(t) == nil
end

function table.pop(t)
    if next(t) == nil then
        return nil
    end
    return table.remove(t)
end

if utf8 == nil then utf8 = require "utf8" end

--- @brief get length of utf8 string
function utf8.size(str)
    return utf8.len(str)
end

--- @brife
function string.size(str)
    return #str
end

--- @brief concat respecting meta methods
function string.concat(delimiter, ...)
    local out = ""
    local n = select("#", ...)
    for i = 1, n do
        out = out .. tostring(select(i, ...))
        if i < n then
            out = out .. delimiter
        end
    end
    return out
end

--- @brief concatenate vararg into string
function string.paste(...)
    local out = {}
    for i = 1, select("#", ...) do
        local arg = select(i, ...)
        if arg == nil then
            table.insert(out, "nil")
        else
            table.insert(out, tostring(arg))
        end
    end
    return table.concat(out, "")
end

--- @brief
--- @param duration Number in seconds
function string.format_time(duration)
    local hours = math.floor(duration / 3600)
    local minutes = math.floor((duration % 3600) / 60)
    local seconds = math.floor(duration % 60)
    local milliseconds = math.floor((duration * 1000) % 1000)

    if hours >= 1 then
        return string.format("%2d:%02d:%02d.%03d", hours, minutes, seconds, milliseconds)
    elseif minutes >= 1 then
        return string.format("%2d:%02d.%03d", minutes, seconds, milliseconds)
    else
        return string.format("%2d.%03d s", seconds, milliseconds)
    end
end

--- @brief
function string.format_percentage(fraction)
    local percentage = math.floor(fraction * 1000) / 10
    if math.fmod(percentage, 1) == 0 then
        return percentage .. ".0 %"
    else
        return percentage .. " %"
    end
end

--- @brief get substring of utf8 string
--- @param s string
--- @param i Number starting index (in terms of conceptual characters)
--- @param j Number end index
function utf8.sub(s, i, j)
    i = i or 1
    j = j or -1
    if i < 1 or j < 1 then
        local n = utf8.len(s)
        if not n then return nil end
        if i < 0 then i = n + 1 + i end
        if j < 0 then j = n + 1 + j end
        if i < 0 then i = 1 elseif i > n then i = n end
        if j < 0 then j = 1 elseif j > n then j = n end
    end
    if j < i then return "" end
    i = utf8.offset(s, i)
    j = utf8.offset(s, j+1)
    if i and j then return string.sub(s, i,j - 1)
    elseif i then return string.sub(s, i)
    else return ""
    end
end

--- @brief get character at position in utf8 string
--- @param s string
--- @param i Number character index
function utf8.at(s, i)
    return utf8.sub(s, i, i)
end

--- @brief
function utf8.less_than(a, b)
    local a_len, b_len = utf8.len(a), utf8.len(b)
    for i = 1, math.min(a_len, b_len) do
        local ac, bc = utf8.codepoint(a, i), utf8.codepoint(b, i)
        if ac == bc then
        else
            return ac < bc
        end
    end

    if a_len ~= b_len then
        return utf8.len(a) < utf8.len(b)
    else
        return false
    end
end

--- @brief
function utf8.equal(a, b)
    if utf8.len(a) ~= utf8.len(b) then return false end
    for i = 1, utf8.len(a) do
        if utf8.codepoint(a, i) ~= utf8.codepoint(b, i) then
            return false
        end
    end
    return true
end

--- @brief
function utf8.greater_than(a, b)
    return not utf8.equal(a, b) and not utf8.less_than(a, b)
end

--- @brief make first letter capital
--- @param str string
function string.capitalize(str)
    assert(type(str) == "string")
    return string.upper(string.sub(str, 1, 1)) .. string.sub(str, 2, string.len(str))
end

--- @brief check if character is upper case or non-letter
function string.is_lower(str)
    assert(type(str) == "string" and string.len(str) == 1)
    return string.find(str, "[a-z]") ~= nil
end

--- @brief check if character is lower case
function string.is_upper(str)
    assert(type(str) == "string" and string.len(str) == 1)
    return string.find(str, "[A-Z1-9]") ~= nil
end

--- @brief get last character
function string.last(str)
    return string.sub(str, #str, #str)
end

--- @brief get first character
function string.first(str)
    return string.sub(str, 1, 1)
end

--- @brief split along character
function string.split(str, sep)
    assert(type(str) == "string")
    assert(type(sep) == "string" and #sep == 1)

    local out = {}
    local pattern = string.format("([^%s]+)", string.gsub(sep,
        "(%W)", -- not alpha-numeric
        "%%%1" -- "% literal" + first captured group
    ))

    for word in str:gmatch(pattern) do
        table.insert(out, word)
    end

    return table.unpack(out)
end


--- @brief check if pattern occurrs in string
--- @param str string
--- @param pattern string
--- @return boolean
function string.contains(str, pattern)
    return string.find(str, pattern) ~= nil
end

--- @brief replace expression in string
function string.replace(str, pattern, replacement)
    return string.gsub(str, pattern, replacement)
end

--- @brief get number of bits in string
function string.len(str)
    return #str
end

--- @brief
function string.at(str, i)
    return string.sub(str, i, i)
end

--- @brief hash string
function string.sha256(data)
    if love.getVersion() >= 12 then
        return love.data.encode("string", "hex", love.data.hash("string", "sha256", data))
    else
        local hash = love.data.hash("sha256", data)
        return love.data.encode("string", "hex", hash)
    end
end

--- @brief
function exit(status)
    if status == nil then status = 0 end
    love.event.push("quit", status)
end

local _tabspace = "    "
local _serialize_get_indent = function(n_indent_tabs)
    return string.rep(_tabspace, n_indent_tabs)
end

local _serialize_insert = function(buffer, ...)
    if buffer == nil then return end
    for i = 1, select("#", ...) do
        local value = select(i, ...)
        table.insert(buffer, value)
    end
end

local function _safe_comment_str(val)
    return tostring(val):gsub("%]%]", "] ]")
end

local function _serialize_inner(buffer, object, n_indent_tabs, seen, comment_out)
    local object_type = type(object)

    if object_type == "number" then
        if object == math.huge then
            _serialize_insert(buffer, "math.huge")
        elseif object == -math.huge then
            _serialize_insert(buffer, "-math.huge")
        elseif object ~= object then
            _serialize_insert(buffer, "(0/0)") -- NaN
        else
            _serialize_insert(buffer, tostring(object))
        end
    elseif object_type == "string" then
        _serialize_insert(buffer, string.format("%q", object))
    elseif object_type == "boolean" then
        _serialize_insert(buffer, object and "true" or "false")
    elseif object_type == "nil" then
        _serialize_insert(buffer, "nil")
    elseif object_type == "table" then
        if seen[object] then
            if comment_out then
                _serialize_insert(buffer, "nil --[[ cyclic table ]]")
            else
                _serialize_insert(buffer, "nil")
            end
            return
        end

        seen[object] = true

        local is_empty = true
        for _ in pairs(object) do
            is_empty = false
            break
        end

        if is_empty then
            _serialize_insert(buffer, "{}")
        else
            _serialize_insert(buffer, "{\n")
            n_indent_tabs = n_indent_tabs + 1

            for key, value in pairs(object) do
                local k_type = type(key)
                local v_type = type(value)

                local k_unserializable = (k_type == "function" or k_type == "userdata" or k_type == "thread")
                local v_unserializable = (v_type == "function" or v_type == "userdata" or v_type == "thread")

                -- check for immediate cycles to prevent evaluating keys to nil
                local k_cyclic = (k_type == "table" and seen[key])
                local v_cyclic = (v_type == "table" and seen[value])

                if k_unserializable or v_unserializable or k_cyclic or v_cyclic then
                    if comment_out then
                        local reason = "unserializable"
                        if k_cyclic or v_cyclic then reason = "cyclic reference" end

                        _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs),
                            "--[[ [\"", _safe_comment_str(key), "\"] = ", _safe_comment_str(value), " (", reason, ") ]],\n")
                    end
                else
                    _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs), "[")
                    _serialize_inner(buffer, key, n_indent_tabs, seen, comment_out)
                    _serialize_insert(buffer, "] = ")
                    _serialize_inner(buffer, value, n_indent_tabs, seen, comment_out)
                    _serialize_insert(buffer, ",\n")
                end
            end
            n_indent_tabs = n_indent_tabs - 1
            _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs), "}")
        end

        seen[object] = nil
    else
        if comment_out then
            _serialize_insert(buffer, "nil --[[ ", _safe_comment_str(object), " ]]")
        else
            _serialize_insert(buffer, "nil")
        end
    end
end

--- @brief convert arbitrary object to string
--- @param object any
--- @param comment_out_unserializable boolean false by default
--- @return string
local function _serialize(object, comment_out_unserializable)
    if comment_out_unserializable == nil then comment_out_unserializable = true end
    if object == nil then return "nil" end

    local buffer = {}
    local seen = {}
    _serialize_inner(buffer, object, 0, seen, comment_out_unserializable)
    return table.concat(buffer, "")
end

--- @brief validates if graph can be fully serialized without errors or cycle omissions
local function _is_serializable(value, seen)
    local value_type = type(value)

    if value_type == "function" or value_type == "userdata" or value_type == "thread" then
        return false
    end

    if value_type ~= "table" then
        return true
    end

    seen = seen or {}

    if seen[value] then
        return false -- cyclic
    end

    seen[value] = true

    for key, entry in pairs(value) do
        if not _is_serializable(key, seen) then
            return false
        end
        if not _is_serializable(entry, seen) then
            return false
        end
    end

    seen[value] = nil
    return true
end

--- @brief
function table.is_serializable(t)
    return _is_serializable(t, {})
end

--- @brief
function table.serialize(t)
    return _serialize(t, true)
end

--- @brief
function dbg(...)
    for _, x in pairs({...}) do
        io.write(_serialize(x))
        io.write(" ")
    end

    io.write("\n")
    io.flush()
end