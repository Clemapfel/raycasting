if table.unpack == nil then table.unpack = unpack end
assert(table.unpack ~= nil)

if debug.setfenv == nil then debug.setfenv = setfenv end
assert(debug.setfenv ~= nil)

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
    return function() -- impossible to do without closure
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
    return _range_iterator, {1, ...} -- start at 1, because because actual table is by one
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

--- @brief print, arguments are concatenade with a newline in between each
--- @param vararg any
--- @return nil
function println(...)
    local values = {...}
    if #values == 0 then
        io.write("nil\n")
        return
    end

    for _, v in pairs(values) do
        io.write(tostring(v))
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
        for _ in pairs(x) do
            n = n + 1
        end
        return n
    elseif type(x) == "string" then
        return #x
    elseif type(x) == "nil" then
        return 0
    else
        return 1
    end
end

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

--- @brief deepcopy table, fails for recursive tables
function table.deepcopy(t)
    if type(t) ~= "table" then return t end
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

--- @brief clamp
--- @param x number
--- @param lower_bound number
--- @param upper_bound number
--- @return number
function math.clamp(x, lower_bound, upper_bound)
    if type(lower_bound) == "nil" then lower_bound = -math.huge end
    if type(upper_bound) == "nil" then upper_bound = math.huge end

    if x < lower_bound then
        x = lower_bound
    end

    if x > upper_bound then
        x = upper_bound
    end

    return x
end

--- @brief
function math.project(value, lower, upper)
    return value * math.abs(upper - lower) + math.min(lower, upper);
end

--- @brief linear interpolate between two values
--- @param lower number
--- @param upper number
--- @param ratio number in [0, 1]
--- @return number
function math.mix(lower, upper, ratio)
    -- @see https://registry.khronos.org/OpenGL-Refpages/gl4/html/mix.xhtml
    return lower * (1 - ratio) + upper * ratio
end

--- @brief
function math.smoothstep(lower, upper, ratio)
    local t = clamp((ratio - lower) / (upper - lower), 0.0, 1.0);
    return t * t * (3.0 - 2.0 * t);
end

--- @brief
function math.fract(x)
    return math.fmod(x, 1.0)
end

--- @brief round to nearest integer
--- @param i number
--- @return number
function math.round(i)
    return math.floor(i + 0.5)
end

--- @brief
function math.sign(x)
    if x > 0 then
        return 1
    elseif x < 0 then
        return -1
    else
        return 0
    end
end

--- @brief evaluate erf integral
--- @param x number
--- @return number
function math.erf(x)
    -- src: https://hewgill.com/picomath/lua/erf.lua.html
    local a1 =  0.254829592
    local a2 = -0.284496736
    local a3 =  1.421413741
    local a4 = -1.453152027
    local a5 =  1.061405429
    local p  =  0.3275911

    local sign = 1
    if x < 0 then
        sign = -1
    end
    x = math.abs(x)

    local t = 1.0 / (1.0 + p * x)
    local y = 1.0 - (((((a5 * t + a4) * t) + a3) * t + a2) * t + a1) * t * math.exp(-x * x)
    return sign * y
end

--- @brief hyperbolic tangent
--- @param x number
--- @return number
function math.tanh(x)
    -- src: http://lua-users.org/wiki/HyperbolicFunctions
    if x == 0 then return 0.0 end
    local neg = false
    if x < 0 then x = -x; neg = true end
    if x < 0.54930614433405 then
        local y = x * x
        x = x + x * y *
            ((-0.96437492777225469787e0 * y +
                -0.99225929672236083313e2) * y +
                -0.16134119023996228053e4) /
            (((0.10000000000000000000e1 * y +
                0.11274474380534949335e3) * y +
                0.22337720718962312926e4) * y +
                0.48402357071988688686e4)
    else
        x = math.exp(x)
        x = 1.0 - 2.0 / (x * x + 1.0)
    end
    if neg then x = -x end
    return x
end

--- @brief normalize a vector
--- @param x number x component of the vector
--- @param y number y component of the vector
--- @return number, number normalized x and y components
function math.normalize(x, y)
    local magnitude = math.sqrt(x * x + y * y)
    if magnitude == 0 then
        return 0, 0
    else
        return x / magnitude, y / magnitude
    end
end

--- @brief
function math.magnitude(x, y)
    return math.sqrt(x * x + y * y)
end

--- @brief
function math.angle(x, y)
    return math.atan2(y, x)
end

--- @brief
function math.translate_by_angle(x, y, angle, distance)
    return x + math.cos(angle) * distance, y + math.sin(angle) * distance
end

