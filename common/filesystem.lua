--- @class bd.FileType
bd.FileType = meta.enum("FileType", {
    FILE = "file",
    DIRECTORY = "directory",
    SYMLINK = "symlink",
    OTHER = "other"
})

--- @brief
function bd.file_exists(path)
    meta.assert(path, "String")
    return love.filesystem.getInfo(path) ~= nil
end

--- @brief
function bd.get_file_type(path)
    meta.assert(path, "String")
    local info = love.filesystem.getInfo(path)
    if info == nil then return nil end
    return info.type
end

--- @brief
function bd.is_directory(path)
    meta.assert(path, "String")
    local info = love.filesystem.getInfo(path)
    if info == nil then return false end
    return info.type == bd.FileType.DIRECTORY
end

--- @brief
function bd.is_file(path)
    if path == nil then return false end
    meta.assert(path, "String")

    local info = love.filesystem.getInfo(path)
    if info == nil then return false end
    return info.type == bd.FileType.FILE
end

--- @brief
function bd.create_directory(path)
    meta.assert(path, "String")

    local success = love.filesystem.createDirectory(path)
    if not success then
        rt.error("In bd.create_directory: unable to create directory at `",  path,  "`")
    end
end

--- @class bd.OperatingSystem
bd.OperatingSystem = meta.enum("OperatingSystem",  {
    MAC = "OS X",
    WINDOWS = "Windows",
    LINUX = "Linux",
    ANDROID ="Android",
    IOS = "iOS"
})

--- @brief
function bd.get_operating_system()
    return love.system.getOS()
end

--- @brief
function bd.join_path(...)
    local n = select("#", ...)
    if n == 0 then return "" end

    local to_concatenate = {}
    local table_i = 1
    for i = 1, n do
        local part = select(i, ...)
        if part and part ~= "" then
            part = string.gsub(tostring(part), "[\\/]*$", "") -- remove trailing slashes
            to_concatenate[table_i] = part
            table_i = table_i + 1
        end
    end

    -- Return empty string if no valid parts
    if #to_concatenate == 0 then return "" end

    return table.concat(to_concatenate, "/")
end

--- @brief
function bd.normalize_path(path)
    if path == nil or path == "" then return "" end

    -- starts with `/` or drive letter)
    local is_absolute = path:match("^/") or path:match("^%a:")

    -- replace \\
    path = string.gsub(path, "[\\/]+", "/")

    -- convert C:/ back to C:
    path = string.gsub(path, "^(%a):/?", "%1:/")

    -- remove trailing /
    if path ~= "/" and not path:match("^%a:/$") then path = string.gsub(path, "/$", "") end

    -- catch `/`
    if path == "" and is_absolute then return "/" end

    return path
end

--- @brief
function bd.get_directory_prefix(file_path)
    meta.assert(file_path, "String")
    return string.match(file_path, "^(.*[\\/])[^\\/]*$")
end

--- @brief
--- @param file_path String
--- @param include_extension Boolean
function bd.get_file_name(file_path, include_extension)
    if include_extension == nil then include_extension = false end
    if include_extension then
        return string.match(file_path, "([^/\\]+)$") -- after last / or \
    else
        return string.match(file_path, "([^/\\%.]+)") -- after last / or \ but before last . (if present)
    end
end

--- @brief
function bd.mount_path(path, mount_point)
    meta.assert(path, "String")
    path = bd.normalize_path(path)
    if not love.filesystem.mountFullPath(
        path,
        mount_point,
        "readwrite",
        false
    ) then
        rt.error("In bd.mount_path: unable to mount path at `",  path,  "`")
    end
end

