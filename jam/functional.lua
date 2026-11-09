do
    iter_apply = function(f, ...)
        log_assert(f, Function_t)

        for i = 1, select("#", ...) do
            log_call(f, select(i, ...))
        end
    end

    iter_apply_recursively = function(f, ...)
        log_assert(f, Function_t)

        local function _apply_inner(v)
            if object_is_table(v) then
                for key, value in pairs(v) do
                    _apply_inner(value)
                end
            else
                log_call(f, v)
            end
        end

        for i = 1, select("#", ...) do
                local e = select(i, ...)
            _apply_inner(e)
        end
    end
end

do
    iter_map = function(t, f, ...)
        for i = 1, table_sizeof(t) do
            local x = t[i]
            local res = f(x, ...)
            if res ~= nil then
                t[i] = res
            end
        end

        return t
    end

    iter_map_recursively = function(x, f, ...)
        if object_is_table(x) then
            for i = 1, table_sizeof(x) do
                local res = iter_map_recursively(x[i], f, ...)
                if res ~= nil then
                    x[i] = res
                end
            end
            return x
        end

        return f(x, ...)
    end
end

do
    iter_collect = function(f, state, cursor)
        log_assert(f, Function_t)

        local result = {}
        local n = 0
        for v in f, state, cursor do
            n = n + 1
            result[n] = v
        end

        return result
    end
end

do
    local _noop = function() return nil end

    do
        local _keys_iterator = function(t, k)
            local next_key, _ = next(t, k)
            return next_key
        end

        iter_keys = function(t)
            log_typecheck(t, Table_t)
            return _keys_iterator, t
        end
    end

    iter_values = function(t)
        log_typecheck(t, Table_t)

        local k, v
        return function()
            k, v = next(t, k)
            return v
        end
    end

    do
        local function _foreach_iterator(state)
            local next_i, out = next(state, state[1])
            state[1] = next_i
            return out, state
        end

        iter_varargs = function(...)
            if select("#", ...) == 0 then return _noop end
            return _foreach_iterator, { 1, ... }
        end
    end

    do
        local function _range_up(to, current)
            local next_i = current + 1
            if next_i <= to then
                return next_i
            else
                return nil
            end
        end

        local function _range_down(to, current)
            local next_i = current - 1
            if next_i >= to then
                return next_i
            else
                return nil
            end
        end

        local function _range_step(state, current)
            local step = state[2]
            local next_i = current + step
            if step > 0 then
                if next_i <= state[1] then
                    return next_i
                else
                    return nil
                end
            else
                if next_i >= state[1] then
                    return next_i
                else
                    return nil
                end
            end
        end

        iter_range = function(from, to, step)
            log_typecheck(from, Number_t, to, Number_t)
            if step ~= nil then
                log_typecheck_arg_i(step, Number_t, 3)
                log_assert(step ~= 0, "In range: step cannot be 0")
            end

            if step == nil or step == 1 or step == -1 then
                -- 0 allocation branch
                if (step == nil) and (from <= to) or step == 1 then
                    return _range_up, to, from - 1
                else
                    return _range_down, to, from + 1
                end
            end

            return _range_step, { to, step }, from - step
        end
    end
end

iter_chain = function(x, ...)
    local current = x
    for i = 1, select("#", ...) do
        local f = select(i, ...)
        x = log_call(f, x)
    end
    return x
end