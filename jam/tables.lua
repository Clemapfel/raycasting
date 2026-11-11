table_push = table.insert
table_remove = table.remove

local _g_table_new
do
    local success, table_new = pcall(require, "table.new")
    if success == true then
        _g_table_new = table_new
    else
        _g_table_new = function()
            return {}
        end
    end
end

local _g_table_clear
do
    local success, table_clear = pcall(require, "table.clear")
    if success == true then
        _g_table_clear = table_clear
    else
        _g_table_clear = function(t)
            for k in iter_keys(t) do
                t[k] = nil
            end

            return t
        end
    end
end

table_clear = _g_table_clear

table_new = function(n)
    if n == nil then n = 0 end
    return _g_table_new(n, 0)
end

table_sizeof = function(t)
    return #t
end

table_count = function(t)
    local n = 0
    for _, _ in pairs(t) do
        n = n + 1
    end
    return n
end

local _g_unpack = table.unpack or unpack
table_unpack = function(t)
    log_typecheck(t, Table_t)

    return _g_unpack(t)
end

local _g_concat = table.concat
table_concat = function(t)
    log_typecheck(t, Table_t)
    for i, x in ipairs(t) do t[i] = tostring(x) end

    return _g_concat(t)
end

table_sub = function(t, from, to)
    log_typecheck(t, Table_t, from, Integer_t, to, Integer_t)
    log_assert(from <= to)

    return _g_unpack(t, from, to)
end

table_rep = function(to_repeat, n)
    log_typecheck_arg_i(n, Integer_t)
    local out = table_new(n)
    for i = 1, n do out[i] = to_repeat end
    return out
end

table_deepcopy = function(t)
    if object_is_table(t) then
        local copy = {}
        for k, v in pairs(t) do
            copy[table_deepcopy(k)] = table_deepcopy(v)
        end
        return copy
    else
        return t
    end
end

do -- table_serialize
    local _typeof = _G.type

    local _tabspace = "    "
    local _serialize_get_indent = function(n_indent_tabs)
        return string.rep(_tabspace, n_indent_tabs)
    end

    local _serialize_insert = function(buffer, ...)
        if buffer == nil then return end
        for i = 1, select("#", ...) do
            local value = select(i, ...)
            table_push(buffer, value)
        end
    end

    local _tostring = _G.tostring

    local function _safe_comment_str(val)
        return (string.gsub(_tostring(val), "([%[%]])", "%1 "))
    end

    local _is_type_serializable = function(t)
        return t ~= "function" and t ~= "userdata" and t ~= "thread" and t ~= "cdata"
    end

    local function _serialize_inner(buffer, object, n_indent_tabs, seen, comment_out, disallowed_types)
        local object_type = _typeof(object)
        if object_type == "number" and disallowed_types["number"] ~= true then
            if object == math_positive_inf then
                _serialize_insert(buffer, "math.huge")
            elseif object == math_negative_inf then
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
                    local k_type = _typeof(key)
                    local v_type = _typeof(value)

                    if disallowed_types[k_type] ~= true and disallowed_types[v_type] ~= true then
                        local k_unserializable = not _is_type_serializable(k_type)
                        local v_unserializable = not _is_type_serializable(v_type)

                        -- check for immediate cycles to prevent evaluating keys to nil
                        local k_cyclic = (k_type == "table" and seen[key])
                        local v_cyclic = (v_type == "table" and seen[value])

                        if k_unserializable or v_unserializable or k_cyclic or v_cyclic then
                            if comment_out then
                                _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs),
                                    "--[[ [\"", _safe_comment_str(key), "\"] = ", _safe_comment_str(value), " ]],\n")
                            end
                        else
                            _serialize_insert(buffer, _serialize_get_indent(n_indent_tabs), "[")
                            _serialize_inner(buffer, key, n_indent_tabs, seen, comment_out, disallowed_types)
                            _serialize_insert(buffer, "] = ")
                            _serialize_inner(buffer, value, n_indent_tabs, seen, comment_out, disallowed_types)
                            _serialize_insert(buffer, ",\n")
                        end
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

    local function _serialize(object, comment_out_unserializable, disallowed_types_set)
        if comment_out_unserializable == nil then comment_out_unserializable = true end
        if object == nil then return "nil" end
        if disallowed_types_set == nil then disallowed_types_set = {} end

        local buffer = {}
        local seen = {}
        _serialize_inner(
            buffer,
            object,
            0,
            seen,
            comment_out_unserializable,
            disallowed_types_set
        )

        return table_concat(buffer, "")
    end

    local function _is_serializable(value, seen)
        local value_type = _typeof(value)
        if value_type == "function" or value_type == "userdata" or value_type == "thread" or value_type == "cdata" then
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

    table_is_serializable = function(t)
        if not object_is_table(t) then return false end
        return _is_serializable(t, {})
    end

    table_serialize = function(t, disallowed_types)
        if disallowed_types == nil then disallowed_types = {} end
        log_typecheck_arg_i(disallowed_types, Table_t, 2)

        local set = {}
        for current_type in values(disallowed_types) do
            set[current_type] = true
        end

        return _serialize(t, true, set)
    end
