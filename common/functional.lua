local _nil_t, _table_t, _function_t, _string_t, _number_t, _boolean_t = type(nil), type({}), type(function() end), type(""), type(0), type(true)
local _all_types = (function()
    local t = {}
    for _, which in ipairs({ _nil_t, _table_t, _function_t, _string_t, _number_t, _boolean_t }) do
        t[which] = true
    end
    return t
end)()

local _is_nil = function(x) return x == nil end
local _is_table = function(x) return type(x) == _table_t end
local _is_number = function(x) return type(x) == _number_t end
local _is_boolean = function(x) return type(x) == _boolean_t end
local _is_string = function(x) return type(x) == _string_t end
local _is_type = function(x) return _all_types[x] == true end

local _sizeof = function(x)
    return #x
end

local _type = _G.type
local _to_string = _G.tostring
local _select = _G.select
local _unpack = table.unpack or unpack

local _paste = function(...)
    local parts = {}
    for i = 1, _select("#", ...) do parts[i] = _to_string((_select(i, ...))) end
    return table.concat(parts)
end

local _error = function(...) error(_paste(...)) end
local _assert = function(condition, ...) assert(condition, _paste(...)) end

local _convert_functions = (function()
    local t = {}

    for _, which in ipairs({ _nil_t, _table_t, _function_t, _string_t, _number_t, _boolean_t}) do
        t[which] = {}
    end
    local throw = function(x, to)
        _error("unable to convert object `", x, "` to `", to, "`")
    end

    local to_identity_f = function(x) return x end
    local to_table_f = function(x) return { x } end
    local to_function_f = function(x) return function() return x end end

    local function from_table(to)
        return function(x)
            if _sizeof(x) == 1 then
                return t[_type(x[1])][to](x[1])
            else
                throw(x, to)
                return nil
            end
        end
    end

    local function from_function(to)
        return function(x)
            local out = { x() }
            if _sizeof(out) == 1 then
                return t[_type(out[1])][to](out[1])
            else
                throw(x, to)
                return nil
            end
        end
    end

    t[_nil_t][_nil_t] = to_identity_f
    t[_nil_t][_number_t] = function(x) return 0 end
    t[_nil_t][_boolean_t] = function(x) return false end
    t[_nil_t][_string_t] = function(x) return "nil" end
    t[_nil_t][_table_t] = function(x) return {} end
    t[_nil_t][_function_t] = function(x) return function() return nil end end

    t[_table_t][_table_t] = to_identity_f
    t[_table_t][_function_t] = to_function_f
    t[_table_t][_number_t] = from_table(_number_t)
    t[_table_t][_boolean_t] = from_table(_boolean_t)
    t[_table_t][_string_t] = from_table(_string_t)
    t[_table_t][_nil_t] = function(x)
        if _sizeof(x) == 0 then return nil end
        throw(x, _nil_t)
        return nil
    end

    t[_function_t][_function_t] = to_identity_f
    t[_function_t][_table_t] = to_table_f
    t[_function_t][_number_t] = from_function(_number_t)
    t[_function_t][_boolean_t] = from_function(_boolean_t)
    t[_function_t][_string_t] = from_function(_string_t)
    t[_function_t][_nil_t] = function(x)
        local out = { x() }
        if _sizeof(out) == 0 then return nil end
        throw(x, _nil_t)
        return nil
    end

    t[_string_t][_string_t] = to_identity_f
    t[_string_t][_table_t] = to_table_f
    t[_string_t][_function_t] = to_function_f
    t[_string_t][_boolean_t] = function(x)
        if x == "true" then
            return true
        elseif x == "false" then
            return false
        else
            throw(x, _boolean_t)
            return nil
        end
    end

    t[_string_t][_number_t] = function(x)
        local out = tonumber(x)
        if out == nil then
            throw(x, _number_t)
            return nil
        end
        return out
    end

    t[_string_t][_nil_t] = function(x)
        if x == "nil" then return nil end
        throw(x, _nil_t)
        return nil
    end

    t[_number_t][_number_t] = to_identity_f
    t[_number_t][_table_t] = to_table_f
    t[_number_t][_function_t] = to_function_f
    t[_number_t][_boolean_t] = function(x)
        if x == 1 then
            return true
        elseif x == 0 then
            return false
        else
            throw(x, _boolean_t)
            return nil
        end
    end

    t[_number_t][_string_t] = function(x)
        local out = _to_string(x)
        if out == nil then
            throw(x, _string_t)
            return nil
        end
        return out
    end

    t[_number_t][_nil_t] = function(x)
        throw(x, _nil_t)
        return nil
    end

    t[_boolean_t][_boolean_t] = to_identity_f
    t[_boolean_t][_table_t] = to_table_f
    t[_boolean_t][_function_t] = to_function_f
    t[_boolean_t][_number_t] = function(x)
        if x == true then
            return 1
        elseif x == false then
            return 0
        else
            throw(x, _number_t)
            return nil
        end
    end

    t[_boolean_t][_string_t] = function(x)
        if x == true then
            return "true"
        elseif x == false then
            return "false"
        else
            throw(x, _string_t)
            return nil
        end
    end

    t[_boolean_t][_nil_t] = function(x)
        throw(x, _nil_t)
        return nil
    end

    for a, _ in pairs(_all_types) do
        for b, _ in pairs(_all_types) do
            _assert(t[a] ~= nil and t[a][b] ~= nil)
        end
    end

    return t
end)()

