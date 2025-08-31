require "common.meta"
require "common.common"
require "common.log"

if bd == nil then bd = {} end

--- @class bd.SystemArchitecture
bd.SystemArchitecture = meta.enum("SystemArchitexture", {
    WINDOWS_AMD = "WINDOWS_AMD",
    WINDOWS_ARM = "WINDOWS_ARM",
    LINUX_AMD = "LINUX_AMD",
    LINUX_ARM = "LINUX_ARM",
    UNSUPPORTED = "UNSUPPORTED"
})

bd.settings = {
    build_directory = "build",
    build_directory_mount_point = "build",
    workspace_directory = "build/workspace",
    executable_directory = "build/executables",
    dependency_directory = "dependencies",
    module_names = {
        "common",
        "menu",
        "physics",
        "overworld",
    },

    header_names = {
        "main.lua",
        "conf.lua",
        "include.lua"
    },

    executable_download_link_prefix = "https://nightly.link/love2d/love/actions/runs",
    architecture_to_download_link = {
        [bd.SystemArchitecture.WINDOWS_ARM] = "love-windows-arm64.zip",
        [bd.SystemArchitecture.WINDOWS_AMD] = "love-windows-x64.zip",
        [bd.SystemArchitecture.LINUX_ARM] = "love-linux-ARM64.AppImage.zip",
        [bd.SystemArchitecture.LINUX_AMD] = "love-linux-X64.AppImage.zip"
    },

}

--- @brief
function bd.file_exists(path)
    meta.assert(path, "String")
    return love.filesystem.getInfo(path) ~= nil
end

--- @class bd.FileType
bd.FileType = meta.enum("FileType", {
    FILE = "file",
    DIRECTORY = "directory",
    SYMLINK = "symlink",
    OTHER = "other"
})

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
        rt.error("In bd.create_directory: unable to create directory at `" .. path .. "`")
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
            to_concatenate[table_i] = tostring(part)
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
function bd.mount_path(path, mount_point)
    meta.assert(path, "String")
    path = bd.normalize_path(path)
    if not love.filesystem.mountFullPath(
        path,
        mount_point,
        "readwrite",
        true
    ) then
        rt.error("In bd.mount_path: unable to mount path at `" .. path .. "`")
    end
end

do
    local function _apply(path, f, visited)
        local normalized_path = bd.normalize_path(path)

        -- prevent loop on symlinks
        if visited[normalized_path] then return end
        visited[normalized_path] = true

        if not bd.file_exists(path) or not bd.is_directory(path) then
            return
        end

        local items = love.filesystem.getDirectoryItems(path)
        for item in values(items) do
            local full_path = bd.join_path(path, item)
            local type = bd.get_file_type(full_path)
            if type == bd.FileType.DIRECTORY then
                _apply(full_path, f, visited)
            else
                f(full_path)
            end
        end
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

--- @brief
function bd.compile_file(source_file_path, destination_file_path)
    meta.assert(source_file_path, "String", destination_file_path, "String")

    source_file_path = bd.normalize_path(source_file_path)
    destination_file_path = bd.normalize_path(destination_file_path)

    if not bd.file_exists(source_file_path) then
        rt.error("In bd.compile_file: object at `" .. source_file_path .. "` does not exist")
    end

    if not bd.is_file(source_file_path) then
        rt.error("In bd.compile_file: object at `" .. source_file_path .. "` is not a file")
    end

    local file_data, read_error_maybe = love.filesystem.read(source_file_path)
    if not file_data then
        rt.error("In bd.compile_file: unable to read file at `" .. source_file_path .. "`:" .. read_error_maybe)
    end

    -- load chunk
    local compiled_function, compile_error = _G.loadstring(file_data, "@" .. source_file_path)
    if compiled_function == nil then
        rt.error("In bd.compile_file: unable to apply loadstring to content of file at  `" .. source_file_path .. "`: " .. compile_error)
    end

    -- compile to bytecade
    local bytecode = string.dump(compiled_function)
    if bytecode == nil then
        rt.error("In bd.compile_file: failed to generate bytecode for `" .. source_file_path .. "`")
    end

    -- Replace file_data with the bytecode for writing
    file_data = bytecode

    -- create directory if necessary
    local destination_directory = bd.get_directory_prefix(destination_file_path)
    if not bd.file_exists(destination_directory) then
        bd.create_directory(destination_directory)
    end

    local write_success, write_error_maybe = love.filesystem.write(destination_file_path, file_data)
    if not write_success then
        rt.error("In bd.compile_file: unable to copy file from `" .. source_file_path .. "` to `" .. destination_file_path .. "`: " .. write_error_maybe)
    end
end

