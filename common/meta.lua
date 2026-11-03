require "common.common"

local _noop = function() end
io.stdout:setvbuf("no")

--- @class meta
meta = meta or {}
mt = mt or meta

if _G.type == nil then error("In require(\"common.meta\"): function `type` is not available in the global environment. Was it overwritten or was setfenv called?") end
local _g_type = _G.type

-- reserved typenames
local _type_typename = "Type"
local _union_typename = "Union"
local _enum_typename = "Enum"

-- shared type data
local _type_to_name = {}
local _name_to_type = {}
local _enum_to_value_to_is_present = {}
local _enum_to_instances = {}
local _class_to_instance_metatable = {}

local _current_instance_hash = 0

-- instance properties
local _metatable_index = 1
local _hash_index = 2
local _signals_index = 3

local function _set_metatable(x, mt)
    rawset(x, _metatable_index, mt)
end

local function _get_metatable(x)
    return rawget(x, _metatable_index)
end

local _new_type = function(name, super)
    local metatable = {
        __name = name,
        __super = super,
        __index = super,
        __signals = {},
        __typename = _type_typename,
        __tostring = function(self) return name end,--_type_typename .. "<" .. name .. ">" end,
        __is_native = false,
    }

    local type = setmetatable({}, metatable)

    _type_to_name[type] = name
    _name_to_type[name] = type

    _set_metatable(type, metatable)
    rawset(type, _hash_index, _current_instance_hash)
    _current_instance_hash = _current_instance_hash + 1
    type[_signals_index] = nil

    return type
end

local _new_native_type = function(typename, ...)
    local res = _new_type(typename, ...)
    local to_override = getmetatable(res)
    to_override.__is_native = true
    return res
end

--- @class meta.Number
meta.Number = _new_native_type("Number")

--- @class meta.Boolean
meta.Boolean = _new_native_type("Boolean")

--- @class meta.String
meta.String = _new_native_type("String")

--- @class meta.Table
meta.Table = _new_native_type("Table")

--- @class meta.Function
meta.Function = _new_native_type("Function")

--- @class meta.Coroutine
meta.Coroutine = _new_native_type("Coroutine")

--- @class meta.Nil
meta.Nil = _new_native_type("Nil")

--- @class meta.CData
meta.CData = _new_native_type("CData")

--- @class meta.UserData
meta.UserData = _new_native_type("UserData")

--- @class meta.Any
meta.Any = _new_native_type("Any")

--- @class meta.Type
meta.Type = _new_native_type(_type_typename)

--- @class meta.Enum
meta.Enum = _new_native_type(_enum_typename)

--- @class meta.Union
meta.Union = _new_native_type(_union_typename)

--- @class meta.Optional
meta.Optional = _new_native_type("Optional")

do

    local function _union_tostring(self)
        local names = {}
        for i, t in ipairs(self.types) do
            names[i] = tostring(t)
        end
        return "Union<" .. table.concat(names, ", ") .. ">"
    end

    getmetatable(meta.Union).__call = function(self, ...)
        if select("#", ...) == 0 then rt.error("In meta.Union: number of arguments cannot be 0") end
        local out = _new_native_type("Union")
        local mt = _get_metatable(out)
        mt.__typename = _union_typename
        mt.__tostring = _union_tostring
        out.types = { ... }
        return out
    end

    getmetatable(meta.Optional).__call = function(self, ...)
        if select("#", ...) == 0 then rt.error("In meta.Optional: number of arguments cannot be 0") end
        local out = _new_native_type("Union")
        local mt = _get_metatable(out)
        mt.__typename = _union_typename
        mt.__tostring = _union_tostring
        out.types = { meta.Nil, ... }
        return out
    end
end

-- reserve typenames
for type in range(
    meta.Number,
    meta.Boolean,
    meta.String,
    meta.Function,
    meta.Coroutine,
    meta.Nil,
    meta.Enum,
    meta.CData,
    meta.UserData,
    meta.Any,
    meta.Table,
    meta.Type,
    meta.Enum,
    meta.Union
) do
    local typename = getmetatable(type).__name
    _type_to_name[type] = typename
    _name_to_type[typename] = type
