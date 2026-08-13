require "common.common"

local _noop = function() end

if meta == nil then meta = {} end
if mt == nil then mt = meta end

--- @class meta.Number
meta.Number = "Number"

--- @class meta.Boolean
meta.Boolean = "Boolean"

--- @class meta.String
meta.String = "String"

--- @class meta.Table
meta.Table = "Table"

--- @class meta.Function
meta.Function = "Function"

--- @class meta.Coroutine
meta.Coroutine = "Coroutine"

--- @class meta.Nil
meta.Nil = "Nil"

--- @class meta.Type
meta.Type = "Type"

--- @class meta.Enum
meta.Enum = "Enum"

--- @class meta.CData
meta.CData = "CData"

--- @class meta.UserData
meta.UserData = "UserData"

--- @class meta.Object
meta.Object = "Object"

--- @class meta.Union
meta.Union = function(...)
    if select("#", ...) == 0 then
        rt.error("In meta.Union: called with 0 arguments, but a type cannot be the empty Union")
    end

    for i = 1, select("#", ...) do
        if select(i, ...) == nil then
            rt.error("In meta.Union: argument #", i, " is `nil`")
        end
    end

    return { ... }
end

--- @class meta.Optional
meta.Optional = function(...)
    if select("#", ...) == 0 then
        rt.error("In meta.Optional: called with 0 arguments, but a type cannot be an empty Optional")
    end

    for i = 1, select("#", ...) do
        if select(i, ...) == nil then
            rt.error("In meta.Optional: argument #", i, " is `nil`")
        end
    end

    return meta.Union(mt.Nil, ...)
end

--- @class meta.Any
meta.Any = "*"

if _G.type == nil then error("In require(\"common.meta\"): function `type` is not available in the global environment. Was it overwritten or was setfenv called?") end
local _get_native_type = _G.type

local _current_hash = 0

local _object_metatable_index = 1
local _object_hash_index = _object_metatable_index + 1
local _object_signal_component_index = _object_hash_index + 1

local _instantiate_name = "instantiate"
meta._typenames = {}
for type in range(
    meta.Number,
    meta.Boolean,
    meta.String,
    meta.Table,
    meta.Function,
    meta.Coroutine,
    meta.Nil,
    meta.Type,
    meta.Enum,
    meta.Object,
    meta.CData,
    meta.UserData,
    meta.Any,
    "Union",
    "Optional"
) do
    meta._typenames[type] = true
end

local _type_to_super = {}
local _type_to_instance_metatable = {}
local _typename_to_type = {}
local _type_to_typename = {}

--- @brief
function meta.get_typename(type)
    meta.assert(type, meta.Type)
    return _type_to_typename[type]
end

--- @brief
function meta.get_union_typename(union)
    if not meta.is_union(union) then
        rt.error("In meta.get_union_typename: expected `Union`, got `", meta.typeof(union), "`")
    end

    local result = { }
    for x in values(union) do
        local to_insert
        if meta.is_type(x) then
            to_insert = meta.get_typename(x)
        elseif meta.is_enum(x) then
            to_insert = meta.get_enum_name(x)
        elseif meta.is_union(x) then
            to_insert = meta.get_union_typename(x)
        else
            to_insert = x
        end

        table.insert(result, to_insert)
    end

    return "Union<" .. table.concat(result, ", ") .. ">"
end

--- @brief
function meta.get_super(type)
    meta.assert(type, meta.Type)
    return _type_to_super[type]
end

--- @brief
function meta.is_type(x)
    if _get_native_type(x) ~= "table" then return false end
    local mt = getmetatable(x)
    return mt ~= nil and mt.__typename == meta.Type
end

--- @brief check if `type` inherits from `other_type`, directly or transitively
--- @param type meta.Type
--- @param other_type meta.Type
--- @return meta.Boolean
function meta.is_subtype(type, other_type)
    meta.assert(type, meta.Type, other_type, meta.Type)
    if type == other_type then return true end

    local seen = {}
    local current = meta.get_super(type)
    repeat
        if current == other_type then
            return true
        end
        if seen[current] then
            break -- inheritance cycle
        end
        seen[current] = true
        current = meta.get_super(current)
    until current == nil

    return false
