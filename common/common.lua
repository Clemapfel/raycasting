if table.unpack == nil then table.unpack = unpack end
assert(table.unpack ~= nil)

require "common.compat"

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
            _G.error("In deepcopy: table `" .. tostring(original) .. "` is recursive, it cannot be deepcopied")
            return {}
        end

        local copy = table.new(#original, 0)

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

--- @brief
function table.count(t)
    local n = 0
    for _ in pairs(t) do n = n + 1 end
    return n
end

--- @brief
function table.sub(t, i, j)
    local n = #t
    i = i or 1
    j = j or -1

    if i < 0 then i = n + i + 1 end
    if j < 0 then j = n + j + 1 end

    if i < 1 then i = 1 end
    if j > n then j = n
    end

    local result = {}
    for k = i, j do
        table.insert(result, t[k])
    end
    return table.unpack(result)
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

--- @brief
function string.unique_timestamp()
    local time = os.time()
    return table.concat({
        string.format("%011d", time),
        os.date("%Y_%m_%d_%H_%M_%S", time)
    }, "_")
end

--- @brief
function string.reverse(str)
    local to_concat = table.new(string.len(str), 0)
    for i = 1, string.len(str) do
        table.insert(to_concat, 1, string.at(str, i))
    end
    return table.concat(to_concat)
end

--- @brief
function string.interlace(a, b)
    local a_n = string.len(a)
    local b_n = string.len(b)
    local to_concat = table.new(a_n + b_n, 0)
    local n = 0

    for i = 1, math.max(a_n, b_n) do
        if i <= a_n then
            n = n + 1
            to_concat[n] = string.at(a, i)
        end

        if i <= b_n then
            n = n + 1
            to_concat[n] = string.at(b, i)
        end
    end

    return table.concat(to_concat)
end

--- @brief
function string.deinterlace(a_length, str)
    assert(type(a_length) == "number", type(str) == "string", "In string.deinterlace: wrong argument types")

    local total = string.len(str)
    local b_length = total - a_length

    local a_buffer = table.new(a_length, 0)
    local b_buffer = table.new(b_length, 0)
    local na, nb = 0, 0

    for i = 1, total do
        local current = string.at(str, i)

        local take_a
        if na < a_length and nb < b_length then
            take_a = (na == nb)
        else
            take_a = na < a_length
        end

        if take_a then
            na = na + 1
            a_buffer[na] = current
        else
            nb = nb + 1
            b_buffer[nb] = current
        end
    end

    return table.concat(a_buffer), table.concat(b_buffer)
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
function string.encode(str, type)
    return love.data.encode("string", type or "base64", str)
end

--- @brief
function string.decode(str, type)
    return love.data.decode("string", type or "base64", str)
end

--- @brief
function exit(status)
    if status == nil then status = 0 end
    love.event.push("quit", status)
end

--- @brief deallocate a love, rt, functional, or box2d object
--- @param object Any
--- @return Boolean
function free(...)
    local n_freed = 0
    for i = 1, select("#", ...) do
        local object = select(i, ...)
        if object == nil or not (meta.is_table(object) or meta.is_userdata(object)) then
            break
        end

        local native = nil
        if meta.is_function(object.get_native) then
            native = object:get_native()
        elseif object._native ~= nil then
            native = object._native
        end

        for _, x in ipairs({ object, native }) do
            if meta.is_function(x.free) then
                x:free()
                n_freed = n_freed + 1
            elseif meta.is_function(x.release) then
                x:release()
                n_freed = n_freed + 1
            elseif meta.is_function(x.destroy) then
                x:destroy()
                n_freed = n_freed + 1
            end
        end
    end

    return n_freed == select("#", ...)
end

do
    local success, new = pcall(require, "table.new")
    if success then
        local _table_new = new
        table.new = function(array_size, dict_size, ...)
            if array_size == nil then array_size = 0 end
            if dict_size == nil then dict_size = 0 end
            return _table_new(array_size, dict_size, ...)
        end
    else
        table.new = function(array_size, dict_size)
            return {}
        end
    end
end

do
    local success, clear = pcall(require, "table.clear")
    if type(table.clear) == "function" then
        local _table_clear = clear
        table.clear = function(...)
            return _table_clear(...)
        end
    else
        table.clear = function(t)
            for k, _ in pairs(t) do
                t[k] = nil
            end
            return t
        end
    end
end

--- @brief
function table.encrypt(t)
    rt.assert(
        table.is_serializable(t),
        "In table.encrypt: table is not fully serializable"
    )

    local function encrypt_table(t)
        local seen = {}
        local function encrypt_inner(v)
            if meta.is_string(v) then
                return string.reverse(string.encode(v, "base64"))
            elseif meta.is_table(v) then
                if seen[v] then
                    return seen[v]
                end

                local out = {}
                seen[v] = out

                for k2, v2 in pairs(v) do
                    out[encrypt_inner(k2)] = encrypt_inner(v2)
                end
                return out
            end

            return v
        end

        return encrypt_inner(t)
    end

    local encrypted = t -- encrypt_table(table.deepcopy(t))
    local serialized = "return " .. table.serialize(encrypted)

    love.filesystem.write("temp", string.dump(loadstring(serialized), true))

    local bytecode = string.reverse(string.dump(loadstring(serialized), true)) -- no line numbers
    return string.interlace(string.encode(bytecode), string.sha256(bytecode))
end

function table.decrypt(str)
    local function decrypt_table(t)
        local seen = {}
        local function decrypt_inner(v)
            if meta.is_table(v) then
                if seen[v] then
                    return seen[v]
                end

                local out = {}
                seen[v] = out
                for k2, v2 in pairs(v) do
                    out[decrypt_inner(k2)] = decrypt_inner(v2)
                end
                return out
            elseif meta.is_string(v) then
                    return string.decode(string.reverse(v), "base64")
                else
            end

            return v
        end

        return decrypt_inner(t)
    end

    local encoded, hash = string.deinterlace(string.len(str) - 64, str)
    local reversed = string.decode(encoded)

    if string.sha256(reversed) ~= hash then
        rt.critical("In table.decrypt: cryptographic verification failed, the data may have been modified or corrupted")
    end

    local success, result = pcall(bd.load_string, string.reverse(reversed))
    if not success or not meta.is_table(result) then
        return nil
    end

    return decrypt_table(result)
end

require "common.serialize"

--- @brief
function dbg(...)
    for _, x in pairs({...}) do
        if meta.is_table(x) then
            io.write(tostring(meta.typeof(x)))
            io.write(" ")
        end

        if meta.is_string(x) then
            io.write(x)
        else
            io.write(table.serialize(x))
        end
        io.write(" ")
    end

    io.write("\n")
    io.flush()
end

--- @brief
function rerequire(module)
    package.loaded[module] = nil
    require(module)
end