end

-- assertion

function meta.is_number(x)
    return _g_type(x) == "number" and not (x ~= x) -- NaN
end

function meta.is_boolean(x)
    return _g_type(x) == "boolean"
end

function meta.is_string(x)
    return _g_type(x) == "string"
end

function meta.is_function(x)
    return _g_type(x) == "function"
end

function meta.is_coroutine(x)
    return _g_type(x) == "thread"
end

function meta.is_nil(x)
    return x == nil
end

function meta.is_cdata(x)
    return _g_type(x) == "cdata"
end

function meta.is_userdata(x)
    return _g_type(x) == "userdata"
end

function meta.is_any(x)
    return x ~= nil
end

function meta.is_table(x)
    return _g_type(x) == "table"
end

function meta.is_love_type(x, type)
    local valid = _g_type(x) == "userdata" and _g_type(x.typeOf) == "function"
    if type == nil then return valid else return x:typeOf(type) end
end

do
    function meta.is_enum(x)
        if _g_type(x) ~= "table" then return false end
        local mt = _get_metatable(x)
        return meta.is_table(mt) and mt.__typename == _enum_typename
    end

    function meta.is_type(x)
        if _g_type(x) ~= "table" then return false end
        local mt = _get_metatable(x)
        return meta.is_table(mt) and (mt.__typename == _type_typename
            or mt.__typename == _union_typename
            or mt.__typename == _enum_typename
        )
    end

    function meta.is_union(x)
        if _g_type(x) ~= "table" then return false end
        local mt = _get_metatable(x)
        return meta.is_table(mt) and mt.__typename == _union_typename and meta.is_table(x.types)
    end
end

function meta.is_enum_value(x, enum)
    local is_present = _g_type(enum) == "table" and _enum_to_value_to_is_present[enum]
    if is_present == nil then
        rt.error("In meta.is_enum_value: for argument #2: expected `Enum`, got `", meta.typeof(enum), "`")
        return false
    end

    return is_present[x] == true
end

--- @brief
function meta.is_subtype(type, other_type)
    meta.assert(type, meta.Type, other_type, meta.Type)

    local seen = {}
    local current = _get_metatable(type).__super

    while current ~= nil do
        if current == other_type then
            return true
        end

        if seen[current] then
            break
        end

        seen[current] = true
        current = _get_metatable(current).__super
    end

    return type == other_type
end

local _native_to_type = {
    ["nil"] = meta.Nil,
    ["number"] = meta.Number,
    ["string"] = meta.String,
    ["boolean"] = meta.Boolean,
    ["table"] = meta.Table,
    ["function"] = meta.Function,
    ["thread"] = meta.Coroutine,
    ["userdata"] = meta.UserData,
    ["cdata"] = meta.CData,
}

function meta.typeof(x)
    local raw_typename = _g_type(x)
    if raw_typename == "table" then
        local metatable = getmetatable(x)
        if meta.is_table(metatable) and metatable.__typename ~= nil then
            return _name_to_type[metatable.__typename]
        else
            return meta.Table
        end
    else
        return _native_to_type[raw_typename]
    end
end

--- @brief
function meta.get_typename(type)
    meta.assert(type, meta.Type)
    return _get_metatable(type).__name
end

local _type_to_validator = {
    [meta.Number] = meta.is_number,
    [meta.Boolean] = meta.is_boolean,
    [meta.String] = meta.is_string,
    [meta.Table] = meta.is_table,
    [meta.Function] = meta.is_function,
    [meta.Coroutine] = meta.is_coroutine,
    [meta.Nil] = meta.is_nil,
    [meta.CData] = meta.is_cdata,
    [meta.UserData] = meta.is_userdata,
    [meta.Any] = meta.is_any,
    [meta.Type] = meta.is_type,
    [meta.Enum] = meta.is_enum,
    [meta.Union] = meta.is_union,
}