end

do -- table_stable_sort
    local _buffer = {}
    local _small_run_threshold = 16

    local function _insertion_sort(array, left, right, compare)
        local index = left + 1
        while index <= right do
            local value = array[index]
            local scan = index - 1
            while scan >= left and compare(value, array[scan]) do
                array[scan + 1] = array[scan]
                scan = scan - 1
            end
            array[scan + 1] = value
            index = index + 1
        end
    end

    local function _merge_pass(destination, source, length, run_width, compare)
        local run_start = 1
        while run_start <= length do
            local left_end = run_start + run_width - 1
            if left_end >= length then
                for index = run_start, length do
                    destination[index] = source[index]
                end
                break
            end
            local right_end = run_start + run_width + run_width - 1
            if right_end > length then
                right_end = length
            end
            local left_index = run_start
            local right_index = left_end + 1
            local output_index = run_start
            while left_index <= left_end and right_index <= right_end do
                local left_value = source[left_index]
                local right_value = source[right_index]
                if compare(right_value, left_value) then
                    destination[output_index] = right_value
                    right_index = right_index + 1
                else
                    -- prefer left on equality to maintain stability
                    destination[output_index] = left_value
                    left_index = left_index + 1
                end
                output_index = output_index + 1
            end
            while left_index <= left_end do
                destination[output_index] = source[left_index]
                left_index = left_index + 1
                output_index = output_index + 1
            end
            while right_index <= right_end do
                destination[output_index] = source[right_index]
                right_index = right_index + 1
                output_index = output_index + 1
            end
            run_start = right_end + 1
        end
    end

    local _default_comparator = function(a, b) return a < b end

    table_sort = table.sort

    table_stable_sort = function(array, comparator)
        if comparator == nil then comparator = _default_comparator end

        local length = #array
        if length < 2 then
            return array
        end

        -- insertion sort each small run in-place before merging
        local run_start = 1
        while run_start <= length do
            local run_end = run_start + _small_run_threshold - 1
            if run_end > length then
                run_end = length
            end

            _insertion_sort(array, run_start, run_end, comparator)
            run_start = run_end + 1
        end

        if length <= _small_run_threshold then
            return array
        end

        table_clear(_buffer)

        local source = array
        local destination = _buffer
        local run_width = _small_run_threshold
        while run_width < length do
            _merge_pass(destination, source, length, run_width, comparator)
            source, destination = destination, source
            run_width = run_width + run_width
        end

        -- if the final result is in the temp buffer, copy it back to the array
        if source ~= array then
            for index = 1, length do
                array[index] = source[index]
            end
        end
        return array
    end
end
