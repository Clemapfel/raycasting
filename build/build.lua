require "common.meta"
require "common.common"
require "common.log"

if bd == nil then bd = {} end

--- @class bd.SystemArchitecture
bd.SystemArchitecture = meta.enum("SystemArchitexture", {
    WINDOWS_AMD = "windows_amd",
    WINDOWS_ARM = "windows_arm",
    LINUX_AMD = "linux_amd",
    LINUX_ARM = "linux_arm",
    MAC_OS = "mac_os",
    UNSUPPORTED = "unsupported"
})

bd.settings = {
    build_directory = "build",
    build_directory_mount_point = "build",
    workspace_directory = "build/workspace",
    output_directory = "build/out",
    executable_directory = "build/executables",
    dependency_directory = "dependencies",

    love_file_name = "chroma_drift",
    love_file_name_extension = ".love",

    love_executable_name = "love.exe",
    love_executable_c_name = "lovec.exe",

    executable_name = "game",
    executable_c_name = "game_debug",

    favicon_location = "assets/favicon",
    favicon_name = "favicon.ico",

    license_location = "assets",
    license_name = "license.txt",
    love_license_name = "love_license.txt",

    module_names = {
        "common",
        "menu",
        "physics",
        "overworld",
        "assets"
    },

    header_names = {
        "main.lua",
        "conf.lua",
        "include.lua"
    },

    dependency_names = {
        "slick"
    },

    executable_download_link_prefix = "https://nightly.link/love2d/love/actions/runs",
    architecture_to_input_filename = {
        [bd.SystemArchitecture.WINDOWS_ARM] = "love-windows-arm64.zip",
        [bd.SystemArchitecture.WINDOWS_AMD] = "love-windows-x64.zip",
        [bd.SystemArchitecture.LINUX_ARM] = "love-linux-ARM64.AppImage.zip",
        [bd.SystemArchitecture.LINUX_AMD] = "love-linux-X64.AppImage.zip",
        [bd.SystemArchitecture.MAC_OS] = "love-macos.zip"
    },
    
    architecture_to_output_filename = {
        [bd.SystemArchitecture.WINDOWS_ARM] = "chroma_drift_windows_x86_64",
        [bd.SystemArchitecture.WINDOWS_AMD] = "chroma_drift_windows_arm64",
        [bd.SystemArchitecture.LINUX_ARM] = "chroma_drift_linux_x64_64",
        [bd.SystemArchitecture.LINUX_AMD] = "chroma_drift_linux_arm64",
        [bd.SystemArchitecture.MAC_OS] = "mac_os"
    }
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
        false
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
function bd.compile(source_file_path, destination_file_path)
    meta.assert(source_file_path, "String", destination_file_path, "String")

    source_file_path = bd.normalize_path(source_file_path)
    destination_file_path = bd.normalize_path(destination_file_path)

    if not bd.file_exists(source_file_path) then
        rt.error("In bd.compile: object at `" .. source_file_path .. "` does not exist")
    end

    if not bd.is_file(source_file_path) then
        rt.error("In bd.compile: object at `" .. source_file_path .. "` is not a file")
    end

    local file_data, read_error_maybe = love.filesystem.read(source_file_path)
    if not file_data then
        rt.error("In bd.compile: unable to read file at `" .. source_file_path .. "`:" .. read_error_maybe)
    end

    -- load chunk
    local compiled_function, compile_error = _G.loadstring(file_data, "@" .. source_file_path)
    if compiled_function == nil then
        rt.error("In bd.compile: unable to apply loadstring to content of file at  `" .. source_file_path .. "`: " .. compile_error)
    end

    -- compile to bytecade
    local bytecode = string.dump(compiled_function)
    if bytecode == nil then
        rt.error("In bd.compile: failed to generate bytecode for `" .. source_file_path .. "`")
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
        rt.error("In bd.compile: unable to copy file from `" .. source_file_path .. "` to `" .. destination_file_path .. "`: " .. write_error_maybe)
    end
end

--- @brief copy a single file
function bd.copy_file(source_file_path, destination_file_path)
    meta.assert(source_file_path, "String", destination_file_path, "String")

    source_file_path = bd.normalize_path(source_file_path)
    destination_file_path = bd.normalize_path(destination_file_path)

    if not bd.file_exists(source_file_path) then
        rt.error("In bd.copy_file: file at `" .. source_file_path .. "` does not exist")
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
        rt.error("In bd.copy_file: unable to write file to `" .. destination_file_path .. "`: " .. write_error_maybe)
    end
end

--- @brief remove a single file
function bd.remove_file(file_path)
    meta.assert(file_path, "String")

    file_path = bd.normalize_path(file_path)

    if not bd.file_exists(file_path) then
        rt.error("In bd.remove_file: file at `" .. file_path .. "` does not exist")
    end

    if not bd.is_file(file_path) then
        rt.error("In bd.remove_file: object at `" .. file_path .. "` is not a file")
    end

    local remove_success = love.filesystem.remove(file_path)
    if not remove_success then
        rt.error("In bd.remove_file: unable to remove file at `" .. file_path .. "`")
    end
end

--- @brief recursively copy a directory and all its contents
function bd.copy_directory(source_directory_path, destination_directory_path)
    meta.assert(source_directory_path, "String", destination_directory_path, "String")

    source_directory_path = bd.normalize_path(source_directory_path)
    destination_directory_path = bd.normalize_path(destination_directory_path)

    if not bd.file_exists(source_directory_path) then
        rt.error("In bd.copy_directory: directory at `" .. source_directory_path .. "` does not exist")
    end

    if not bd.is_directory(source_directory_path) then
        rt.error("In bd.copy_directory: object at `" .. source_directory_path .. "` is not a directory")
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
        rt.error("In bd.remove_directory: directory at `" .. directory_path .. "` does not exist")
    end

    if not bd.is_directory(directory_path) then
        rt.error("In bd.remove_directory: object at `" .. directory_path .. "` is not a directory")
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
        rt.warning("In bd.remove_directory: unable to remove directory at `" .. directory_path .. "`")
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
        rt.error("In bd.copy: object at `" .. source_path .. "` is not a file or directory")
    end
end

--- @brief
function bd.remove(source_path, destination_path)
    meta.assert(source_path, "String", destination_path, "String")
    if bd.is_directory(source_path) then
        bd.remove_directory(source_path, destination_path)
    elseif bd.is_file(source_path) then
        bd.remove_file(source_path, destination_path)
    else
        rt.error("In bd.remove: object at `" .. source_path .. "` is not a file or directory")
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
        rt.error("In bd.move: object at `" .. source_path .. "` does not exist")
    end

    if bd.is_file(source_path) then
        bd.move_file(source_path, destination_path)
    elseif bd.is_directory(source_path) then
        bd.move_directory(source_path, destination_path)
    else
        rt.error("In bd.move: object at `" .. source_path .. "` is neither a file nor a directory")
    end
end

--- @brief downloads executables into build/executables
--- @param github_actions_run_id Number run id of love2d github actions repo
--- @param ... bd.SystemArchitecture
function bd._download_love_executables(github_actions_run_id, ...)
    local executable_prefix = bd.settings.executable_directory
    if bd.file_exists(executable_prefix) then
        local success = love.filesystem.remove(executable_prefix)
        if not success then
            rt.warning("In bd._download_love_executables: unable to remove folder at `" .. executable_prefix .. "`")
        end
    end

    bd.create_directory(executable_prefix)

    local https = require("https")

    for architecture in range(...) do
        local download_link

        local prefix = bd.settings.executable_download_link_prefix .. "/" .. github_actions_run_id
        local postfix = bd.settings.architecture_to_input_filename[architecture]
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
        return name ~= nil-- and name ~= "conf" -- exclude conf.lua
    end

    local _zip_pattern = "%.zip$"
    local _appimage_pattern = "%.[aA]pp[iI]mage$"
    local _squashfs_root_pattern = "squashfs-root"

    --- @brief
    function bd.build(rebuild_love_file)
        if rebuild_love_file == nil then rebuild_love_file = true end
        rt.log("starting build for operating system `" .. bd.get_operating_system() .. "`")

        local build_prefix = bd.settings.build_directory_mount_point

        -- create workspace directory
        local workspace_prefix = bd.settings.workspace_directory
        if not bd.file_exists(workspace_prefix) then
            bd.create_directory(workspace_prefix)
        end

        -- create output directory
        local output_prefix = bd.settings.output_directory
        if not bd.file_exists(output_prefix) then
            bd.create_directory(output_prefix)
        end

        rt.log("creating .love file")

        require "dependencies.zip.zip"
        local to_zip_path = bd.join_path(workspace_prefix, bd.settings.love_file_name)
        local love_file_path = to_zip_path .. bd.settings.love_file_name_extension

        if rebuild_love_file == true then

            bd.create_directory(bd.join_path(workspace_prefix, bd.settings.love_file_name))

            -- copy all modules into workspace
            for module_name in values(bd.settings.module_names) do
                rt.log("exporting `/" .. module_name .. "`")
                bd.apply_recursively(module_name, function(from_path)
                    -- check if filename has ~ prefix
                    if string.match(from_path, "[\\/](~[^\\/]*)$") == nil then
                        local destination_path = bd.join_path(to_zip_path, from_path)
                        if _is_lua_file(from_path) then
                            -- if lua, compile to bytecode
                            bd.compile(from_path, destination_path)
                        else
                            bd.copy(from_path, destination_path)
                        end
                    end
                end)
            end

            local main_lua_seen = false
            local conf_lua_seen = false

            -- copy headers
            for file in values(bd.settings.header_names) do
                rt.log("exporting `/" .. file .. "`")

                local destination_path = bd.join_path(to_zip_path, file)
                if file == "main.lua" then main_lua_seen = true end
                if file == "conf.lua" then conf_lua_seen = true end

                if _is_lua_file(file) then
                    bd.compile(file, destination_path)
                else
                    bd.copy(file, destination_path)
                end
            end

            if not main_lua_seen then
                rt.critical("In bd.build: no `main.lua` is present in top level folder")
            end

            if not conf_lua_seen then
                rt.critical("In bd.build: no `conf.lua` is present in top level folder")
            end

            -- copy dependencies
            for dependency_name in values(bd.settings.dependency_names) do
                local path = bd.join_path(bd.settings.dependency_directory, dependency_name)
                rt.log("exporting `/" .. path .. "`")

                bd.apply_recursively(path, function(file)
                    local to_path =  bd.join_path(to_zip_path, file)
                    bd.copy(file, to_path)
                end)
            end

            require "dependencies.zip.zip"

            -- zip into .love file
            zip.compress(to_zip_path, love_file_path)

            -- delete pre-zip folder
            bd.remove_directory(to_zip_path)
        end

        -- iterate executables
        local executable_directory = bd.settings.executable_directory
        local in_names = bd.settings.architecture_to_input_filename
        local out_names = bd.settings.architecture_to_output_filename

        if bd.get_operating_system() == bd.OperatingSystem.WINDOWS then
            for architecture in range(
                bd.SystemArchitecture.WINDOWS_ARM,
                bd.SystemArchitecture.WINDOWS_AMD
            ) do
                local in_name = in_names[architecture]
                local out_name = out_names[architecture]
                local out_path = bd.join_path(workspace_prefix, out_name)

                rt.log("building executable `" .. out_name .. "`")

                -- create output dir in workspace/<architecture>
                bd.create_directory(out_path)

                -- unzip executables/<outer>.zip into workspace/<outer>
                local to_unzip_from = bd.join_path(executable_directory, in_name)
                local to_unzip_to = bd.join_path(workspace_prefix, string.gsub(in_name, _zip_pattern, ""))

                zip.decompress(to_unzip_from, to_unzip_to)

                -- find inner zip dir
                for inner_filename in values(love.filesystem.getDirectoryItems(to_unzip_to)) do

                    -- unzip executables/<outer>/<inner>.zip into executables/<outer>/<inner>
                    if string.match(inner_filename, _zip_pattern) ~= nil then
                        local to_unzip_inner_from =  bd.join_path(to_unzip_to, inner_filename)
                        local to_unzip_inner_to = string.gsub(to_unzip_inner_from, _zip_pattern, "")

                        zip.decompress(to_unzip_inner_from, to_unzip_inner_to)

                        -- copy all files from executables/<outer>/<inner> into workspace/<architecture>
                        for inner_inner_filename in values(love.filesystem.getDirectoryItems(to_unzip_inner_to)) do
                            bd.copy(
                                bd.join_path(to_unzip_inner_to, inner_inner_filename),
                                out_path
                            )
                        end
                    end
                end

                -- cleanup executables/<outer>
                bd.remove_directory(to_unzip_to)

                -- delete love leftovers
                for file in range(
                    "changes.txt",
                    "readme.txt",
                    "game.ico",
                    "love.ico"
                ) do
                    local path = bd.join_path(out_path, file)
                    if bd.file_exists(path) then
                        bd.remove_file(path)
                    end
                end

                -- add new icon
                local favicon_name = bd.settings.favicon_name
                bd.copy(
                    bd.join_path(bd.settings.favicon_location, favicon_name),
                    bd.join_path(out_path, favicon_name)
                )

                -- rename license
                bd.move(
                    bd.join_path(out_path, "license.txt"),
                    bd.join_path(out_path, bd.settings.love_license_name)
                )

                -- add custom license
                bd.copy(
                    bd.join_path(bd.settings.license_location, bd.settings.license_name),
                    bd.join_path(out_path, bd.settings.license_name)
                )

                do -- append .love to executable and rename
                    local love_file_data = love.filesystem.read(love_file_path)
                    if love_file_data == nil then
                        rt.error("In bd.build: unable to read .love file at `" .. love_file_path .. "`")
                    end

                    for from_name_to_name in range(
                        { bd.settings.love_executable_name, bd.settings.executable_name },
                        { bd.settings.love_executable_c_name, bd.settings.executable_c_name}
                    ) do
                        local from_name, to_name = table.unpack(from_name_to_name)
                        local from_path = bd.join_path(out_path, from_name)
                        if not bd.file_exists(from_path) then
                            rt.error("In bd.build: expected executable `" .. from_name .. "`, but it was not found")
                        end

                        local to_path = bd.join_path(out_path, to_name) .. ".exe"

                        -- concatenate zip to end of executable
                        local executable_data = love.filesystem.read(from_path) .. love_file_data

                        -- write to new location
                        love.filesystem.write(to_path, executable_data)

                        -- delete old executable
                        bd.remove_file(from_path)
                    end
                end

                -- move to output folder
                bd.move_directory(
                    out_path,
                    bd.join_path(output_prefix, out_name)
                )

                rt.log("wrote `" .. out_name .. "` to `" .. output_prefix .. "`")
            end
        elseif bd.get_operating_system() == bd.OperatingSystem.LINUX then
            for architecture in range(
                bd.SystemArchitecture.LINUX_ARM,
                bd.SystemArchitecture.LINUX_AMD
            ) do
                local in_name = in_names[architecture]
                local out_name = out_names[architecture]
                local out_path = bd.join_path(workspace_prefix, out_name)

                rt.log("building executable `" .. out_name .. "`")

                -- unzip executables/<outer>.zip into workspace/<outer>
                local to_unzip_from = bd.join_path(executable_directory, in_name)
                local to_unzip_to = bd.join_path(workspace_prefix, string.gsub(in_name, _zip_pattern, ""))

                zip.decompress(to_unzip_from, to_unzip_to)

                -- find inner .appImage
                for inner_filename in values(love.filesystem.getDirectoryItems(to_unzip_to)) do
                    if string.match(inner_filename, _appimage_pattern) ~= nil then
                        local to_unsquash_from = bd.join_path(to_unzip_to, inner_filename)
                        local to_unsquash_from_absolute = bd.join_path(love.filesystem.getSource(), to_unsquash_from)

                        local extract_command = string.format('binwalk -e %s -quiet', to_unsquash_from_absolute)
                        local success = os.execute(extract_command)
                        if success ~= 0 then
                            rt.error("In bd.build: failed to unsquash app image at `" .. to_unsquash_from_absolute .. "`. Is this a linux machine? Is binwalk installed?")
                        end

                        -- extracts to _<love-name.appImage>.extracted
                        local extract_name = "_" .. inner_filename .. ".extracted"
                        if not bd.file_exists(bd.join_path(to_unzip_to, extract_name)) then
                            rt.error("In bd.build: failed to iterate results of binwalk, file `" .. extract_name .. "` does not exist")
                        end

                        -- locate squashfs-root
                        local moved = false
                        for inner_inner_filename in values(love.filesystem.getDirectoryItems(bd.join_path(to_unzip_to, extract_name))) do
                            if inner_inner_filename == _squashfs_root_pattern then
                                bd.copy_directory(
                                    bd.join_path(to_unzip_to, extract_name, inner_inner_filename),
                                    bd.join_path(output_prefix, out_name)
                                )
                                moved = true
                                break
                            end
                        end
                        break
                    end
                end

                bd.remove_directory(to_unzip_to)
            end
        elseif bd.get_operating_system() == bd.OperatingSystem.MAC_OS then
            rt.error("In bd.build: macOS build currently unimplemented")
        end

        -- remove workspace
        bd.remove_directory(workspace_prefix)

        rt.log("build done.")
    end
end

do -- mount build directory
    local build_prefix = bd.settings.build_directory_mount_point
    local source_prefix = bd.normalize_path(love.filesystem.getSource())
    local build_directory_path = bd.join_path(source_prefix, bd.settings.build_directory)
    bd.mount_path(build_directory_path, build_prefix)

    if not bd.file_exists(bd.settings.build_directory) then
        rt.error("In bd.build: `/build` does not exists")
    end
end