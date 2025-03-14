require "common.common"
local meta = {}

--- @class meta.Type
--- @class meta.Enum

local _current_hash = 0

local _object_metatable_index = 1
local _object_hash_index = _object_metatable_index + 1
local _object_signal_component_index = _object_hash_index + 1

local _instantiate_name = "instantiate"
local _typenames = {
    ["Type"] = true,
    ["Enum"] = true
}
local _type_to_super = {}
local _type_to_instance_metatable = {}
local _typename_to_type = {}
local _type_to_typename = {}

--- @brief
function meta.get_typename(type)
    return type[_object_metatable_index].__typename
end

local _native_type_to_type = {
    ["nil"] = "Nil",
    ["number"] = "Number",
    ["string"] = "String",
    ["boolean"] = "Boolean",
    ["table"] = "Table",
    ["function"] = "Function",
    ["thread"] = "Coroutine"
}

--- @class Nil
--- @class Number
--- @class String
--- @class Boolean
--- @class Table
--- @class Function
--- @class Coroutine

--- @brief
function meta.typeof(instance)
    if type(instance) ~= "table" then
        local mapped = _native_type_to_type[type(instance)]
        if mapped == nil then return "Unknown" else return mapped end
    end

    local metatable = getmetatable(instance)
    if type(metatable) ~= "table" then
        local mapped = _native_type_to_type[type(instance)]
        if mapped == nil then return "Unknown" else return mapped end
    else
        local typename = metatable.__typename
        if typename == nil then
            return "Table"
        else
            return typename
        end
    end
end

--- @brief
function meta.isa(x, type)
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
function meta.assert(...)
    local n = select("#", ...)
    assert(n % 2 == 0)
    for i = 1, n, 2 do
        local instance = select(i+0, ...)
        local type = select(i+1, ...)
        local typename = _type_to_typename[type]
        if typename == nil then typename = type end -- assume string

        assert(meta.typeof(instance) == typename, "In meta.assert: wrong type for argument #" .. i.. ": expected `" .. typename .. "`, got `" .. meta.typeof(instance) .. "`")
    end
end

--- @brief
function meta.assert_typeof(x, type, argument_i)
    local instance_type = meta.typeof(x)
    local prefix = ""
    if argument_i ~= nil then
        prefix = "For argument #" .. argument_i .. ": "
    end
    assert(instance_type == type, prefix .. "expected `" .. type .. "`, got `" .. meta.typeof(x) .. "`")
end

--- @brief
function meta.assert_enum_value(x, enum, argument_i)
    local prefix = ""
    if argument_i ~= nil then
        prefix = "For argument #" .. argument_i .. ": "
    end
    assert(meta.is_enum_value(x, enum), prefix .. "expected value of enum `" .. _type_to_typename[enum] .. "`, got `" .. tostring(x) .. "`")
end
--- @brief
function meta.is_nil(x)
    return x == nil
end

--- @brief
function meta.is_number(x)
    return _G.type(x) == "number"
end

--- @brief
function meta.is_string(x)
    return _G.type(x) == "string"
end

--- @brief
function meta.is_boolean(x)
    return _G.type(x) == "boolean"
end

--- @brief
function meta.is_table(x)
    return _G.type(x) == "table"
end

--- @brief
function meta.is_function(x)
    return _G.type(x) == "function"
end

-- signals

local _signal_emit = function(instance, id, ...)
    local component = instance[_object_signal_component_index]
    local entry = component[id]
    if entry == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_emit: no signal with id `" .. id .. "`")
        return
    end

    for callback in values(entry.callbacks_in_order) do
        callback(instance, ...)
    end
end

local _signal_try_emit = function(instance, id, ...)
    local component = instance[_object_signal_component_index]
    if component == nil then return false end

    local entry = component[id]
    if entry == nil then return false end

    local emitted = false
    for callback in values(entry.callbacks_in_order) do
        callback(instance, ...)
        emitted = true
    end
    return emitted
end

local _signal_connect = function(instance, id, callback)
    local component = instance[_object_signal_component_index]
    local entry = component[id]
    if entry == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_connect: no signal with id `" .. id .. "`")
        return
    end

    local callback_id = entry.current_callback_id
    entry.current_callback_id = entry.current_callback_id + 1
    entry.callback_id_to_callback[callback_id] = callback
    table.insert(entry.callbacks_in_order, callback)
