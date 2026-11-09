local _g_error = _G.error
local _g_assert = _G.assert

local _paste = function(...)
    local to_concat = {}
    for i = 1, select("#", ...) do
        table_push(to_concat, object_to_string((select(i, ...))))
    end
    return table_concat(to_concat)
end

log_println = function(...)
    for i = 1, select("#", ...) do
        local x = select(i, ...)
        if i > 1 then
            io.stdout:write(" ")
        end
        io.stdout:write(object_to_string(x))
    end
    io.stdout:write("\n")
    io.stdout:flush()
end


log_println_error = function(...)
    for i = 1, select("#", ...) do
        local x = select(i, ...)
        if i > 1 then
            io.stderr:write(" ")
        end
        io.stderr:write(object_to_string(x))
    end
    io.stderr:write("\n")
    io.stderr:flush()
end

log_log = function(...)
    log_println("[LOG] ", ...)
end

log_warning = function(...)
    log_println("[WARNING] ", ...)
end

log_error = function(...)
    _g_error(_paste("[ERROR] ", ...))
end

log_fatal = function(...)
    _g_error(_paste("[FATAL] ", ...))
end

log_assert = function(condition, ...)
    _g_assert(condition, _paste(...))
end

log_typecheck_arg_i = function(instance, expected, arg_i)
    if not object_isa(instance, expected) then
        local got
        if object_is_table(instance) and instance.type ~= nil then
            got = instance.type
        else
            got = object_typeof(instance)
        end

        log_error("argument #", arg_i, " `", object_to_string(instance), "` has wrong type. Expected `", expected, "`, got `", got, "`")
    end
end

log_typecheck = function(...)
    local n = select("#", ...)
    _g_assert(n % 2 == 0 and n >= 2, "In log_typecheck: number of arguments must be a multiple of 2")
    local arg_i  = 1
    for i = 1, n, 2 do
        local instance = select(i, ...)
        local expected = select(i + 1, ...)
        log_typecheck_arg_i(instance, expected, arg_i)
        arg_i = arg_i + 1
    end
end

log_call = function(f, ...)
    if f == nil then return end
    return f(...)
end

do
    local _g_pcall = _G.pcall
    log_safe_call = function(f, ...)
        if f == nil then return end
        local res = { _g_pcall(f, ...) }
        if res[1] == true then
            table_remove(res, 1)
            return table_unpack(res)
        else
            log_error(res[2])
            return nil
        end
    end
end