end

--- @brief
function meta.is_object(x)
    if _get_native_type(x) ~= "table" then return end
    local metatable = getmetatable(x)
    if metatable == nil then return false end
    return metatable == rawget(x, _object_metatable_index) and meta.is_string(metatable.__typename)
end

--- @brief
function meta.is_enum(x)
    if _get_native_type(x) ~= "table" then return false end
    local mt = getmetatable(x)
    return mt ~= nil and mt.__typename == meta.Enum
end

do
    local _native_type_to_type = {
        ["nil"] = meta.Nil,
        ["number"] = meta.Number,
        ["string"] = meta.String,
        ["boolean"] = meta.Boolean,
        ["table"] = meta.Table,
        ["function"] = meta.Function,
        ["thread"] = meta.Coroutine,
        ["userdata"] = meta.UserData,
        ["cdata"] = meta.CData
    }

    --- @brief
    function meta.typeof(instance)
        if _get_native_type(instance) ~= "table" then
            local mapped = _native_type_to_type[_get_native_type(instance)]
            if mapped == nil then return "Unknown" else return mapped end
        end

        local metatable = getmetatable(instance)
        if _get_native_type(metatable) ~= "table" then
            local mapped = _native_type_to_type[_get_native_type(instance)]
            if mapped == nil then return "Unknown" else return mapped end
        else
            local typename = metatable.__typename
            if typename == nil then
                return meta.Table
            else
                return typename
            end
        end
    end

    --- @brief
    function meta.is_nil(x)
        return x == nil
    end

    --- @brief
    function meta.is_number(x)
        return _get_native_type(x) == "number" and not math.is_nan(x)
    end

    --- @brief
    function meta.is_integer(x)
        return meta.is_number(x) and x % 1 == 0
    end

    --- @brief
    function meta.is_string(x)
        return _get_native_type(x) == "string"
    end

    --- @brief
    function meta.is_boolean(x)
        return _get_native_type(x) == "boolean"
    end

    --- @brief
    function meta.is_table(x)
        return _get_native_type(x) == "table"
    end

    --- @brief
    function meta.is_function(x)
        return _get_native_type(x) == "function"
    end

    --- @brief
    function meta.is_coroutine(x)
        return _get_native_type(x) == "thread"
    end

    --- @brief
    function meta.is_cdata(x)
        return _get_native_type(x) == "cdata"
    end

    --- @brief
    function meta.is_userdata(x)
        return _get_native_type(x) == "userdata"
    end

    --- @brief
    function meta.is_union(x)
        if _get_native_type(x) ~= "table" then return false end
        for type in values(x) do
            if not (meta.is_string(type)
                or meta.is_type(type)
                or meta.is_enum(type)
                or meta.is_union(type)
            ) then
                return false
            end
        end

        return true
    end

    --- @brief
    function meta.is_type_instance(x, type)
        local super
        do
            local metatable = getmetatable(x)
            if metatable == nil then return false end
            super = metatable.__index
        end

        while super ~= nil do
            if super == type then return true end
            local metatable = getmetatable(super)
            if metatable == nil then return false end
            super = metatable.__index
        end

        return false
    end

    --- @brief
    function meta.is_union_instance(x, type)
        for option in values(type) do
            if meta.isa(x, option) then return true end
        end

        return false
    end

    --- @brief
    function meta.isa(x, type)
        if x == nil and type == mt.Nil then
            return true
        elseif meta.is_string(type) then
            local is = meta.typeof(x) == type
            if is == false then
                -- check love objects
                if meta.is_userdata(x) and meta.is_function(x.typeOf) then
                    is = x:typeOf(type)
                end
            end
            return is
        elseif meta.is_type(type) then
            return meta.is_type_instance(x, type)
        elseif meta.is_enum(type) then
            return meta.is_enum_value(x, type)
        elseif meta.is_union(type) then
            return meta.is_union_instance(x, type)
        else
            rt.error("In meta.isa: for argument #2: expected `String`, `Type`, `Enum`, or `Union`, got `", meta.typeof(type), "`")
            return false
        end
    end

    --- @brief
    function meta.is_love_type(x, type)
        require "love.love"
        meta.assert_argument_type(type, meta.String, 2)
        return meta.is_table(x) and meta.is_function(x.typeOf) and x:typeOf(type) == true
    end

    local _type_to_validator = {
        [meta.Number] = function(x) return meta.is_number, meta.Number end,
        [meta.Boolean] = function(x) return meta.is_boolean, meta.Boolean end,
        [meta.String] = function(x) return meta.is_string, meta.String end,
        [meta.Table] =  function(x) return meta.is_table, meta.Table end,
        [meta.Function] = function(x) return meta.is_function, meta.Function end,
        [meta.Coroutine] = function(x) return meta.is_coroutine, meta.Coroutine end,
        [meta.Nil] = function(x) return meta.is_nil, meta.Nil end,
        [meta.Object] = function(x) return meta.is_object, meta.Object end,
        [meta.CData] = function(x) return meta.is_cdata, meta.CData end,
        [meta.UserData] = function(x) return meta.is_userdata, meta.UserData end,
        [meta.Type] = function(x) return meta.is_type, meta.Type end,
        [meta.Enum] = function(x) return meta.is_enum, meta.Enum end,
        [meta.Union] = function(x) return meta.is_union, meta.get_union_typename(x) end,
        [meta.Optional] = function(x) return meta.is_union, meta.get_union_typename(x) end
    }

    local function _assert_typeof(scope, instance, type, i)
        local is_valid, typename, error = true, nil, nil
        if type == meta.Any and instance ~= nil then return true, "" end

        if _type_to_validator[type] ~= nil then
            local validator
            validator, typename = _type_to_validator[type](instance)
            is_valid = validator(instance) == true
        elseif meta.is_type(type) then
            is_valid = meta.is_type_instance(instance, type)
            if is_valid == false then
                typename = meta.get_typename(type)
            end
        elseif meta.is_enum(type) then
            is_valid = meta.is_enum_value(instance, type)
            if is_valid == false then
                typename = meta.get_enum_name(type)
            end
        elseif meta.is_union(type) then
            is_valid = meta.is_union_instance(instance, type)
            if is_valid == false then
                typename = meta.get_union_typename(type)
            end
        elseif meta.is_string(type) then
            is_valid = meta.typeof(instance) == type
            typename = type

            if is_valid == false then -- try love typeOf
                is_valid = meta.is_love_type(instance, type)
                typename = type
            end
        else
            return false, string.paste("In ", scope, ": wrong arguments for `", scope, "`: argument #", i + 1, ", expected `", meta.Type, "`, `", meta.Enum, "` or `", meta.String, "` got `", meta.typeof(type), "`")
        end

        if not is_valid then
            error = string.paste("In meta.assert: for argument #", i, ", expected value of type `", typename, "`, got `", meta.typeof(instance), "`")
        end

        if error == nil then error = "" end

        assert(meta.is_boolean(is_valid))
        return is_valid, error
    end

    if DEBUG then
        --- @brief
        function meta.assert(...)
            local argument_i = 1
            for i = 1, select("#", ...), 2 do
                local instance, type =
                    select(i+0, ...),
                    select(i+1, ...)

                local is_valid, error = _assert_typeof(
                    "meta.assert",
                    instance, type,
                    argument_i
                )

                if not is_valid then
                    rt.error(error)
                end

                argument_i = argument_i + 1
            end
        end

        --- @brief
        function meta.assert_argument_type(x, type, argument_i)
            local is_valid, error = _assert_typeof("meta.assert_argument_type", x, type, argument_i)
            if is_valid ~= true then rt.error(error) end
        end
    else
        -- optimize to noop in release mode
        meta.assert = _noop
        meta.assert_argument_type = _noop
    end