local _cast = function(to, x)
    local f = _convert_functions[_type(x)][to]
    if f == nil then _error("In _convert: no function for types `", _type(x), "` -> `", to, "`") end
    return f(x)
end

local _new_proxy = function(...)
    local self = { _ = { ... } }

    local resolve = function(...)
        local type, f
        if _select("#", ...) == 2 then
            type, f = _select(1, ...), _select(2, ...)
        elseif _select("#", ...) == 1 then
            f = _select(1, ...)
        else
            _error("In _new_proxy.resolve: incorrect number of arguments `", _select("#", ...))
        end

        local function proxy_resolve_inner(t)
            for i, v in pairs(t) do
                if _is_table(v) then
                    proxy_resolve_inner(v)
                else
                    if type ~= nil and _type(v) ~= type then
                        v = _cast(type, v)
                    end
                    
                    t[i] = f(v)
                end
            end
        end

        proxy_resolve_inner(self._)
    end

    self.identity = function()
        return self._
    end

    self.print = function()
        local function print_inner(t, indent)
            indent = indent or ""
            local next_indent = indent .. "  "

            if not _is_table(t) then
                io.write(_to_string(t))
                return
            end

            local n = _sizeof(t)
            local is_array = true
            for k, _ in pairs(t) do
                if not _is_number(k)
                    or k < 1
                    or k > n
                    or k ~= math.floor(k)
                then
                    is_array = false
                    break
                end
            end

            io.write("{\n")
            if is_array then
                for i = 1, n do
                    io.write(next_indent)
                    print_inner(t[i], next_indent)
                    io.write(i < n and ",\n" or "\n")
                end
            else
                local keys = {}
                for k, _ in pairs(t) do keys[_sizeof(keys) + 1] = k end
                table.sort(keys, function(a, b)
                    return _to_string(a) < _to_string(b)
                end)

                for index, k in ipairs(keys) do
                    io.write(next_indent)
                    if _is_string(k) then
                        io.write(k, " = ")
                    else
                        io.write("[", _to_string(k), "] = ")
                    end
                    print_inner(t[k], next_indent)
                    io.write(index < _sizeof(keys) and ",\n" or "\n")
                end
            end
            io.write(indent .. "}")
        end

        print_inner(self._, "")
        io.write("\n")
        io.flush()
        return self
    end

    self.add = function(to_add)
        resolve(_number_t, function(x)
            return x + to_add
        end)
        return self
    end

    self.subtract = function(to_subtract)
        resolve(_number_t, function(x)
            return x - to_subtract
        end)
        return self
    end

    self.multiply = function(to_multiply)
        resolve(_number_t, function(x)
            return x * to_multiply
        end)
        return self
    end

    self.divide = function(to_divide)
        resolve(_number_t, function(x)
            return x / to_divide
        end)
        return self
    end

    self.pow = function(exponent)
        resolve(_number_t, function(x)
            return x ^ exponent
        end)
        return self
    end

    self.sqrt = function()
        resolve(_number_t, function(x)
            return math.sqrt(x)
        end)
        return self
    end

    local success, bit = pcall(require, "bit")
    if success then
        local bit_op = function(op)
            return function(other)
                resolve(_number_t, function(x)
                    return op(bit.tobit(x), bit.tobit(other))
                end)
                return self
            end
        end
        
        self.bit_not = bit_op(function(a) return bit.bnot(a) end)
        self.bit_and = bit_op(function(a, b) return bit.band(a, b) end)
        self.bit_or = bit_op(function(a, b) return bit.bor(a, b) end)
        self.bit_xor = bit_op(function(a, b) return bit.bxor(a, b) end)
        self.bit_left_shift = bit_op(function(a, b) return bit.lshift(a, b) end)
        self.bit_right_shift = bit_op(function(a, b) return bit.rshift(a, b) end)
        self.bit_rotate_left = bit_op(function(a, b) return bit.rol(a, b) end)
        self.bit_rotate_right = bit_op(function(a, b) return bit.ror(a, b) end)
        self.bit_byte_swap = bit_op(function(a) return bit.bswap(a) end)
    end

    self.iterate = function()
        return ipairs(self._)
    end

    self.series = function()
        local from = _cast(_number_t, self._[1])
        local to = _cast(_number_t, self._[2])
        local step = _cast(_number_t, self._[3])

        if step == nil then step = (from <= to) and 1 or -1 end

        if step == 0 then
            _error("In series: step cannot be 0")
            return function() return nil end
        end

        local i = 0
        return function()
            local value = from + i * step

            if (step > 0 and value > to) or (step < 0 and value < to) then
                return nil
            end

            i = i + 1
            return value
        end
    end

    self.apply = function(to_apply, ...)
        local args = { ... }
        local function apply_inner(t)
            for i, v in pairs(t) do
                if _is_table(v) then
                    apply_inner(v)
                else
                    t[i] = to_apply(v, table.unpack(args))
                end
            end
        end

        apply_inner(self._)
        return self
    end

    self.collect = function(to_apply, ...)
        local args = { ... }
        local function collect_inner(t)
            local res = {}
            for i, v in pairs(t) do
                if _is_table(v) then
                    res[i] = collect_inner(v)
                else
                    res[i] = to_apply(v, table.unpack(args))
                end
            end
            return res
        end

        self._ = collect_inner(self._)
        return self
    end

    local function cast_all(t, type_t)
        for k, v in pairs(t) do
            if _is_table(v) then
                cast_all(v, type_t)
            else
                t[k] = _cast(type_t, v)
            end
        end
    end

    self.to_nil = function()
        cast_all(self._, _nil_t)
        return self
    end

    self.to_number = function()
        cast_all(self._, _number_t)
        return self
    end

    self.to_boolean = function()
        cast_all(self._, _boolean_t)
        return self
    end

    self.to_string = function()
        cast_all(self._, _string_t)
        return self
    end

    self.to_function = function()
        cast_all(self._, _function_t)
        return self
    end

    self.to_table = function()
        cast_all(self._, _table_t)
        return self
    end

    self.at = function(...)
        local current = self._
        for i = 1, _select("#", ...) do
            local index = _select(i, ...)
            current = _cast(_table_t, current)[index]
        end
        return current
    end

    self.insert = function(i, element)
        if element == nil then
            element = i
            local function add_inner(t)
                for k, v in pairs(t) do
                    if _is_table(v) then
                        add_inner(v)
                    end
                end
                if _is_table(t) then
                    table.insert(t, element)
                elseif _is_string(t) then
                    t = t .. _to_string(element)
                end
            end
            add_inner(self._)
        else
            local index = _cast(_number_t, i)
            local function add_at_inner(t)
                for k, v in pairs(t) do
                    if _is_table(v) then
                        add_at_inner(v)
                    end
                end
                if _is_table(t) then
                    table.insert(t, math.floor(index), element)
                elseif _is_string(t) then
                    local p1 = string.sub(t, 1, math.floor(index) - 1)
                    local p2 = string.sub(t, math.floor(index))
                    t = p1 .. _to_string(element) .. p2
                end
            end
            add_at_inner(self._)
        end
        return self
    end

    self.remove = function(element)
        local function remove_inner(x)
            if _is_table(x) then
                local i = 1
                while i <= #x do
                    if x[i] == element then
                        table.remove(x, i)
                    else
                        remove_inner(x[i])
                        i = i + 1
                    end
                end
                for k, v in pairs(x) do
                    if not _is_number(k) then
                        if v == element then
                            x[k] = nil
                        else
                            remove_inner(v)
                        end
                    end
                end
            elseif _is_string(x) and _is_string(element) then
                return string.gsub(x, element, "")
            end
            return x
        end
        self._ = remove_inner(self._)
        return self
    end

    self.replace = function(element, to_replace_with)
        local function replace_inner(x)
            if _is_table(x) then
                for k, v in pairs(x) do
                    if v == element then
                        x[k] = to_replace_with
                    else
                        x[k] = replace_inner(v)
                    end
                end
            elseif _is_string(x) and _is_string(element) then
                return string.gsub(x, element, _to_string(to_replace_with))
            elseif x == element then
                return nil
            end
            return x
        end
        self._ = replace_inner(self._)
        return self
    end

    self.remove_at = function(i)
        local index = _cast(_number_t, i)
        local function remove_at_inner(x)
            if _is_table(x) then
                if index >= 1 and index <= #x and index == math.floor(index) then
                    table.remove(x, math.floor(index))
                end
                for k, v in pairs(x) do
                    if _is_table(v) then remove_at_inner(v) end
                end
            elseif _is_string(x) then
                local f = math.floor(index)
                if f >= 1 and f <= string.len(x) then
                    return string.sub(x, 1, f - 1) .. string.sub(x, f + 1)
                end
            elseif index == 1 then
                return nil
            end
            return x
        end
        self._ = remove_at_inner(self._)
        return self
    end

    self.replace_at = function(i, to_replace_with)
        local index = _cast(_number_t, i)
        local function replace_at_inner(x)
            if _is_table(x) then
                local f = math.floor(index)
                if f >= 1 and f <= #x then
                    x[f] = to_replace_with
                end
                for k, v in pairs(x) do
                    if _is_table(v) then replace_at_inner(v) end
                end
            elseif _is_string(x) then
                local f = math.floor(index)
                if f >= 1 and f <= string.len(x) then
                    return string.sub(x, 1, f - 1) .. _to_string(to_replace_with) .. string.sub(x, f + 1)
                end
            elseif index == 1 then
                return to_replace_with
            end
            return x
        end
        self._ = replace_at_inner(self._)
        return self
    end

    self.size = function()
        return _sizeof(self._)
    end

    -- if it is a table { x, y, z }, create a table { x, y, z, x, y, z, ... }
    -- if it is a string "xyz", replace it with "xyzxyz..."
    -- otherwise, replace x with { x, x, ... }
    self.duplicate = function(n)

    end

    -- if f(v) compares true for the value, replace it with nil, recursively
    self.filter = function(f)

    end

    -- if n is positive, drop first n elements of string / table
    -- if n is negative, drop last abs(n) elements
    self.drop = function(n)

    end

    -- if n is positive, drop last n - 1 elements of string/table
    -- if n is negative, drop first abs(n) elements of string/table
    self.keep = function(n)

    end

    --
    self.append = function(to_append)
        local function copy(x)
            if not _is_table(x) then return x end
            local out = {}
            for k, v in pairs(x) do out[k] = copy(v) end
            return out
        end

        if _is_table(to_append) then
            local m = _sizeof(to_append)

            local function append_inner_table(t)
                for _, v in pairs(t) do
                    if _is_table(v) then append_inner_table(v) end
                end

                local n = _sizeof(t)
                for i = 1, m do
                    t[n + i] = copy(to_append[i])
                end
                for k, v in pairs(to_append) do
                    local in_array = _is_number(k) and k >= 1 and k <= m and k == math.floor(k)
                    if not in_array then t[k] = copy(v) end
                end
            end

            append_inner_table(self._)
        else
            local suffix = _cast(_string_t, to_append)
            local function append_inner_string(t)
                for i, v in pairs(t) do
                    if _is_table(v) then
                        append_inner_string(v)
                    else
                        t[i] = _cast(_string_t, v) .. suffix
                    end
                end
            end

            append_inner_string(self._)
        end

        return self
    end

    self.reverse = function()
        local function reverse_inner(x)
            if _is_string(x) then
                local to_concat = {}
                for i = string.len(x), 1, -1 do
                    to_concat[#to_concat + 1] = string.sub(x, i, i)
                end
                return table.concat(to_concat)
            elseif _is_table(x) then
                local n = _sizeof(x)
                local out = {}
                for k, v in pairs(x) do
                    if _is_number(k)
                        and k >= 1
                        and k <= n
                        and k == math.floor(k)
                    then
                        out[n - k + 1] = reverse_inner(v)
                    else
                        out[k] = reverse_inner(v)
                    end
                end
                return out
            else
                return x
            end
        end

        self._ = reverse_inner(self._)
        return self
    end

    self.interlace = function(other)
        local other_value = _is_table(other) and other or (other._ and other._ or { other })
        if other._ then other_value = other._ end

        local function interlace_inner(x)
            if _is_table(x) then
                local out = {}
                local max_len = math.max(#x, #other_value)
                local index = 1
                for i = 1, max_len do
                    if i <= #x then
                        out[index] = interlace_inner(x[i])
                        index = index + 1
                    end

                    if i <= #other_value then
                        out[index] = other_value[i]
                        index = index + 1
                    end
                end
                return out
            elseif _is_string(x) then
                local other_str = _cast(_string_t, other_value[1] or "")
                local out = {}
                local max_len = math.max(string.len(x), string.len(other_str))
                for i = 1, max_len do
                    if i <= string.len(x) then
                        table.insert(out, string.sub(x, i, i))
                    end
                    if i <= string.len(other_str) then
                        table.insert(out, string.sub(other_str, i, i))
                    end
                end
                return table.concat(out)
            else
                local t = { x }
                local out = {}
                local max_len = math.max(1, #other_value)
                local index = 1
                for i = 1, max_len do
                    if i <= 1 then
                        out[index] = t[1]
                        index = index + 1
                    end

                    if i <= #other_value then
                        out[index] = other_value[i]
                        index = index + 1
                    end
                end
                return out
            end
        end

        self._ = interlace_inner(self._)
        return self
    end

    return self
end

_G.new = function(...)
    return _new_proxy(...)
end