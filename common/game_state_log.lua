local _get_prefix = function()
    return love.filesystem.getSaveDirectory()
end
--- @brief
function rt.GameState:_init_log_worker()
    self._current_log_file = "TODO.txt"
    local directory = rt.settings.scene_manager.log_directory_name

    require "build.build"
    if not bd.is_directory(directory) then
        bd.create_directory(directory)
    end

    if self._log_worker == nil then
        require "common.thread"
    end
end

--- @brief
function rt.GameState:get_log_file(absolute)
    require "build.build"
    if absolute == true then
        return bd.join_path(
            _get_prefix(),
            rt.settings.scene_manager.log_directory_name,
            self._current_log_file
        )
    else
        return bd.join_path(
            rt.settings.scene_manager.log_directory_name,
            self._current_log_file
        )
    end
end

--- @brief
function rt.GameState:get_log_file_directory(absolute)
    local directory = rt.settings.scene_manager.log_directory_name

    require "build.build"
    if absolute == true then
        return bd.join_path(_get_prefix(), directory)
    else
        return directory
    end
end