end

local _signal_disconnect = function(instance, id, callback_id)
    local component = instance[_object_signal_component_index]
    if component == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_disconnect: object `" .. meta.typeof(self) .. "` does not have any signals")
        return
    end

    local entry = component[id]
    if entry == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_disconnect: no signal with id `" .. id .. "`")
        return
    end

    if callback_id == nil then
        self:signal_disconnect_all(id)
    else
        local callback = entry.callback_id_to_callback[callback_id]
        if callback == nil then
            rt.error("In " .. meta.typeof(instance) .. ".signal_disconnect: no callback with id `" .. id .. "` connected to signal `" .. id .. "`")
            return
        end
    end
end

local _signal_list_handler_ids = function(instance, id)
    local component = instance[_object_signal_component_index]
    if component == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_list_handler_id: object `" .. meta.typeof(self) .. "` does not have any signals")
        return
    end

    local entry = component[id]
    if entry == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_list_handler_id: no signal with id `" .. id .. "`")
        return
    end

    return { table.unpack(entry.callbacks_in_order) }
end

local _signal_disconnect_all = function(instance, id)
    local component = instance[_object_signal_component_index]
    if component == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_disconnect_all: object `" .. meta.typeof(self) .. "` does not have any signals")
        return
    end

    local entry = component[id]
    if entry == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_disconnect_all: no signal with id `" .. id .. "`")
        return
    end

    entry.callback_id_to_callback = {}
    entry.callbacks_in_order = setmetatable({}, {
        __mode = "kv"
    })
end

local _signal_set_is_blocked = function(instance, id, b)
    local component = instance[_object_signal_component_index]
    if component == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_set_is_blocked: object `" .. meta.typeof(self) .. "` does not have any signals")
        return
    end

    local entry = component[id]
    if entry == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_set_is_blocked: no signal with id `" .. id .. "`")
        return
    end

    entry.is_blocked = b
end

local _signal_get_is_blocked = function(instance, id)
    local component = instance[_object_signal_component_index]
    if component == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_get_is_blocked: object `" .. meta.typeof(self) .. "` does not have any signals")
        return
    end

    local entry = component[id]
    if entry == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_get_is_blocked: no signal with id `" .. id .. "`")
        return
    end

    return entry.is_blocked
end

local _signal_block_all = function(instance)
    local component = instance[_object_signal_component_index]
    if component == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_block_all: object `" .. meta.typeof(self) .. "` does not have any signals")
        return
    end

    for entry in values(component) do
        entry.is_blocked = true
    end
end

local _signal_unblock_all = function(instance)
    local component = instance[_object_signal_component_index]
    if component == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_unblock_all: object `" .. meta.typeof(self) .. "` does not have any signals")
        return
    end

    for entry in values(component) do
        entry.is_blocked = true
    end
end

local _signal_has_signal = function(instance, id)
    local component = instance[_object_signal_component_index]
    if component == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_has_signal: object `" .. meta.typeof(self) .. "` does not have any signals")
        return
    end

    return component[id] ~= nil
end

local _signal_list_handler_ids = function(instance, id)
    local component = instance[_object_signal_component_index]
    if component == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_list_handler_ids: object `" .. meta.typeof(self) .. "` does not have any signals")
        return
    end

    local entry = component[id]
    if entry == nil then
        rt.error("In " .. meta.typeof(instance) .. ".signal_list_handler_ids: no signal with id `" .. id .. "`")
        return
    end

    local out = {}
    for callback_id in keys(entry.callback_id_to_callback) do
        table.insert(out, callback_id)
    end
    return out
end

local _signal_list_signals = function(instance)
    local component = instance[_object_signal_component_index]
    if component == nil then return {} end

    local out = {}
    for id in keys(component) do
        table.insert(out, id)
    end
    return out
end