function meta.isa(x, type)
    if type == meta.Any then return true end

    -- union: x must match at least one member
    if meta.is_union(type) then
        for _, other in ipairs(type.types) do
            if meta.isa(x, other) then return true end
        end
        return false
    end

    -- enum: x must be one of the enum's values
    if meta.is_enum(type) then
        return meta.is_enum_value(x, type)
    end

    -- native types: direct validator
    local validator = _type_to_validator[type]
    if validator ~= nil then
        return validator(x)
    end

    if not meta.is_type(type) then
        rt.error("In meta.isa: for argument #2: expected `Type`, got `", meta.typeof(type), "`")
        return false
    end

    -- non-native type: only tables can be instances
    if _g_type(x) ~= "table" then return false end

    local seen = {}
    local current = meta.typeof(x)
    while current ~= nil and not seen[current] do
        if current == type then return true end
        seen[current] = true
        local current_metatable = getmetatable(current)
        if current_metatable == nil then break end
        current = rawget(current_metatable, "__super")
    end

    return false
end

function meta.assert_argument_type(x, type, index)
    if not meta.isa(x, type) then
        rt.error("In meta.assert_argument_type: wrong type for argument #", index, ": expected `", _type_to_name[type], "`, got `", meta.typeof(x), "`")
    end
end

function meta.assert(...)
    local argument_i = 1
    for i = 1, select("#", ...), 2 do
        local x = select(i + 0, ...)
        local type = select(i + 1, ...)
        if not meta.isa(x, type) then
            rt.error("In meta.assert: wrong type for argument #", argument_i, ": expected `", _type_to_name[type], "`, got `", meta.typeof(x), "`")
        end
        argument_i = argument_i + 1
    end
end

