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

local _tostring = function(val)
    if type(val) == "table" and getmetatable(val) ~= nil then
        local mt = getmetatable(val)
        local before = mt.__tostring
        mt.__tostring = nil
        local out = tostring(val)
        mt.__tostring = before
        return out
    else
        return tostring(val)
    end
end

local function _safe_comment_str(val)
    return string.gsub(_tostring(val), "%]%]", "] ]")
end

local _is_type_serializable = function(t)
    return t ~= "function" and t ~= "userdata" and t ~= "thread" and t ~= "cdata"
end

local _seen = {}

local function _serialize_inner(buffer, object, n_indent_tabs, comment_out, disallowed_types)
    local object_type = type(object)
    if object_type == "number" and disallowed_types["number"] ~= true then
        if object == math.huge then
            _serialize_insert(buffer, "math.huge")
        elseif object == -math.huge then
            _serialize_insert(buffer, "-math.huge")
        elseif object ~= object then
            _serialize_insert(buffer, "(0/0)") -- NaN
        else
            _serialize_insert(buffer, _tostring(object))
        end
    elseif object_type == "string" and disallowed_types["string"] ~= true then
        _serialize_insert(buffer, string.format("%q", object))
    elseif object_type == "boolean" and disallowed_types["boolean"] ~= true then
        _serialize_insert(buffer, object and "true" or "false")
    elseif object_type == "nil" and disallowed_types["nil"] ~= true then
        _serialize_insert(buffer, "nil")
    elseif object_type == "table" and disallowed_types["table"] ~= true then
        if _seen[object] then
            if comment_out then
                _serialize_insert(buffer, "nil --[[ cyclic table ]]")
            else
                _serialize_insert(buffer, "nil")
            end
            return
        end

        _seen[object] = true

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

                if disallowed_types[k_type] ~= true and disallowed_types[v_type] ~= true then
                    local k_unserializable = not _is_type_serializable(k_type)
                    local v_unserializable = not _is_type_serializable(v_type)

                    -- check for immediate cycles to prevent evaluating keys to nil
                    local k_cyclic = (k_type == "table" and _seen[key])
                    local v_cyclic = (v_type == "table" and _seen[value])

                    if k_unserializable or v_unserializable or k_cyclic or v_cyclic then
                        if comment_out then
                            _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs),
                                "--[[ [\"", _safe_comment_str(key), "\"] = ", _safe_comment_str(value), " ]],\n")
                        end
                    else
                        _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs), "[")
                        _serialize_inner(buffer, key, n_indent_tabs, comment_out, disallowed_types)
                        _serialize_insert(buffer, "] = ")
                        _serialize_inner(buffer, value, n_indent_tabs, comment_out, disallowed_types)
                        _serialize_insert(buffer, ",\n")
                    end
                end
            end
            n_indent_tabs = n_indent_tabs - 1
            _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs), "}")
        end

        _seen[object] = nil
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
local function _serialize(object, comment_out_unserializable, disallowed_types_set)
    if comment_out_unserializable == nil then comment_out_unserializable = true end
    if object == nil then return "nil" end
    if disallowed_types_set == nil then disallowed_types_set = {} end

    local buffer = {}
    _seen = {}
    _serialize_inner(
        buffer,
        object,
        0,
        comment_out_unserializable,
        disallowed_types_set
    )

    return table.concat(buffer, "")
end

--- @brief validates if graph can be fully serialized without errors or cycle omissions
local function _is_serializable(value)
    local value_type = type(value)

    if value_type == "function" or value_type == "userdata" or value_type == "thread" or value_type == "cdata" then
        return false
    end

    if value_type ~= "table" then
        return true
    end

    if _seen[value] then
        return false -- cyclic
    end

    _seen[value] = true

    for key, entry in pairs(value) do
        if not _is_serializable(key, _seen) then
            return false
        end
        if not _is_serializable(entry, _seen) then
            return false
        end
    end

    _seen[value] = nil
    return true
end

--- @brief
function table.is_serializable(t)
    return _is_serializable(t, {})
end

--- @brief
function table.serialize(t, disallowed_types)
    if disallowed_types == nil then disallowed_types = {} end
    assert(type(disallowed_types) == "table", "In table.serialize: for argument #2: expected `table`, got `" .. type(disallowed_types) .. "`")

    local set = {}
    for type in values(disallowed_types) do
        set[type] = true
    end

    return _serialize(t, true, set)
end

--- @brief
function dbg(...)
    for _, x in pairs({...}) do
        if meta.is_table(x) then
            io.write(_tostring(meta.typeof(x)))
            io.write(" ")
        end

        if meta.is_string(x) then
            io.write(x)
        else
            io.write(_serialize(x))
        end
        io.write(" ")
    end

    io.write("\n")
    io.flush()
end