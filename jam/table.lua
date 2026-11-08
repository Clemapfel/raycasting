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