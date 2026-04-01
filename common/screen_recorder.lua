require "common.thread"

rt.settings.screen_recorder = {
    target_fps = 60,
    frame_name_pattern = "_%06d.png",
    export_prefix = "temp"
}

--- @class rt.ScreenRecorder
rt.ScreenRecorder = meta.class("ScreenRecorder")

local MessageType = {
    ERROR = "ERROR",
    SHUTDOWN = "SHUTDOWN",
    SHUTDOWN_RESPONSE = "SHUTDOWN_RESPONSE",
    RECORDING_START = "RECORDING_START",
    RECORDING_START_RESPONSE = "RECORDING_START_RESPONSE",
    RECORDING_END = "RECORDING_END",
    RECORDING_END_RESPONSE = "RECORDING_END_RESPONSE",
    READBACK = "READBACK",
    READBACK_RESPONSE = "READBACK_RESPONSE",
    UPDATE = "UPDATE",
    EXPORT = "EXPORT",
    EXPORT_RESPONSE = "EXPORT_RESPONSE"
}

--[[
ERROR: worker -> main
    type  : MessageType
    id    : String
    error : String

SHUTDOWN: main -> worker
    type : MessageType

SHUTDOWN_RESPONSE: worker -> main
    type    : MessageType
    success : Boolean
    error   : String?

RECORDING_START: main -> worker
    type : MessageType
    id   : String

RECORDING_START_RESPONSE: worker -> main
    type : MessageType
    id   : String

RECORDING_END: main -> worker
    type : MessageType
    id   : String

RECORDING_END_RESPONSE: worker -> main
    type     : MessageType
    id       : String
    n_frames : Integer

READBACK: main -> worker
    type     : MessageType
    readback : love.GraphicsReadback
    filename : String
    id       : String

READBACK_RESPONSE: worker -> main
    type     : MessageType
    filename : String
    frame_i  : Integer

UPDATE: main -> worker
    type : MessageType
    id   : String

EXPORT: main -> worker
    type     : MessageType
    command  : String
    filename : String
    id       : String
    
EXPORT_RESPONSE: main -> worker
    type    : MessageType
    filename  : String
]]

local _worker, _main_to_worker, _worker_to_main

local STATE_RECORDING = "RECORDING"
local STATE_EXPORTING = "EXPORTING"
local STATE_IDLE = "IDLE"

--- @brief
function rt.ScreenRecorder:instantiate()
    self._state = STATE_IDLE
    self._active_recording_id = nil
    self._texture = nil -- rt.RenderTexture
    self._frame_index = 0
end

--- @brief
function rt.ScreenRecorder:start_recording()
    if _main_to_worker == nil then
        _main_to_worker = rt.Channel()
    end

    if _worker_to_main == nil then
        _worker_to_main = rt.Channel()
    end

    if _worker == nil then
        _worker = rt.Thread("common/screen_recorder_worker.lua")
        _worker:signal_connect("shutdown", function()
            _main_to_worker:push({
                type = MessageType.SHUTDOWN
            })
        end)

        if not rt.ThreadManager:get_is_shutdown_active() then
            _worker:start(
                _main_to_worker:get_native(),
                _worker_to_main:get_native(),
                MessageType
            )
        end
    end

    self:_try_initialize()

    if self._state ~= STATE_IDLE then
        rt.critical("In rt.ScreenRecorder.start_recording: a past recording is still active")
        return
    end

    self._fixed_timestep_before = rt.SceneManager:get_use_fixed_timestep()
    self._vsync_before = rt.GameState:get_vsync_mode()

    rt.SceneManager:set_use_fixed_fps(true, 60)

    -- get temporal hash, has no meaning other than getting sub-second precision on filenames
    local hash_n_digits = 5
    local hash = string.format("%05d", math.floor(os.time() % 10^hash_n_digits))

    self._active_recording_id = os.date("%Y_%m_%d_%H_%M_%S") .. "_" .. hash
    self._is_active = true
    self._frame_index = 0

    bd.create_directory(bd.join_path(bd.get_temp_directory_name(), self._active_recording_id))

    local export_folder = rt.settings.screen_recorder.export_prefix
    if bd.is_file(export_folder) then
        rt.error("In rt.ScreenRecorder: folder at `", bd.join_path(bd.get_save_directory(), export_folder), "` is not a directory")
    else
        bd.create_directory(export_folder)
    end

    _main_to_worker:push({
        type = MessageType.RECORDING_START,
        id = self._active_recording_id
    })
    rt.log("In rt.ScreenRecorder: starting recording at `", bd.join_path(bd.get_temp_directory(), self._active_recording_id) , "`")
    self._state = STATE_RECORDING
end

