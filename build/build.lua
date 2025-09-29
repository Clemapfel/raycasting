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

love.filesystem.setSymlinksEnabled(true)

local executable_name = "chromadrift"

bd.settings = {
    build_directory = "build",
    build_directory_mount_point = "build",
    workspace_directory = "build/workspace",
    output_directory = "build/out",
    executable_directory = "build/executables",
    dependency_directory = "dependencies",

    love_file_name = executable_name,
    love_file_name_extension = ".love",

    love_executable_name = "love",
    love_executable_c_name = "lovec",

    executable_name = executable_name,
    executable_c_name = executable_name .. "debug",
    executable_comment = "Flow-Based Precision Platformer",

    favicon_location = "assets/favicon",
    favicon_name = "favicon",

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
        [bd.SystemArchitecture.LINUX_ARM] = "chroma_drift_linux_x86_64",
        [bd.SystemArchitecture.LINUX_AMD] = "chroma_drift_linux_arm64",
        [bd.SystemArchitecture.MAC_OS] = "chroma_drift_macos"
    }
}

require "common.filesystem"

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

        rt.log("building .love file")

        require "dependencies.zip.zip"
        local to_zip_path = bd.join_path(workspace_prefix, bd.settings.love_file_name)
        local love_file_path = bd.join_path(output_prefix, bd.settings.love_file_name) .. bd.settings.love_file_name_extension

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

        local love_file_data = love.filesystem.read(love_file_path)
        if love_file_data == nil then
            rt.error("In bd.build: unable to read .love file at `" .. love_file_path .. "`")
        else
            rt.log("wrote .love file to `" .. love_file_path .. "`")
        end

        local clear_workspace = function()
            if bd.get_operating_system() == bd.OperatingSystem.WINDOWS then
                bd.remove_directory(workspace_prefix)
            else
                os.execute(string.format("rm -r %s", bd.join_path(love.filesystem.getSource(), workspace_prefix)))
            end
        end

        clear_workspace()

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
                if bd.file_exists(out_path) then
                    bd.remove_directory(out_path)
                end
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

                -- add favicon as ico
                local favicon_name = bd.settings.favicon_name .. ".ico"
                bd.copy(
                    bd.join_path(bd.settings.favicon_location, favicon_name),
                    bd.join_path(out_path, bd.settings.executable_name .. ".ico")
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
                    for from_name_to_name in range(
                        { bd.settings.love_executable_name .. ".exe", bd.settings.executable_name },
                        { bd.settings.love_executable_c_name .. ".exe", bd.settings.executable_c_name}
                    ) do
                        local from_name, to_name = table.unpack(from_name_to_name)
                        local from_path = bd.join_path(out_path, from_name)
                        if not bd.file_exists(from_path) then
                            rt.error("In bd.build: expected executable `" .. from_name .. "`, but it was not found")
                        end

                        local to_path = bd.join_path(out_path, to_name) .. ".exe"

                        -- concatenate zip to end of executable
                        local executable_data = love.filesystem.read(from_path)

                        if executable_data == nil then
                            rt.error("In bd.build: unable to read executable at `" .. from_path)
                        end

                        executable_data = executable_data .. love_file_data

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

                if bd.file_exists(to_unzip_to) then
                    bd.remove_directory(to_unzip_to)
                end

                zip.decompress(to_unzip_from, to_unzip_to)

                local output_folder =  bd.join_path(output_prefix, out_name)
                if bd.file_exists(output_folder) then
                    bd.remove_directory(output_folder)
                end

                -- find inner .appImage
                for inner_filename in values(love.filesystem.getDirectoryItems(to_unzip_to)) do
                    if string.match(inner_filename, _appimage_pattern) ~= nil then
                        local to_unsquash_from = bd.join_path(to_unzip_to, inner_filename)
                        local to_unsquash_from_absolute = bd.join_path(love.filesystem.getSource(), to_unsquash_from)

                        local extract_command = string.format("binwalk -e %s -quiet", to_unsquash_from_absolute)
                        local success = os.execute(extract_command)
                        if success ~= 0 then
                            rt.error("In bd.build: failed to unsquash app image at `" .. to_unsquash_from_absolute .. "`. Is this a linux machine? Is binwalk installed?")
                        end

                        -- extracts to _<love-name.appImage>.extracted
                        local extract_name = "_" .. inner_filename .. ".extracted"
                        if not bd.file_exists(bd.join_path(to_unzip_to, extract_name)) then
                            rt.error("In bd.build: failed to iterate results of binwalk, file `" .. extract_name .. "` does not exist")
                        end

                        -- locate squashfs-root, move to /out
                        local moved = false
                        for inner_inner_filename in values(love.filesystem.getDirectoryItems(bd.join_path(to_unzip_to, extract_name))) do
                            if inner_inner_filename == _squashfs_root_pattern then
                                bd.copy_directory(
                                    bd.join_path(to_unzip_to, extract_name, inner_inner_filename),
                                    output_folder
                                )
                                moved = true
                                break
                            end
                        end
                        break
                    end
                end

                bd.remove_directory(to_unzip_to)

                -- append to executable
                local old_executable_path = bd.join_path(output_folder, "bin", "love")
                local executable_data = love.filesystem.read(old_executable_path)
                if executable_data == nil then
                    rt.error("In bd.build: unable to read executable at `" .. old_executable_path .. "`")
                end

                -- add .love to end of executable, then replace
                executable_data = executable_data .. love_file_data

                local new_executable_path = bd.join_path(output_folder, "bin", bd.settings.executable_name)
                love.filesystem.write(new_executable_path, executable_data)

                bd.remove_file(old_executable_path)

                -- remove old favicon
                bd.remove_file(bd.join_path(output_folder, "love.svg"))

                -- add favicon as svg
                local favicon_name = bd.settings.favicon_name .. ".svg"
                bd.copy(
                    bd.join_path(bd.settings.favicon_location, favicon_name),
                    bd.join_path(output_folder, bd.settings.executable_name .. ".svg") -- favicon needs to have same name as executable
                )

                -- rename license
                bd.move(
                    bd.join_path(output_folder, "license.txt"),
                    bd.join_path(output_folder, bd.settings.love_license_name)
                )

                -- add custom license
                bd.copy(
                    bd.join_path(bd.settings.license_location, bd.settings.license_name),
                    bd.join_path(output_folder, bd.settings.license_name)
                )

                -- modify AppRun
                local app_run_path = bd.join_path(output_folder, "AppRun")
                local app_run_data = love.filesystem.read(app_run_path)
                if app_run_data == nil then
                    rt.error("In bd.build: unable to read `AppRun` shell script at `" .. app_run_path .. "`")
                end

                do -- AppRun: replace /bin/love with /bin/<game>
                    local pattern = "/bin/" .. bd.settings.love_executable_name
                    local to_replace = "/bin/" .. bd.settings.executable_name

                    if not string.match(app_run_data, pattern) then
                        rt.error("In bd.build: pattern `" .. pattern .. "` not present in `" .. app_run_path .. "`")
                    end

                    app_run_data = string.gsub(app_run_data, pattern, to_replace)

                    -- strip .love comments
                    app_run_data = string.gsub(app_run_data, "# uncomment and edit to add your own game", "")
                    app_run_data = string.gsub(app_run_data, "FUSE_PATH=\"$APPDIR/my_game\"", "")

                    -- uncomment FUSE_PATH declaration
                    app_run_data = string.gsub(app_run_data, "#FUSE_PATH", "FUSE_PATH")

                    -- replace with <game>.love
                    app_run_data = string.gsub(app_run_data, "my_game", bd.settings.love_file_name)

                    if not love.filesystem.write(app_run_path, app_run_data) then
                        rt.error("In bd.build: unable to write file to `" .. app_run_path .. "`")
                    end
                end

                do -- .desktop
                    local old_desktop_file_path = bd.join_path(output_folder, "love.desktop")
                    local desktop_file_data = love.filesystem.read(old_desktop_file_path)

                    if desktop_file_data == nil then
                        rt.error("In bd.build: unable to read file at `" .. old_desktop_file_path .. "`")
                    end

                    -- replace name
                    desktop_file_data = string.gsub(desktop_file_data, "\nName=.-\n", "\nName=" .. bd.settings.executable_name .. "\n")

                    -- replace comment
                    desktop_file_data = string.gsub(desktop_file_data, "\nComment=.-\n", "\nComment=" .. bd.settings.executable_comment .. "\n")

                    -- replace Exec
                    desktop_file_data = string.gsub(desktop_file_data, "\nExec=.-\n", "\nExec=bin/" .. bd.settings.executable_name .. " %f\n")

                    -- replace mime type
                    desktop_file_data = string.gsub(desktop_file_data, "\nMimeType=.-\n", "\nMimeType=application/" .. bd.settings.executable_name .. "-game;\n")

                    -- also add favicon to icons folder
                    local mime_type_icon_prefix = bd.join_path(output_folder, "share", "icons", "hicolor", "scalable", "mimetypes")
                    bd.remove_file(bd.join_path(mime_type_icon_prefix, "application-x-love-game.svg"))
                    bd.copy(
                        bd.join_path(bd.settings.favicon_location, favicon_name),
                        bd.join_path(mime_type_icon_prefix, "application-" .. bd.settings.executable_name .. ".svg")
                    )

                    local new_desktop_file_path = bd.join_path(output_folder, bd.settings.executable_name .. ".desktop")
                    if not love.filesystem.write(new_desktop_file_path, desktop_file_data) then
                        rt.error("In bd.build: unable to write file to `" .. new_desktop_file_path .. "`")
                    end

                    bd.remove_file(old_desktop_file_path)

                    -- also replace .desktop in /share
                    local old_share_desktop_file_path = bd.join_path(output_folder, "share", "applications")
                    bd.remove_file(bd.join_path(old_share_desktop_file_path, "love.desktop"))

                    local new_share_desktop_file_path = bd.join_path(old_share_desktop_file_path, bd.settings.executable_name .. ".desktop")
                    if not love.filesystem.write(
                        new_share_desktop_file_path,
                        desktop_file_data
                    ) then
                        rt.error("In bd.build: unable to write file to `" .. new_share_desktop_file_path .. "`")
                    end
                end

                -- add .love to output
                bd.copy(love_file_path, bd.join_path(output_folder, bd.settings.love_file_name) .. bd.settings.love_file_name_extension)

                rt.log("wrote executable to `" .. output_folder .. "`")
            end
        elseif bd.get_operating_system() == bd.OperatingSystem.MAC_OS then
            rt.error("In bd.build: macOS build currently unimplemented")
        end

        clear_workspace()

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