local function _install_signals(instance, type)
    for id in values(type[_object_metatable_index].__signals) do
        local component = instance[_object_signal_component_index]
        if component == nil then
            component = {}
            instance[_object_signal_component_index] = component
            instance.signal_emit = _signal_emit
            instance.signal_try_emit = _signal_try_emit
            instance.signal_connect = _signal_connect
            instance.signal_disconnect = _signal_disconnect
            instance.signal_disconnect_all = _signal_disconnect_all
            instance.signal_set_is_blocked = _signal_set_is_blocked
            instance.signal_get_is_blocked = _signal_get_is_blocked
            instance.signal_block_all = _signal_block_all
            instance.signal_unblock_all = _signal_unblock_all
            instance.signal_has_signal = _signal_has_signal
            instance.signal_list_handler_ids = _signal_list_handler_ids
            instance.signal_list_signals = _signal_list_signals
        end

        component[id] = {
            is_blocked = false,
            current_callback_id = 0,
            callback_id_to_callback = {},
            callbacks_in_order = setmetatable({}, {
                __mode = "kv"
            })
        }
    end
end

--- @param typename String
--- @param super meta.Type
--- @return meta.Type
function meta.class(typename, super, instantiate_maybe)
    meta.assert(typename, "String")
    if super ~= nil then assert(meta.typeof(super) == "Type") end
    if instantiate_maybe ~= nil then assert(meta.is_function(instantiate_maybe)) end

    -- instance metatable
    local type = {}
    local instance_metatable = {
        __index = type,
        __typename = typename,
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
    local type_metatable = {
        __call = function(self, ...)
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
            if type.instantiate ~= nil then
                type.instantiate(instance, ...)
            end

            for current_super in values(supers) do
                if current_super.instantiate ~= nil then
                    current_super.instantiate(instance) -- no varargs
                end
            end

            return instance
        end,

        __index = super,
        __typename = "Type",
        __signals = {}
    }

    setmetatable(type, type_metatable)
    rawset(type, _object_hash_index, _current_hash)
    _current_hash = _current_hash + 1
    rawset(type, _object_metatable_index, type_metatable)

    _type_to_super[type] = super
    _type_to_instance_metatable[type] = instance_metatable
    _typename_to_type[typename] = type
    _type_to_typename[type] = typename

    if instantiate_maybe ~= nil then
        type.instantiate = instantiate_maybe
    end

    return type
end

--- @brief
function meta.abstract_class(typename, super)
    local type = meta.class(typename, super)
    local type_metatable = getmetatable(type)
    type_metatable.__call = function()
        rt.error("In " .. typename .. "(): trying to instantiated type, but it was declared abstract")
    end
    return type
end

--- @brief
function meta.add_signals(type, ...)
    meta.assert(type, "Type")

    local metatable = type[_object_metatable_index]
    for i = 1, select("#", ...) do
        local id = select(i, ...)
        assert(meta.typeof(id) == "String")
        table.insert(metatable.__signals, id)
    end
end

local _enum_to_instances = {}

--- @return meta.Enum
function meta.enum(typename, fields)
    local enum_metatable = {
        __index = function(self, key)
            local result = fields[key]
            if result == nil then
                rt.error("In meta.enum: trying to access field `" .. key .. "` of enum `" .. typename .. "`, but enum has no such field")
                return nil
            end
            return result
        end,

        __newindex = function()
            rt.error("In meta.enum: trying to modify enum `" .. typename .. "`, but it is immutable")
            return
        end,

        __typename = "Enum",
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
        instance[key] = value
    end
    return instance
end

--- @return boolean
function meta.is_enum_value(x, enum)
    return getmetatable(enum).__value_to_is_present[x] == true
end

--- @return number
function meta.hash(instance)
    return rawget(instance, _object_hash_index)
end

--- @return table
function meta.instances(enum)
    return _enum_to_instances[enum]
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
                rt.error("trying to access `" .. key .. "` of `" .. tostring(t) .. "`, but this value does not exist")
                return nil
            end
            return out
        end,

        __newindex = function(_, key, value)
            rt.error("trying to modify table `" .. tostring(t) .. "`, but it is immutable")
        end
    }

    return setmetatable({}, metatable), metatable
end

--- @brief
function meta.get_instance_metatable(type)
    meta.assert(type, "Type")
    return _type_to_instance_metatable[type]
end

return meta