end

-- global signal to disconnect signal after emission
meta.DISCONNECT_SIGNAL = "DISCONNECT"

do
    -- signal aux
    local _signal_callback_id = 0
    local _throw_no_signal = function(scope, instance, signal)
        rt.error("In ", meta.typeof(instance), ".", scope, ": no signal with id `", signal, "`")
    end

    local _disconnect_callback = function(entry, callback_id)
        local callback = entry.callback_id_to_callback[callback_id]
        entry.callback_id_to_callback[callback_id] = nil

        for i, other in ipairs(entry.callback_ids_in_order) do
            if other == callback_id then
                table.remove(entry.callback_ids_in_order, i)
                break
            end
        end
    end

    -- signals
    local _signal_list_handler_ids = function(instance, id)
        meta.assert(instance, mt.Object, id, mt.String)

        local component, entry
        component = instance[_object_signal_component_index]
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
        meta.assert(instance, mt.Object)

        local component = instance[_object_signal_component_index]
        if component == nil then return {} end

        local out = {}
        for id in keys(component) do
            table.insert(out, id)
        end
        return out
    end

    local _signal_connect = function(instance, id, ...)
        local callback = select(1, ...)
        meta.assert(instance, mt.Object, id, mt.String, callback, mt.Function)

        local component = instance[_object_signal_component_index]
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
            instance, mt.Object,
            id, mt.String,
            callback_id, mt.Optional(mt.Number)
        )

        local component, entry
        component = instance[_object_signal_component_index]

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
            instance, mt.Object,
            id, mt.String,
            callback_id, mt.Number
        )

        local component = instance[_object_signal_component_index]
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
        meta.assert(instance, mt.Object, id, mt.Optional(mt.String))

        local component = instance[_object_signal_component_index]
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
        meta.assert(instance, mt.Object, id, mt.String, b, mt.Boolean)

        local component, entry
        component = instance[_object_signal_component_index]
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
        meta.assert(instance, mt.Object, id, mt.String)

        local component, entry
        component = instance[_object_signal_component_index]
        if component ~= nil then entry = component[id] end

        if component == nil or entry == nil then
            _throw_no_signal("signal_set_is_blocked", instance, id)
            return false
        end

        return entry.is_blocked
    end

    local _signal_has_signal = function(instance, id)
        meta.assert(instance, mt.Object, id, mt.String)

        local component = instance[_object_signal_component_index]
        if component == nil then
            return false
        end
        return component[id] ~= nil
    end

    local _signal_emit = function(instance, id, ...)
        meta.assert(instance, mt.Object, id, mt.String)

        local component, entry
        component = instance[_object_signal_component_index]
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
        meta.assert(instance, mt.Object, id, mt.String)

        local component, entry
        component = instance[_object_signal_component_index]
        if component ~= nil then entry = component[id] end

        if component == nil or entry == nil then
            return false
        end

        if entry.is_blocked then return false end

        local callback_ids = {}
        for _, callback_id in ipairs(entry.callback_ids_in_order) do
            table.insert(callback_ids, callback_id)
        end

        local to_remove_callback_ids = {}
        for _, callback_id in ipairs(callback_ids) do
            local callback = entry.callback_id_to_callback[callback_id]
            if callback ~= nil then
                local success, result_maybe = pcall(callback, instance, ...)
                if success then
                    if result_maybe == meta.DISCONNECT_SIGNAL then
                        instance:signal_disconnect(id, callback_id)
                    end
                else
                    return false
                end
            else
                -- disconnected during emission
                _disconnect_callback(entry, callback_id)
            end
        end
    end

    local function _install_signals(instance, type)
        local signals = type[_object_metatable_index].__signals
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
            local component = instance[_object_signal_component_index]
            if component == nil then
                component = {}
                instance[_object_signal_component_index] = component
            end

            component[signal_id] = {
                is_blocked = false,
                callback_id_to_callback = {}, -- Table<Function>
                callback_ids_in_order = {} -- Table<Integer>
            }
        end
    end

    local _default_instantiate = function(self, ...)
        if meta.is_table(select(1, ...)) then
            meta.install(self, select(1, ...))
        end
    end

    --- @generic T
    --- @param typename `T`
    --- @param super Any
    --- @param _ Nil
    --- @return T
    function meta.class(typename, super, _)
        meta.assert(typename, mt.String, super, mt.Optional(mt.Type), _, mt.Nil)

        if meta._typenames[typename] ~= nil then
            rt.fatal("In meta.class: a type with typename `", typename, "` already exists")
        end
        meta._typenames[typename] = true

        if super ~= nil then
            -- check for cyclic inheritance
            local seen = {}
            local current = super
            repeat
                if seen[current] then
                    rt.fatal("In meta.class: cyclic inheritance detected for type: `", typename, "`, multiple super types inherit from `", meta.get_typename(current), "`")
                end
                seen[current] = true
                current = _type_to_super[current]
            until current == nil
        end

        -- instance metatable
        local type = {}

        local instance_metatable = {
            __index = type,
            __typename = typename,
            __default_index = type
        }

        local supers = {}
        local reverse_supers = {}
        do
            local current = super
            while current ~= nil do
                table.insert(supers, current)
                table.insert(reverse_supers, 1, current)

                current = _type_to_super[current]
            end
        end

        -- create instance
        local type_metatable = {}
        type_metatable.__call = function(self, ...)
            local instance = setmetatable({}, instance_metatable)
            rawset(instance, _object_hash_index, _current_hash)
            _current_hash = _current_hash + 1
            rawset(instance, _object_metatable_index, instance_metatable)

            -- inject signals in reverse order
            for current_super in values(reverse_supers) do
                _install_signals(instance, current_super)
            end

            _install_signals(instance, type)

            -- instantiate in order
            for current_super in values(supers) do
                if current_super.instantiate ~= nil then
                    current_super.instantiate(instance) -- no varargs
                end
            end

            if type.instantiate ~= nil then
                type.instantiate(instance, ...)
            end

            return instance
        end

        type_metatable.__tostring = function() return typename end
        type_metatable.__index = super
        type_metatable.__typename = meta.Type
        type_metatable.__signals = {}

        -- wrap all function calls in manual timing
        type_metatable.__newindex = function(self, key, value)
            if false then --PROFILE and meta.is_function(value) then
                local id = typename .. "." .. key
                rawset(self, key, function(...)
                    profiler.push(id)
                    local before = love.timer.getTime()
                    local capture = { value(...) }
                    profiler.notify(love.timer.getTime() - before)
                    profiler.pop(id)
                    return table.unpack(capture)
                end)
            else
                rawset(self, key, value)
            end
        end

        setmetatable(type, type_metatable)
        rawset(type, _object_hash_index, _current_hash)
        _current_hash = _current_hash + 1
        rawset(type, _object_metatable_index, type_metatable)

        _type_to_super[type] = super
        _type_to_instance_metatable[type] = instance_metatable
        _typename_to_type[typename] = type
        _type_to_typename[type] = typename

        -- default instantiate
        type.instantiate = _default_instantiate

        return type
    end
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
function meta.as_singleton(type, ...)
    local instance = type(...)
    getmetatable(instance).__call = function()
        rt.error("In ", meta.get_typename(type), "(): trying to instantiate type, but is a singleton that cannot be instatiated")
    end

    return instance