--- @brief copy a single file
function bd.copy_file(source_file_path, destination_file_path)
    meta.assert(source_file_path, "String", destination_file_path, "String")

    source_file_path = bd.normalize_path(source_file_path)
    destination_file_path = bd.normalize_path(destination_file_path)

    if not bd.file_exists(source_file_path) then
        rt.error("In bd.copy_file: file at `",  source_file_path,  "` does not exist")
    end

    if not bd.is_file(source_file_path) then
        rt.error("In bd.copy_file: object at `",  source_file_path,  "` is not a file")
    end

    local destination_directory = bd.get_directory_prefix(destination_file_path)
    if not bd.file_exists(destination_directory) then
        bd.create_directory(destination_directory)
    end

    local file_data, read_error_maybe = love.filesystem.read(source_file_path)
    if not file_data then
        rt.error("In bd.copy_file: unable to read file at `",  source_file_path,  "`:",  read_error_maybe)
    end

    local write_success, write_error_maybe = love.filesystem.write(destination_file_path, file_data)
    if not write_success then
        rt.error("In bd.copy_file: unable to write file to `",  destination_file_path,  "`: ",  write_error_maybe)
    end
end

--- @brief remove a single file
function bd.remove_file(file_path)
    meta.assert(file_path, "String")

    file_path = bd.normalize_path(file_path)

    if not bd.file_exists(file_path) then
        rt.error("In bd.remove_file: file at `",  file_path,  "` does not exist")
    end

    if not bd.is_file(file_path) then
        rt.error("In bd.remove_file: object at `",  file_path,  "` is not a file")
    end

    local remove_success = love.filesystem.remove(file_path)
    if not remove_success then
        rt.error("In bd.remove_file: unable to remove file at `",  file_path,  "`")
    end
end

--- @brief recursively copy a directory and all its contents
function bd.copy_directory(source_directory_path, destination_directory_path)
    meta.assert(source_directory_path, "String", destination_directory_path, "String")

    source_directory_path = bd.normalize_path(source_directory_path)
    destination_directory_path = bd.normalize_path(destination_directory_path)

    if not bd.file_exists(source_directory_path) then
        rt.error("In bd.copy_directory: directory at `",  source_directory_path,  "` does not exist")
    end

    if not bd.is_directory(source_directory_path) then
        rt.error("In bd.copy_directory: object at `",  source_directory_path,  "` is not a directory")
    end

    if not bd.file_exists(destination_directory_path) then
        bd.create_directory(destination_directory_path)
    end

    local items = love.filesystem.getDirectoryItems(source_directory_path)
    for item in values(items) do
        local source_item = source_directory_path .. "/" .. item
        local destination_item = destination_directory_path .. "/" .. item

        if bd.is_file(source_item) then
            bd.copy_file(source_item, destination_item)
        elseif bd.is_directory(source_item) then
            bd.copy_directory(source_item, destination_item)
        end
    end
end

--- @brief recursively remove a directory and all its contents
function bd.remove_directory(directory_path)
    meta.assert(directory_path, "String")

    directory_path = bd.normalize_path(directory_path)

    if not bd.file_exists(directory_path) then
        rt.error("In bd.remove_directory: directory at `",  directory_path,  "` does not exist")
    end

    if not bd.is_directory(directory_path) then
        rt.error("In bd.remove_directory: object at `",  directory_path,  "` is not a directory")
    end

    local items = love.filesystem.getDirectoryItems(directory_path)
    for item in values(items) do
        local item_path = directory_path .. "/" .. item

        if bd.is_file(item_path) then
            bd.remove_file(item_path)
        elseif bd.is_directory(item_path) then
            bd.remove_directory(item_path)
        end
    end

    local remove_success = love.filesystem.remove(directory_path)
    if not remove_success then
        rt.warning("In bd.remove_directory: unable to remove directory at `",  directory_path,  "`")
    end
end

--- @brief
function bd.copy(source_path, destination_path)
    meta.assert(source_path, "String", destination_path, "String")
    if bd.is_directory(source_path) then
        bd.copy_directory(source_path, destination_path)
    elseif bd.is_file(source_path) then
        bd.copy_file(source_path, destination_path)
    else
        rt.error("In bd.copy: object at `",  source_path,  "` is not a file or directory")
    end
