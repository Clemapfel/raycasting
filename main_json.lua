require "common.common"

--local data = love.filesystem.load("fetched_kana_and_vocab.json")
local data = love.filesystem.read("fetched_radicals.json")

dbg("This is the <r>hand</r> radical. If you look at the palm of your right hand, the lines in it probably kinda look like the lines in \u{25163}. Sure it's not a perfect match, and everyone's got different hands, but basically this radical looks like the lines in your hand. You could also think of the horizontal lines in \u{25163} as fingers. That would make for a pretty alien-looking hand, but still a hand\u{8230} of sorts\u{8230}")

function json_to_lua(json_str)
    -- Replace JSON escape sequences with Lua equivalents
    -- Note: Lua and JSON share most escape sequences, but JSON allows escaping '/' and unicode
    -- We'll handle the most common ones here
    local function escape_replacer(str)
        str = string.gsub(str, '\\\\', '\\\\')   -- double backslash
        str = string.gsub(str, '\\"', '\\"')     -- escaped quote
        str = string.gsub(str, '\\/', '/')       -- escaped slash (not needed in Lua)
        str = string.gsub(str, '\\b', '\b')      -- backspace
        str = string.gsub(str, '\\f', '\f')      -- form feed
        str = string.gsub(str, '\\n', '\n')      -- newline
        str = string.gsub(str, '\\r', '\r')      -- carriage return
        str = string.gsub(str, '\\t', '\t')      -- tab
        -- Unicode escape sequences (\uXXXX) are not handled here, as Lua patterns can't do this directly
        -- Optionally, mark them for post-processing:
        str = string.gsub(str, '\\u(%x%x%x%x)', '\\u{%1}') -- mark for later handling
        return str
    end

    -- Replace escape sequences inside all quoted strings
    json_str = string.gsub(json_str, '".-["]', function(s)
        -- Remove the trailing quote for correct processing
        local content = s:sub(1, -2)
        local quote = s:sub(-1)
        return escape_replacer(content) .. quote
    end)

    -- : to =
    local lua_str = string.gsub(json_str, '(%s*):(%s*)', '%1=%2')

    -- line break to newline
    lua_str = string.gsub(lua_str, '\n', "\\n")

    -- [] to {}
    local pattern = "%[(.-)%]"  -- non-greedy match for innermost brackets
    local replaced
    repeat
        lua_str, replaced = string.gsub(lua_str, pattern, "{%1}")
    until replaced == 0

    lua_str = string.gsub(lua_str, "\\u{([0-9a-fA-F]+)}", function(hex)
        return "\\u{" .. tonumber(hex, 16) .. "}"
    end)

    -- "key" to ["key"]
    lua_str = string.gsub(lua_str, '"([%w_]+)"%s*=', '["%1"] =')

    -- Add newlines after opening curly braces
    lua_str = string.gsub(lua_str, "^[\"]{", "{\n")

    -- Add newlines before closing curly braces
    lua_str = string.gsub(lua_str, "}^[\"]", "\n}")

    dbg(lua_str)

    return "return " .. lua_str
end

local chunk, error = load(json_to_lua(data))
if chunk ~= nil then dbg("true") else dbg("-----\n\n\n", error) end