end

--- @brief
function meta.add_signals(type, ...)
    meta.assert(type, meta.Type)
    local metatable = type[_object_metatable_index]
    for i = 1, select("#", ...) do
        local id = select(i, ...)
        rt.assert(meta.typeof(id) == meta.String, "In meta.add_signals: expected `", meta.String, "`, got `", meta.typeof(id), "`")
        table.insert(metatable.__signals, id)
    end
end
meta.add_signal = meta.add_signals

--- @brief
function meta.list_signals(type)
    meta.assert(type, mt.Type)

    local seen = {} -- possible duplicated in super chain
    local out = {}

    local current = type
    while current ~= nil do
        local signals = current[_object_metatable_index].__signals
        for _, signal_id in ipairs(signals) do
            if not seen[signal_id] then
                seen[signal_id] = true
                table.insert(out, signal_id)
            end
        end
        current = _type_to_super[current]
    end

    return out
end

--- @brief
function meta.destroy(instance)
    if meta.is_table(instance) then
        if meta.is_function(instance.signal_disconnect_all) then
            instance:signal_disconnect_all()
        end

        if meta.is_function(instance.destroy) then
            instance:destroy()
        end

        for key in pairs(instance) do
            instance[key] = nil
        end
    end
end

local _enum_to_instances = {}