--- @brief
function bd.copy_file(source_file_path, destination_file_path)
    meta.assert(source_file_path, "String", destination_file_path, "String")

    source_file_path = bd.normalize_path(source_file_path)
    destination_file_path = bd.normalize_path(destination_file_path)

    if not bd.file_exists(source_file_path) then
        rt.error("In bd.copy_file: object at `" .. source_file_path .. "` does not exist")
    end

    if not bd.is_file(source_file_path) then
        rt.error("In bd.copy_file: object at `" .. source_file_path .. "` is not a file")
    end

    local destination_directory = bd.get_directory_prefix(destination_file_path)
    if not bd.file_exists(destination_directory) then
        bd.create_directory(destination_directory)
    end

    local file_data, read_error_maybe = love.filesystem.read(source_file_path)
    if not file_data then
        rt.error("In bd.copy_file: unable to read file at `" .. source_file_path .. "`:" .. read_error_maybe)
    end

    local write_success, write_error_maybe = love.filesystem.write(destination_file_path, file_data)
    if not write_success then
        rt.error("In bd.copy_file: unable to copy file from `" .. source_file_path .. "` to `" .. destination_file_path .. "`: " .. write_error_maybe)
    end
end

do
    local _env_to_architecture = {
        ["AMD64"] = bd.SystemArchitecture.WINDOWS_AMD,
        ["ARM64"] = bd.SystemArchitecture.WINDOWS_ARM,
    }

    --- @brief
    function bd.get_system_architecture()
        if love.system.getOS() == "windows" then
            local architecture = _env_to_architecture[os.getenv("PROCESSOR_ARCHITECTURE")]
            if architecture == nil then
                return bd.SystemArchitecture.UNSUPPORTED
            else
                return architecture
            end
        else
            rt.error("TODO")
        end
    end
end

function bd.unzip(path)
    local zip = require "dependencies.love-zip.love-zip"
    zip:decompress(path)
end

--- @param github_actions_run_id Number run id of love2d github actions repo
--- @param ... bd.SystemArchitecture
function bd.download_love_executables(github_actions_run_id, ...)
    local executable_prefix = bd.settings.executable_directory
    if bd.file_exists(executable_prefix) then
        local success = love.filesystem.remove(executable_prefix)
        if not success then
            rt.warning("In bd.build: unable to remove folder at `" .. executable_prefix .. "`")
        end
    end

    bd.create_directory(executable_prefix)

    local https = require("https")

    for architecture in range(...) do
        local download_link

        local prefix = bd.settings.executable_download_link_prefix .. "/" .. github_actions_run_id
        local postfix = bd.settings.architecture_to_download_link[architecture]
        if postfix == nil then
            rt.error("In bd.download_love_executable: unsupported system architecture: `" .. architecture .. "`")
        end

        download_link = prefix .. "/" .. postfix
        local code, download_data = https.request(download_link)
        if code == 404 then
            rt.error("In bd.download_love_executable: unable to download executable from `" .. download_link .. "`, received `" .. code .. "`")
        end

        local write_path = bd.join_path(executable_prefix, postfix)
        local write_success, write_error_maybe = love.filesystem.write(write_path, download_data)
        if not write_success then
            rt.error("In bd.download_love_executables: unable to write downloaded data to `" .. write_path .. "`")
        end
    end
end

do
    local _is_lua_file = function(path)
        local name = string.match(path, "/([^/]+)%.lua$")
        return name ~= nil and name ~= "conf" -- exclude conf.lua
    end

    --- @brief
    function bd.build(architecture, github_actions_run_id)
        local build_prefix = bd.settings.build_directory_mount_point

        if architecture == bd.SystemArchitecture.UNSUPPORTED then
            rt.error("In bd.build: cannot build for unsupported system architecture")
        end
        meta.assert_enum_value(architecture, bd.SystemArchitecture, 1)
        meta.assert_typeof(github_actions_run_id, "Number", 2)

        -- create workspace directory
        local workspace_prefix = bd.settings.workspace_directory
        if bd.file_exists(workspace_prefix) then
            local success = love.filesystem.remove(workspace_prefix)
            if not success then
                rt.warning("In bd.build: unable to remove folder at `" .. workspace_prefix .. "`")
            end
        end

        bd.create_directory(workspace_prefix)

        -- copy all modules into workspace
        for module_name in values(bd.settings.module_names) do
            bd.apply_recursively(module_name, function(from_path)
                -- check if filename has ~ prefix
                if string.match(from_path, "[\\/](~[^\\/]*)$") == nil then
                    local destination_path = bd.join_path(workspace_prefix, from_path)
                    if _is_lua_file(from_path) then
                        -- if lua, compile to bytecode
                        bd.compile_file(from_path, destination_path)
                    else
                        bd.copy_file(from_path, destination_path)
                    end
                end
            end)
        end

        -- copy headers
        for file in values(bd.settings.header_names) do
            local destination_path = bd.join_path(workspace_prefix, file)
            if _is_lua_file(file) then
                bd.compile_file(file, destination_path)
            else
                bd.copy_file(file, destination_path)
            end
        end

        -- copy dependencies unaltered
        bd.apply_recursively(bd.settings.dependency_directory, function(from_path)
            bd.copy_file(from_path, bd.join_path(workspace_prefix, from_path))
        end)
    end
end

-- mount build directory
do
    local build_prefix = bd.settings.build_directory_mount_point
    local source_prefix = love.filesystem.getSource()
    local build_directory_path = bd.join_path(source_prefix, bd.settings.build_directory)
    bd.mount_path(build_directory_path, build_prefix)

    if not bd.file_exists(bd.settings.build_directory) then
        rt.error("In bd.build: `/build` does not exists")
    end
end