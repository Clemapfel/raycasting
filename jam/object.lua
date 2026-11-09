Float_t = "float"
Integer_t = "integer"
Number_t = "number"
Boolean_t = "boolean"
String_t = "string"
Function_t = "function"
Nil_t = "nil"
Table_t = "table"

local _g_tostring = _G.tostring
local _typeof = _G.type

object_new = function(type, params)
    local out = { type = type }
    if params ~= nil then
        for key, value in pairs(params) do
            out[key] = value
        end
    end
    return out
end

object_is_float = function(x)
    return _typeof(x) == "number" and not (x ~= x) -- NaN
end

object_is_integer = function(x)
    return _typeof(x) == "number" and x % 1 == 0 and not (x ~= x)
end

object_is_number = function(x)
    return _typeof(x) == "number"
end

object_is_boolean = function(x)
    return _typeof(x) == "boolean"
end

object_is_string = function(x)
    return _typeof(x) == "string"
end

object_is_function = function(x)
    return _typeof(x) == "function"
end

object_is_nil = function(x)
    return x == nil
end

object_is_table = function(x)
    return _typeof(x) == "table"
end

local validators = {
    [Float_t] = object_is_float,
    [Integer_t] = object_is_integer,
    [Number_t] = object_is_number,
    [Boolean_t] = object_is_boolean,
    [String_t] = object_is_string,
    [Function_t] = object_is_function,
    [Nil_t] = object_is_nil,
    [Table_t] = object_is_table
}

object_to_string = function(x)
    if x == nil then
        return "nil"
    else
        return _g_tostring(x)
    end
end

object_isa = function(x, type)
    local validator = validators[type]
    if validator ~= nil then
        return validator(x)
    else
        local raw = _typeof(x)
        return raw == type or (raw == "table" and x.type == type)
    end
end

object_typeof = function(x)
    return _typeof(x)
end

object_copy = function(x)
    log_assert(x, Table_t)
    return table_deepcopy(x)
end

