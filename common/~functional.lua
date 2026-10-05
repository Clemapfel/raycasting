local _eval_key = "eval"
local _new_key = "new"
local _db

local _is_table = function(x) return type(x) == "table" end
local _is_number = function(x) return type(x) == "number" end
local _is_boolean = function(x) return type(x) == "boolean" end
local _is_string = function(x) return type(x) == "string" end
local _is_nil = function(x) return x == nil  end
local _is_range = function(x) return x.__ ~= nil and x.__.range == true end

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
            local function pretty(t, indent)
                indent = indent or ""
                local nextIndent = indent .. "  "

                if type(t) ~= "table" then
                    io.write(tostring(t))
                    return
                end

                local n = 0
                local isArray = true
                for k in pairs(t) do
                    if type(k) ~= "number" then
                        isArray = false
                        break
                    end
                end
                if isArray then
                    n = #t
                    for k in pairs(t) do
                        if type(k) ~= "number" or k < 1 or k > n or k ~= math.floor(k) then
                            isArray = false
                            break
                        end
                    end
                end

                io.write("{\n")
                if isArray then
                    for i = 1, n do
                        io.write(nextIndent)
                        pretty(t[i], nextIndent)
                        io.write(i < n and ",\n" or "\n")
                    end
                else
                    -- collect and stable-sort keys for deterministic output
                    local keys = {}
                    for k in pairs(t) do keys[#keys + 1] = k end
                    table.sort(keys, function(a, b)
                        return tostring(a) < tostring(b)
                    end)

                    for idx, k in ipairs(keys) do
                        io.write(nextIndent)
                        if type(k) == "string" then
                            io.write(k, " = ")
                        else
                            io.write("[", tostring(k), "] = ")
                        end
                        pretty(t[k], nextIndent)
                        io.write(idx < #keys and ",\n" or "\n")
                    end
                end
                io.write(indent .. "}")
            end

            pretty(self._, "")
            io.write("\n")
        end

        io.flush()
        return self
    end

    self.add = function(to_add)
        if _is_range(self) then
            self._[1] = self._[1] + to_add
            self._[2] = self._[2] + to_add
        else
            proxy_resolve(function(x) x = x + to_add end)
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

    self.sqrt = function()
        proxy_resolve(function(x) return math.sqrt(x)  end)
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

new_series = function(...)
    local n = select("#", ...)
    local from, to, step
    if n == 1 then
        from, to, step = 1, select(1, ...), 1
    elseif n == 2 then
        from, to, step = select(1, ...), select(2, ...), 1
    elseif n == 3 then
        fromt, to, step = select(1, ...), select(2, ...), select(3, ...)
    else
        rt.error("In series: expected 1, 2, or 3 arguments, got: `", n, "`")
    end

    return _new_proxy({ range = true }, from, to, step)
end