meta.DISCONNECT_SIGNAL = true
local _install_signals
do
    local _signal_callback_id = 0
    local _throw_no_signal = function(scope, instance, signal)
        rt.error("In ", meta.typeof(instance), ".", scope, ": no signal with id `", signal, "`")
    end

    local _disconnect_callback = function(entry, callback_id)
        local callback = entry.callback_id_to_callback[callback_id]
        entry.callback_id_to_callback[callback_id] = nil

        local to_remove = nil
        for i, other in ipairs(entry.callback_ids_in_order) do
            if other == callback_id then
                to_remove = i
                break
            end
        end

        if to_remove ~= nil then
            table.remove(entry.callback_ids_in_order, to_remove)
        end

    end

    -- signals
    local _signal_list_handler_ids = function(instance, id)
        meta.assert(instance, meta.Any, id, meta.String)

        local component, entry
        component = rawget(instance, _signals_index)
        if component ~= nil then entry = component[id] end

        if component == nil or entry == nil then
            _throw_no_signal("signal_list_handler_ids", instance, id)
        end

        local out = {}
        for callback_id in keys(entry.callback_id_to_callback) do
            table.insert(out, callback_id)
        end
        return out
    end

    local _signal_list_signals = function(instance)
        meta.assert(instance, meta.Any)

        local component = rawget(instance, _signals_index)
        if component == nil then return {} end

        local out = {}
        for id in keys(component) do
            table.insert(out, id)
        end
        return out
    end

    local _signal_connect = function(instance, id, ...)
        local callback = select(1, ...)
        meta.assert(instance, meta.Any, id, meta.String, callback, meta.Function)

        local component = rawget(instance, _signals_index)
        local entry = component[id]
        if entry == nil then
            _throw_no_signal("signal_connect", instance, id)
            return
        end

        local callback_id = _signal_callback_id
        _signal_callback_id = _signal_callback_id + 1

        entry.callback_id_to_callback[callback_id] = callback
        table.insert(entry.callback_ids_in_order, callback_id)
        return callback_id
    end

    local _signal_disconnect = function(instance, id, callback_id)
        meta.assert(
            instance, meta.Any,
            id, meta.String,
            callback_id, meta.Optional(meta.Number)
        )

        local component, entry
        component = rawget(instance, _signals_index)

        if component ~= nil then
            entry = component[id]
        end

        if component == nil or entry == nil then
            _throw_no_signal("signal_disconnect", instance, id)
            return
        end

        if callback_id == nil then
            instance:signal_disconnect_all(id)
        else
            local callback = entry.callback_id_to_callback[callback_id]
            if callback == nil then
                rt.error("In ", meta.typeof(instance), ".signal_disconnect: no callback with id `", tostring(callback_id), "` connected to signal `", id, "`")
                return
            end

            _disconnect_callback(entry, callback_id)
        end
    end

    local _signal_try_disconnect = function(instance, id, callback_id)
        meta.assert(
            instance, meta.Any,
            id, meta.String,
            callback_id, meta.Optional(meta.Number)
        )

        local component = rawget(instance, _signals_index)
        if component == nil then
            return false
        end

        local entry = component[id]
        if entry == nil then
            return false
        end

        if callback_id == nil then
            instance:signal_disconnect_all(id)
            return true
        else
            local callback = entry.callback_id_to_callback[callback_id]
            if callback == nil then
                return false
            end

            _disconnect_callback(entry, callback_id)
            return true
        end
    end

    local _signal_disconnect_all = function(instance, id)
        meta.assert(instance, meta.Any, id, meta.Optional(meta.String))

        local component = rawget(instance, _signals_index)
        if component == nil then
            rt.error("In ", meta.typeof(instance), ".signal_disconnect_all: object `", meta.typeof(instance), "` does not have any signals")
            return
        end

        if id == nil then
            for signal in values(_signal_list_signals(instance)) do
                _signal_disconnect(instance, signal, nil) -- all callbacks
            end
        else
            local entry = component[id]
            if entry == nil then
                _throw_no_signal("signal_disconnect_all", instance, id)
                return
            end

            for callback_id in keys(entry.callback_id_to_callback) do
                _disconnect_callback(entry, callback_id)
            end
        end
    end

    local _signal_set_is_blocked = function(instance, id, b)
        meta.assert(instance, meta.Any, id, meta.String, b, meta.Boolean)

        local component, entry
        component = rawget(instance, _signals_index)
        if component ~= nil then
            entry = component[id]
        end

        if component == nil or entry == nil then
            _throw_no_signal("signal_set_is_blocked", instance, id)
            return
        end

        entry.is_blocked = b
    end

    local _signal_get_is_blocked = function(instance, id)
        meta.assert(instance, meta.Any, id, meta.String)

        local component, entry
        component = rawget(instance, _signals_index)
        if component ~= nil then entry = component[id] end

        if component == nil or entry == nil then
            _throw_no_signal("signal_set_is_blocked", instance, id)
            return false
        end

        return entry.is_blocked
    end

    local _signal_has_signal = function(instance, id)
        meta.assert(instance, meta.Any, id, meta.String)

        local component = rawget(instance, _signals_index)
        if component == nil then
            return false
        end
        return component[id] ~= nil
    end

    local _signal_emit = function(instance, id, ...)
        meta.assert(instance, meta.Any, id, meta.String)

        local component, entry
        component = rawget(instance, _signals_index)
        if component ~= nil then entry = component[id] end

        if component == nil or entry == nil then
            _throw_no_signal("signal_emit", instance, id)
            return
        end

        if entry.is_blocked then return end

        local callback_ids = {} -- deep copy since signals could be disconnect during emission
        for _, callback_id in ipairs(entry.callback_ids_in_order) do
            table.insert(callback_ids, callback_id)
        end

        local to_remove_callback_ids = {}
        for _, callback_id in ipairs(callback_ids) do
            local callback = entry.callback_id_to_callback[callback_id]
            if callback ~= nil then
                if callback(instance, ...) == meta.DISCONNECT_SIGNAL then
                    instance:signal_try_disconnect(id, callback_id)
                end
            else
                -- disconnected during emission
                _disconnect_callback(entry, callback_id)
            end
        end
    end

    local _signal_try_emit = function(instance, id, ...)
        meta.assert(instance, meta.Any, id, meta.String)

        local component, entry
        component = rawget(instance, _signals_index)
        if component ~= nil then entry = component[id] end

        if component == nil or entry == nil or entry.is_blocked then
            return false
        end

        local callback_ids = {}
        for _, callback_id in ipairs(entry.callback_ids_in_order) do
            table.insert(callback_ids, callback_id)
        end

        local invoked = false
        for _, callback_id in ipairs(callback_ids) do
            local callback = entry.callback_id_to_callback[callback_id]
            if callback ~= nil then
                invoked = true
                if callback(instance, ...) == meta.DISCONNECT_SIGNAL then
                    instance:signal_try_disconnect(id, callback_id)
                end
            else
                _disconnect_callback(entry, callback_id)
            end
        end

        return invoked
    end

    function _install_signals(instance, type)
        local signals = _get_metatable(type).__signals
        if #signals == 0 then return end

        type.signal_emit = _signal_emit
        type.signal_try_emit = _signal_try_emit
        type.signal_connect = _signal_connect
        type.signal_disconnect = _signal_disconnect
        type.signal_try_disconnect = _signal_try_disconnect
        type.signal_disconnect_all = _signal_disconnect_all
        type.signal_set_is_blocked = _signal_set_is_blocked
        type.signal_get_is_blocked = _signal_get_is_blocked
        type.signal_has_signal = _signal_has_signal
        type.signal_list_handler_ids = _signal_list_handler_ids
        type.signal_list_signals = _signal_list_signals

        for signal_id in values(signals) do
            local component = rawget(instance, _signals_index)
            if component == nil then
                component = {}
                rawset(instance, _signals_index, component)
            end

            component[signal_id] = {
                is_blocked = false,
                callback_id_to_callback = {}, -- Table<Function>
                callback_ids_in_order = {} -- Table<Integer>
            }
        end
    end
