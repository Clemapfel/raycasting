local modules = {}
for _, module in pairs({
    "window",
    "physics",
    "math",
    "graphics",
    "font",
    "image",
    "audio",
    "sound",
    "mouse",
    "joystick",
    "system",
    "data",
    "keyboard",
    "event",
    "timer",
    "thread",
    "filesystem"
}) do
    modules[module] = true
end

local exceptions = { "URL", "FPS", "OS" }

if rt == nil then rt = {} end
for module_id, function_ids in pairs(package.loaded["love"]) do
    if rt[module_id] == nil then rt[module_id] = {} end
    if modules[module_id] == true then
        for function_id, f in pairs(function_ids) do
            if type(f) == "function" then
                local parsed_name

                local parsed_id = function_id
                for _, exception in ipairs(exceptions) do
                    local title_case = string.upper(string.sub(exception, 1, 1)) .. string.lower(string.sub(exception, 2))
                    parsed_id = string.gsub(parsed_id, exception, title_case)
                end

                local ctor = string.match(parsed_id, "^new(.*)")
                if ctor ~= nil then
                    parsed_name = ctor
                else
                    local words = {}
                    for word in string.gmatch(parsed_id, "%u?[^%u]*") do
                        if #word > 0 then
                            table.insert(words, word)
                        end
                    end
                    if #words == 0 then table.insert(words, parsed_id) end

                    for i, word in ipairs(words) do
                        words[i] = string.lower(word)
                    end

                    parsed_name = table.concat(words, "_")
                end

                rt[module_id][parsed_name] = f
            end
        end
    end
end
