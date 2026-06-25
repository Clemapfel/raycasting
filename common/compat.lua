
local table_clear = pcall(require, "table.clear")
if not table_clear then
    function table.clear(t)
        local to_clear = {}
        for k, v in pairs(t) do
            table.insert(to_clear, k)
        end

        for _, k in ipairs(t) do
            t[k] = nil
        end

        return t
    end
end

local table_new = pcall(require, "table.new")
if not table_new then
    function table.new(_)
        return {}
    end
end

if true then -- base lua does not have the sep argument
    function string.rep(s, n, sep)
        local out = table_new and table.new(n + (n - 1) * sep, 0) or {}
        for i = 1, n do
            table.insert(out, s)
            if i ~= (n - 1) then
                table.insert(out, sep)
            end
        end

        return table.concat(out)
    end
end