--- @brief
function rt.ScreenRecorder:stop_recording()
    if self._state ~= STATE_RECORDING then
        rt.critical("In rt.ScreenRecorder.stop_recording: no recording is currently active")
        return
    end

    _main_to_worker:push({
        type = MessageType.RECORDING_END,
        id = self._active_recording_id
    })

    rt.log("In rt.ScreenRecorder: stopping recording at `", bd.join_path(bd.get_temp_directory(), self._active_recording_id) , "`")
    self._state = STATE_EXPORTING
end

--- @brief
function rt.ScreenRecorder:_get_current_folder()
    return bd.join_path(bd.get_temp_directory_name(), self._active_recording_id)
end

--- @brief
function rt.ScreenRecorder:_get_frame_filename()
    local pattern = rt.settings.screen_recorder.frame_name_pattern
    local frame_name = string.format(pattern, self._frame_index)
    return bd.join_path(self:_get_current_folder(), frame_name)
end

--- @brief
function rt.ScreenRecorder:_get_video_filename()
    return bd.join_path(
        rt.settings.screen_recorder.export_prefix,
        self._active_recording_id .. ".mp4"
    )
end

--- @brief
function rt.ScreenRecorder:_try_initialize()
    local width, height = love.graphics.getDimensions()

    if self._texture == nil
        or self._texture:get_width() ~= width
        or self._texture:get_height() ~= height
    then
        self._texture = rt.RenderTexture(width, height, rt.TextureFormat.RGBA8)
    end
end

--- @brief
function rt.ScreenRecorder:bind()
    --f self._is_active ~= true then return end
    self:_try_initialize()
    self._texture:bind()
end

--- @brief
function rt.ScreenRecorder:unbind()
    --if self._is_active ~= true then return end
    self:_try_initialize()
    self._texture:unbind()
end

--- @brief
function rt.ScreenRecorder:draw()
    --if self._is_active ~= true then return end

    self:_try_initialize()
    love.graphics.setColor(1, 1, 1, 1)
    self._texture:draw()
end

--- @brief
function rt.ScreenRecorder:notify_end_of_frame(delta)
    if self._state == STATE_IDLE then
        return
    elseif self._state == STATE_RECORDING then
        _main_to_worker:push({
            type = MessageType.READBACK,
            readback = love.graphics.readbackTextureAsync(self._texture:get_native()),
            filename = self:_get_frame_filename(),
            id = self._active_recording_id
        })

        self._frame_index = self._frame_index + 1
    elseif self._state == STATE_EXPORTING then
        _main_to_worker:push({
            type = MessageType.UPDATE,
            id = self._active_recording_id
        })
    end

    while _worker_to_main:get_n_messages() > 0 do
        local message = _worker_to_main:pop()
        if message.type == MessageType.SHUTDOWN_RESPONSE then
            if message.success == false then
                rt.error("In rt.ScreenRecorder: thread error: ", message.error)
            end
        elseif message.type == MessageType.RECORDING_START_RESPONSE then
            -- noop
        elseif message.type == MessageType.READBACK_RESPONSE then
            rt.log("In rt.ScreenRecorder: wrote frame to `", message.filename, "`")
        elseif message.type == MessageType.RECORDING_END_RESPONSE then
            rt.SceneManager:set_use_fixed_fps(false) -- undo from start_recording

            local settings = rt.settings.screen_recorder
            local frame_filename = bd.join_path(bd.get_save_directory(), self:_get_current_folder(), "_%06d.png")
            local export_filename = bd.join_path(bd.get_save_directory(), self:_get_video_filename())

            _main_to_worker:push({
                type = MessageType.EXPORT,
                id = self._active_recording_id,
                filename = export_filename,
                command = string.format(
                    bd.join_path(bd.get_source_directory(), "love", "windows", "ffmpeg.exe") .. ' -framerate %d -i "%s" -vf "pad=ceil(iw/2)*2:ceil(ih/2)*2" -c:v libx264 -crf 18 -preset slow -pix_fmt yuv420p "%s"',
                    settings.target_fps,
                    frame_filename,
                    export_filename
                )
            })
        elseif message.type == MessageType.EXPORT_RESPONSE then
            rt.log("In rt.ScreenRecorder: successfully exported to `", message.filename, "`")
            self._state = STATE_IDLE
        elseif message.type == MessageType.ERROR then
            rt.error("In rt.ScreenRecorder: thread error: ", message.error)
        else
            rt.error("In rt.ScreenRecorder: unhandled message type `", message.type, "`")
        end
    end
end

--- @brief
function rt.ScreenRecorder:get_is_recording()
    return self._state ~= STATE_IDLE
end

rt.ScreenRecorder = rt.ScreenRecorder() -- singleton instance