end

--- @brief
function bd.remove(source_path)
    meta.assert(source_path, "String")
    if bd.is_directory(source_path) then
        bd.remove_directory(source_path)
    elseif bd.is_file(source_path) then
        bd.remove_file(source_path)
    else
        rt.error("In bd.remove: object at `",  source_path,  "` is not a file or directory")
    end
end

--- @brief
function bd.move_directory(source_path, destination_path)
    bd.copy_directory(source_path, destination_path)
    bd.remove_directory(source_path)
end

--- @brief
function bd.move_file(source_path, destination_path)
    bd.copy_file(source_path, destination_path)
    bd.remove_file(source_path)
end

--- @brief
function bd.move(source_path, destination_path)
    meta.assert(source_path, "String", destination_path, "String")

    source_path = bd.normalize_path(source_path)
    destination_path = bd.normalize_path(destination_path)

    if not bd.file_exists(source_path) then
        rt.error("In bd.move: object at `",  source_path,  "` does not exist")
    end

    if bd.is_file(source_path) then
        bd.move_file(source_path, destination_path)
    elseif bd.is_directory(source_path) then
        bd.move_directory(source_path, destination_path)
    else
        rt.error("In bd.move: object at `",  source_path,  "` is neither a file nor a directory")
    end
end

--- @brief
function bd.load(path, should_sandbox, fenv)
    if should_sandbox == nil then should_sandbox = true end
    meta.assert(path, "String", should_sandbox, "Boolean")

    local load_success, chunk_or_error, love_error = pcall(love.filesystem.load, path)
    if not load_success then
        rt.error("In bd.load: error when parsing file at `",  path,  "`: ",  chunk_or_error)
        return nil
    end

    if love_error ~= nil then
        rt.error("In bd.load: error when loading file at `",  path,  "`: ",  love_error)
        return nil
    end

    local chunk = chunk_or_error

    local setfenv = debug.setfenv or setfenv or _G._setfenv
    if setfenv ~= nil then
        if should_sandbox then
            if fenv == nil then
                setfenv(chunk, {})
            else
                setfenv(chunk, fenv)
            end
        else
            setfenv(chunk, _G)
        end
    end

    local chunk_success, config_or_error = pcall(chunk)
    if not chunk_success then
        rt.error("In bd.load: error when running file at `",  path,  "`: ",  config_or_error)
        return nil
    end
    
    return config_or_error
end

do
    local function _apply(path, f, visited)
        local normalized_path = bd.normalize_path(path)

        -- prevent loop on symlinks
        if visited[normalized_path] then return false end
        visited[normalized_path] = true

        if not bd.file_exists(path) or not bd.is_directory(path) then
            return false
        end

        local items = love.filesystem.getDirectoryItems(path)
        for item in values(items) do
            local full_path = bd.join_path(path, item)
            local type = bd.get_file_type(full_path)
            if type == bd.FileType.DIRECTORY then
                if _apply(full_path, f, visited) == true then
                    return true
                end
            else
                if f(full_path, item) == true then
                    return true -- signal exit
                end
            end
        end

        return false
    end

    --- @brief apply function to full paths of all items recursively
    function bd.apply_recursively(path, f)
        meta.assert(path, "String", f, "Function")

        local type = bd.get_file_type(path)
        if type == bd.FileType.DIRECTORY then
            local visited = {}
            _apply(path, f, visited)
        else
            f(path)
        end
    end
end

--- @brief apply function to full paths of all items in directory (non-recursive)
function bd.apply(path, f)
    meta.assert(path, "String", f, "Function")

    local type = bd.get_file_type(path)
    if type == bd.FileType.DIRECTORY then
        if not bd.file_exists(path) then
            return
        end

        local items = love.filesystem.getDirectoryItems(path)
        for item in values(items) do
            local full_path = bd.join_path(path, item)
            if f(full_path, item) == true then
                return -- exit early if callback returns true
            end
        end
    else
        f(path)
    end
end
