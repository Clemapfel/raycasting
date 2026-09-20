local _eval_key = "eval"
local _new_key = "new"
local _db

local _is_table = function(x) return type(x) == "table" end
local _is_number = function(x) return type(x) == "number" end
local _is_range = function(x) return x.__ ~= nil and x.__.range == true end
local _is_functor = function(x) return x.__ ~= nil and x.__.functor == true end

local _new_proxy = function(tags, ...)
    local self = { _ = { ... }, __ = tags }

    local proxy_resolve = function(f)
        local function proxy_resolve_inner(t)
            for i, v in pairs(t) do
                if _is_table(v) then
                    proxy_resolve_inner(v)
                else
                    f(v)
                end
            end
        end

        proxy_resolve_inner(self._)
    end

    self.value = function()
        if _is_range(self) then
            local res = {}
            for i = self._[1], self._[2], self._[3]  do
                table.insert(res, i)
            end
            return res
        else
            return table.unpack(self._)
        end
    end

    self.identity = function()
        return self._
    end

    self.print = function()
        if _is_range(self) then
            for t = self._[1], self._[2], self._[3] do
                io.write(t, " ")
            end
        else
            proxy_resolve(function(x) io.write(x) end)
        end

        io.flush()
        return self
    end

    self.add = function(to_add)
        if _is_range(self) then
            self._[1] = self._[1] + to_add
            self._[2] = self._[2] + to_add
        else
            local function resolve(t)
                for k, v in pairs(t) do
                    if _is_table(v) then
                        resolve(v)
                    else
                        t[k] = v + to_add
                    end
                end
            end
            resolve(self._)
        end

        return self
    end

    self.subtract = function(to_subtract)
        if _is_range(self) then
            self._[1] = self._[1] - to_subtract
            self._[2] = self._[2] - to_subtract
        else
            proxy_resolve(function(x) return x - to_subtract end)
        end
        return self
    end

    self.multiply = function(to_multiply)
        proxy_resolve(function(x) return x * to_multiply end)
        return self
    end

    self.divide = function(to_divide)
        proxy_resolve(function(x) return x / to_divide end)
        return self
    end

    self.pow = function(exponent)
        proxy_resolve(function(x) return x ^ exponent end)
        return self
    end

    self.apply = function(to_apply, ...)
        local args = { ... }
        if _is_range(self) then
            local from, to, step = table.unpack(self._)
            self._ = {}
            local i = 1
            for t = from, to, step do
                self._[i] = to_apply(t, table.unpack(args))
                i = i + 1
            end
        else
            local function resolve(t)
                for i, v in pairs(t) do
                    if _is_table(v) then
                        resolve(v)
                    else
                        t[i] = to_apply(v, table.unpack(args))
                    end
                end
            end

            resolve(self._)
        end

        return self
    end

    self.collect = function(to_apply, ...)
        local args = { ... }
        if _is_range(self) then
            local from, to, step = table.unpack(self._)
            local res = {}

            local i = 1
            for t = from, to, step or 1 do
                res[i] = to_apply(t, table.unpack(args))
                i = i + 1
            end

            self.__ = {}
            self._ = res
            return self
        else
            local function resolve(t)
                local res = {}
                for i, v in pairs(t) do
                    if _is_table(v) then
                        res[i] = resolve(v)
                    else
                        res[i] = to_apply(v, table.unpack(args))
                    end
                end
                return res
            end

            self._ = resolve(self._)
            return self
        end
    end

    return self
end

new = function(...)
    return _new_proxy({}, ... )
end

newRange = function(...)
    local n = select("#", ...)
    local from, to, step
    if n == 1 then
        from, to, step = 1, select(1, ...), 1
    elseif n == 2 then
        from, to, step = select(1, ...), select(2, ...), 1
    elseif n == 3 then
        fromt, to, step = select(1, ...), select(2, ...), select(3, ...)
    else
        rt.error("In newRange")
    end

    return _new_proxy({ range = true }, from, to, step)
end