--- @return meta.Enum
function meta.enum(typename, fields)
    local enum_metatable = {
        __index = function(self, key)
            local result = rawget(fields, key)
            if result == nil then
                rt.error("In meta.enum: trying to access field `", key, "` of enum `", typename, "`, but enum has no such field")
                return nil
            end
            return result
        end,

        __newindex = function()
            rt.error("In meta.enum: trying to modify enum `", typename, "`, but it is immutable")
            return
        end,

        __typename = meta.Enum,
        __tostring = function() return typename end,
        __value_to_is_present = {}
    }

    for _, value in pairs(fields) do
        enum_metatable.__value_to_is_present[value] = true
    end

    local enum = setmetatable({}, enum_metatable)
    rawset(enum, _object_hash_index, _current_hash)
    _current_hash = _current_hash + 1
    rawset(enum, _object_metatable_index, enum_metatable)

    _enum_to_instances[enum] = fields
    _type_to_typename[enum] = typename
    return enum
end

--- @brief
function meta.install(instance, values)
    for key, value in pairs(values) do
        if instance[key] == nil then
            instance[key] = value
        end
    end
    return instance
end

--- @return Boolean
function meta.is_enum_value(x, enum)
    return getmetatable(enum).__value_to_is_present[x] == true
end

--- @return String
function meta.get_enum_name(enum)
    return getmetatable(enum).__tostring()