--- @brief get distance between two points
--- @param x1 number x component of the first point
--- @param y1 number y component of the first point
--- @param x2 number x component of the second point
--- @param y2 number y component of the second point
--- @return number the distance between the two points
function math.distance(x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    return math.sqrt(dx * dx + dy * dy)
end

--- @brief create a table with n copies of object
--- @param x any
--- @param n Number
--- @return table
function table.rep(x, n)
    local out = {}
    for i = 1, n do
        table.insert(out, x)
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

if utf8 == nil then utf8 = require "utf8" end

--- @brief
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

--- @brief
function utf8.sub(s,i,j)
    -- src: http://lua-users.org/lists/lua-l/2014-04/msg00590.html
    i = i or 1
    j = j or -1
    if i<1 or j<1 then
        local n = utf8.len(s)
        if not n then return nil end
        if i<0 then i = n+1+i end
        if j<0 then j = n+1+j end
        if i<0 then i = 1 elseif i>n then i = n end
        if j<0 then j = 1 elseif j>n then j = n end
    end
    if j<i then return "" end
    i = utf8.offset(s,i)
    j = utf8.offset(s,j+1)
    if i and j then return string.sub(s, i,j-1)
    elseif i then return string.sub(s, i)
    else return ""
    end
end

--- @brief
function utf8.less_than(a, b)
    local a_len, b_len = utf8.len(a), utf8.len(b)
    for i = 1, math.min(a_len, b_len) do
        local ac, bc = utf8.codepoint(a, i), utf8.codepoint(b, i)
        if ac == bc then
            -- continue
        else
            return ac < bc
        end
    end

    -- codepoints equal, but possible different lengths
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
function string.split(str, separator)
    assert(type(str) == "string")
    assert(type(separator) == "string")

    local out = {}
    for word, _ in string.gmatch(str, "([^".. separator .."]+)") do
        table.insert(out, word)
    end
    return out
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
function string.sha256(string)
    local hash
    if love.getVersion() >= 12 then
        hash = love.data.hash("string", "sha256", string)
    else
        hash = love.data.hash("sha256", string)
    end
    return hash
end

--- @brief
function exit(status)
    if status == nil then status = 0 end
    love.event.push("quit", status)
end

local _serialize_get_indent = function(n_indent_tabs)
    local tabspace = "    "
    local buffer = {""}

    for i = 1, n_indent_tabs do
        table.insert(buffer, tabspace)
    end

    return table.concat(buffer)
end

local _serialize_insert = function(buffer, ...)
    for i, value in pairs({...}) do
        table.insert(buffer, value)
    end
end

local function _serialize_inner(buffer, object, n_indent_tabs, seen, comment_out)
    if type(object) == "number" then
        _serialize_insert(buffer, object)
    elseif type(object) == "string" then
        _serialize_insert(buffer, "\"", object, "\"")
    elseif type(object) == "boolean" then
        if object == true then
            _serialize_insert(buffer, "true")
        else
            _serialize_insert(buffer, "false")
        end
    elseif type(object) == "nil" then
        _serialize_insert(buffer, "nil")
    elseif type(object) == "table" then
        local n_entries = table.sizeof(object)
        if seen[object] then
            _serialize_insert(buffer, " { ...")
            return
        end

        if n_entries > 0 then
            _serialize_insert(buffer, "{\n")
            n_indent_tabs = n_indent_tabs + 1

            local index = 0
            for key, value in pairs(object) do
                if comment_out and type(value) == "function" or type(value) == "userdata" then
                    _serialize_insert(buffer, "--[[ ", key, " = ", tostring(value), ", ]]\n")
                    index = index + 1
                elseif comment_out and seen[object] then
                    _serialize_insert(buffer, "--[[ ", key, " = ..., ]]\n")
                    index = index + 1
                else
                    if type(key) == "string" then
                        _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs), "[\"", tostring(key), "\"]", " = ")
                    elseif type(key) == "number" then
                        _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs), "[", tostring(key), "] = ")
                    else
                        _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs), "[", serialize(key), "] = ")
                    end

                    _serialize_inner(buffer, value, n_indent_tabs, seen)

                    index = index + 1
                    if index < n_entries then
                        _serialize_insert(buffer, ",\n")
                    else
                        _serialize_insert(buffer, "\n")
                    end
                end
            end
            _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs-1), "}")
        else
            _serialize_insert(buffer, "{}")
        end

        seen[object] = true
    else
        -- function, userdata, when not commented out
        _serialize_insert(buffer, "[", tostring(object), "]")
    end
end

--- @brief convert arbitrary object to string
--- @param object any
--- @param comment_out_unserializable Boolean false by default
--- @return string
function serialize(object, comment_out_unserializable)
    if comment_out_unserializable == nil then
        comment_out_unserializable = false
    end

    if object == nil then
        return nil
    end

    local buffer = {""}
    local seen = {}
    _serialize_inner(buffer, object, 0, seen, comment_out_unserializable)
    return table.concat(buffer, "")
end

--- @brief
function dbg(...)
    for _, x in pairs({...}) do
        io.write(serialize(x))
        io.write(" ")
    end

    io.write("\n")
    io.flush()
end