end -- _install_signals

local _default_instantiate = function(self, ...)
    if meta.is_table(select(1, ...)) then
        meta.install(self, select(1, ...))
    end
end

function meta.class(typename, super)
    meta.assert(typename, meta.String, super, meta.Optional(meta.Type))

    local type = _new_type(typename, super)
    local type_metatable = getmetatable(type)

    local has_signals = false
    local supers = {}
    local reverse_supers = {}

    do
        local seen = {}
        local current = type
        repeat
            local current_metatable = getmetatable(current)
            if #current_metatable.__signals > 0 then
                has_signals = true
            end

            if seen[current] then
                -- check for cyclic inheritance
                rt.fatal("In meta.class: cyclic inheritance detected for type: `", typename, "`, multiple super types inherit from `", _type_to_name[current], "`")
            end
            seen[current] = true

            local current_super = current_metatable.__super
            if current_super ~= nil then
                table.insert(supers, current_super)
                table.insert(reverse_supers, 1, current_super)
            end

            current = current_super
        until current == nil
    end

    local instance_metatable = {}
    instance_metatable.__index = type
    instance_metatable.__typename = typename

    _class_to_instance_metatable[type] = instance_metatable

    type_metatable.__call = function(self, ...)
        local instance = {}
        instance[_metatable_index] = instance_metatable
        instance[_hash_index] = _current_instance_hash
        _current_instance_hash = _current_instance_hash + 1
        instance[_signals_index] = nil

        -- inject signals in reverse order
        for current_super in values(reverse_supers) do
            _install_signals(instance, current_super)
        end
        _install_signals(instance, self)

        setmetatable(instance, instance_metatable)

        -- instantiate in order
        for current_super in values(supers) do
            current_super.instantiate(instance)
        end

        self.instantiate(instance, ...)
        return instance
    end

    type.instantiate = _default_instantiate
    return type
end

