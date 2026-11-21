
if true then -- base lua does not have the sep argument
    function string.rep(s, n, sep)
        local n_characters = n
        if sep ~= nil then n_characters = n_characters + (n - 1) end
        local out = table_new and table.new(n_characters, 0) or {}
        for i = 1, n do
            table.insert(out, s)
            if i ~= (n - 1) then
                table.insert(out, sep)
            end
        end

        return table.concat(out)
    end
end