end

--- @return Number
function meta.hash(instance)
    if instance == nil then return -1 end
    return rawget(instance, _object_hash_index) or -1
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
function meta.make_auto_extend(x, recursive)
    if recursive == nil then recursive = false end
    local metatable = getmetatable(x)
    if metatable == nil then
        metatable = {}
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

    return setmetatable(x, metatable)
end

--- @brief
function meta.make_weak(t)
    local metatable = getmetatable(t)
    if metatable == nil then
        metatable = {}
        setmetatable(t, metatable)
    end

    metatable.__kv = "kv"
    return t
end

--- @brief
function meta.make_immutable(t)
    local metatable ={
        __index = function(_, key)
            local out = t[key]
            if out == nil then
                rt.error("In meta.make_immutable: trying to access `", key, "` of `", tostring(t), "`, but this value does not exist")
                return nil
            end
            return out
        end,

        __newindex = function(_, key, value)
            rt.error("trying to modify table `", tostring(t), "`, but it is immutable")
        end
    }

    return setmetatable({}, metatable), metatable
end

--- @brief
function meta.make_id_table(t, scope, debug_mode)
    meta.assert(t, meta.Table, scope, meta.String, debug_mode, meta.Boolean)

    if debug_mode then
        rt.warning("In meta.make_id_table: debug mode for `", scope, "` is active, ids will be overriden")
    end

    local _as_immutable = function(t, path)
        return setmetatable(t, {
            __index = function(self, key)
                local value = rawget(self, key)
                if value == nil then
                    rt.warning("In ", scope, ": key `", key, "` does not point to valid id")
                    return nil
                else
                    return value
                end
            end,

            __newindex = function(self, key, new_value)
                rt.error("In ", scope, ": trying to modify dictionary, but it is declared immutable")
            end
        })
    end

    local function _make_immutable(t, path)
        path = path or ""
        local to_process = {}
        local n_to_process = 0

        for k, v in pairs(t) do
            local current_path = path == "" and tostring(k) or (path .. "." .. tostring(k))

            if meta.is_table(v) then
                t[k] = _as_immutable(v, current_path)
                table.insert(to_process, {table = v, path = current_path})
                n_to_process = n_to_process + 1
            else
                if debug_mode and t[k] == "todo" then
                    t[k] = current_path
                end
            end
        end

        for i = 1, n_to_process do
            _make_immutable(to_process[i].table, to_process[i].path)
        end
        return _as_immutable(t, path)
    end

    return _make_immutable(t, "")
end

--- @brief
function meta.get_instance_metatable(type)
    meta.assert(type, meta.Type)
    return _type_to_instance_metatable[type]
end

return meta