--- @brief
function meta.abstract_class(typename, super)
    local type = meta.class(typename, super)
    local type_metatable = getmetatable(type)
    type_metatable.__call = function()
        rt.error("In ", typename, "(): trying to instantiated object of type `", typename, "`, but it was declared abstract")
    end
    return type
end

--- @brief
function meta.add_signals(type, ...)
    meta.assert(type, meta.Type)
    local metatable = _get_metatable(type)
    for i = 1, select("#", ...) do
        local id = select(i, ...)
        meta.assert_argument_type(id, meta.String, 1 + i)
        table.insert(metatable.__signals, id)
    end
end
meta.add_signal = meta.add_signals

--- @brief
function meta.enum(typename, fields)
    meta.assert(typename, meta.String, fields, meta.Table)

    local type = _new_type(typename)

    local type_metatable = getmetatable(type)
    type_metatable.__index = function(self, key)
        local result = rawget(fields, key)
        if result == nil then
            rt.error("In meta.enum: trying to access field `", key, "` of enum `", typename, "`, but enum has no such field")
            return nil
        end
        return result
    end

    type_metatable.__newindex = function(_)
        rt.error("In meta.enum: trying to modify enum `", typename, "`, but it is immutable")
        return nil
    end

    type_metatable.__call = function(_)
        rt.error("In meta.enum: trying to call enum type `", typename, "`, but it is not callable")
    end

    type_metatable.__typename = _enum_typename

    local is_present = {}
    for key, value in pairs(fields) do
        is_present[value] = true
    end

    _enum_to_value_to_is_present[type] = is_present
    _enum_to_instances[type] = table.deepcopy(fields)
    return type
end

--- @return Table
function meta.instances(enum)
    local out = _enum_to_instances[enum]
    if out == nil then
        rt.error("In meta.instances: object of type `", meta.typeof(enum), "` is not an enum")
        return {}
    else
        return out
    end
end

--- @brief
function meta.get_instance_metatable(type)
    meta.assert(type, meta.Type)
    return _class_to_instance_metatable[type]
end

--- @return Number
function meta.hash(instance)
    if instance == nil then return -1 end
    return rawget(instance, _hash_index) or -1
end

--- @brief
function meta.make_weak(t, weak_keys, weak_values)
    meta.assert(t, meta.Table, weak_keys, meta.Optional(meta.Boolean), weak_values, meta.Optional(meta.Boolean))

    local metatable = getmetatable(t)
    if metatable == nil then
        metatable = {}
        setmetatable(t, metatable)
    end

    if weak_keys == nil then weak_keys = true end
    if weak_values == nil then weak_values = true end

    if weak_keys == true and weak_values == true then
        metatable.__mode = "kv"
    elseif weak_keys == true and weak_values == false then
        metatable.__mode = "k"
    elseif weak_keys == false and weak_values == true then
        metatable.__mode = "v"
    else
        metatable.__mode = nil
    end
    return t, metatable
end

--- @brief
function meta.make_immutable(t, recursive, _visited)
    meta.assert(t, meta.Table, recursive, meta.Optional(meta.Boolean))
    if recursive == nil then recursive = false end

    -- guard against cycles and shared subtables
    _visited = _visited or {}
    if _visited[t] then
        return t, getmetatable(t)
    end
    _visited[t] = true

    if recursive then
        for _, value in pairs(t) do
            if type(value) == "table" then
                meta.make_immutable(value, recursive, _visited)
            end
        end
    end

    local metatable = getmetatable(t)
    if metatable == nil then
        metatable = {}
        setmetatable(t, metatable)
    end

    metatable.__index = function(_, key)
        local out = rawget(t, key)
        if out == nil then
            rt.error("In meta.make_immutable: trying to access `", key, "` of `", tostring(t), "`, but this value does not exist")
            return nil
        end
        return out
    end

    metatable.__newindex = function(_, key, value)
        rt.error("trying to modify table `", tostring(t), "`, but it is immutable")
    end

    return t, metatable
end

--- @brief
function meta.make_auto_extend(t, recursive)
    meta.assert(t, meta.Table, recursive, meta.Optional(meta.Boolean))

    if recursive == nil then recursive = false end
    local metatable = getmetatable(t)
    if metatable == nil then
        metatable = {}
        setmetatable(t, metatable)
    end

    metatable.__index = function(self, key)
        local out = {}
        self[key] = out

        if recursive then
            return meta.make_auto_extend(out, recursive)
        else
            return out
        end
    end

    return t, metatable
end

--- @brief
function meta.install(instance, values)
    meta.assert(instance, meta.Any, values, meta.Table)
    for key, value in pairs(values) do
        if instance[key] == nil then
            instance[key] = value
        end
    end
    return instance
end

--- @brief
function meta.as_singleton(type, ...)
    meta.assert(type, meta.Type)
    local instance = type(...)
    _get_metatable(instance).__call = function()
        rt.error("In ", meta.get_typename(type), "(): trying to instantiate type, but is a singleton that cannot be instatiated")
    end

    return instance
end

do
    local function _to_key(prefix, key)
        local parts = {}

        for i = 1, #prefix + 1 do
            local p = (i <= #prefix) and prefix[i] or key

            if meta.is_number(p) then
                parts[#parts + 1] = "[" .. tostring(p) .. "]"
            else
                if #parts > 0 then
                    parts[#parts + 1] = "."
                end
                parts[#parts + 1] = tostring(p)
            end
        end

        return table.concat(parts)
    end

    local function _validate_input(input, schema_node, prefix, is_valid_ref, is_active)
        if is_active[input] == true then return end
        is_active[input] = true

        for key, value in pairs(input) do
            if schema_node[key] == nil then
                rt.error("In meta.validate_schema: key `", _to_key(prefix, key), "`, expected `nil`, got `", meta.typeof(value), "`")
                is_valid_ref[1] = false
                return
            end
        end

        for key, schema_t in pairs(schema_node) do
            local value = input[key]
            if meta.is_type(schema_t) then
                if not meta.isa(value, schema_t) then
                    rt.error("In meta.validate_schema: key `", _to_key(prefix, key), "`: expected `", schema_t, "`, got `", meta.typeof(value), "`")
                    is_valid_ref[1] = false
                    return
                end
            else -- schema_t confirmed nested table in check_schema_correctness
                if not meta.is_table(value) then
                    rt.error("In meta.validate_schema: key `", _to_key(prefix, key), "`: expected nested `Table`, got `", meta.typeof(value), "`")
                    is_valid_ref[1] = false
                    return
                end

                local child_prefix = table.deepcopy(prefix)
                table.insert(child_prefix, key)
                _validate_input(value, schema_t, child_prefix, is_valid_ref, is_active)
            end
        end

        is_active[input] = nil
        return is_valid_ref[1]
    end

    local function _validate_schema(node, prefix, seen)
        if seen[node] then
            rt.fatal("In meta.validate_schema: malformed schema at key `", _to_key(prefix), "`: duplicate or circular table detected")
        end
        seen[node] = true

        for key, value in pairs(node) do
            if meta.is_type(value) then
                -- valid, continue
            elseif _g_type(value) == "table" then
                local child_prefix = table.deepcopy(prefix)
                table.insert(child_prefix, key)
                _validate_schema(value, child_prefix, seen)
            else
                rt.fatal("In meta.validate_schema: malformed schema at key `", _to_key(prefix, key), "`: expected `Type` or a nested table, got `", meta.typeof(value), "`")
            end
        end
    end

    --- @class meta.Schema
    meta.Schema = meta.class("Schema")

    --- @brief
    function meta.Schema:instantiate(layout)
        _validate_schema(layout,
            {}, -- prefix
            {} -- seen
        )

        self.layout = meta.make_immutable(layout)
    end

    --- @brief
    function meta.Schema:validate(x)
        meta.assert(x, meta.Table)
        return _validate_input(x, self.layout,
            {}, -- prefix
            { true }, -- return ref
            {} -- currently active
        )
    end
end

return meta
