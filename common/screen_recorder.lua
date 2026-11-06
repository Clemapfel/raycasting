require "common.thread"
require "common.routine"
require "common.linked_list"

rt.settings.screen_recorder = {
    frame_name_pattern = "_%06d",
    default_export_prefix = "screen_recordings"
}

--- @class rt.ScreenRecorder
rt.ScreenRecorder = meta.class("ScreenRecorder")

local MessageType = {}
for id in range(
    "ERROR", --[[
        worker -> main
        type : MessageType
        error : String
        traceback : String?
        fatal : Boolean
    ]]

    "SHUTDOWN", --[[
        main -> worker
        type : MessageType
    ]]

    "SHUTDOWN_RESPONSE", --[[
        worker -> main
        type : MessageType
        success : Boolean
        error : String?
        traceback : String?
    ]]

    "RECORDING_START", --[[
        main -> worker
        type : MessageType
        path : String
    ]]

    "RECORDING_END", --[[
        main -> worker
        type : MessageType
    ]]

    "FRAME" --[[
        main -> worker
        type : MessageType
        frame_index : Number
        data : love.ByteData | love.ImageData
        path : String
    ]]
) do
    MessageType[id] = id
end

--- @brief
function rt.ScreenRecorder:instantiate(use_ffmpeg)
    self._is_recording = false
    self._is_stopping = false
    self._pending_start = false
    self._pending_start_path = nil
    self._worker_is_shutdown = false
    self._use_ffmpeg = use_ffmpeg == true

    self._texture = nil -- rt.RenderTexture

    self._path = nil
    self._frame_index = 0
    self._next_frame_index_to_send = 0
    self._frame_has_been_queued = false
    self._readbacks = rt.LinkedList()

    if self._main_to_worker == nil then
        self._main_to_worker = rt.Channel()
    end

    if self._worker_to_main == nil then
        self._worker_to_main = rt.Channel()
    end

    if self._worker == nil then
        if rt.ThreadManager:get_is_shutdown_active() then
            self._worker_is_shutdown = true
            rt.critical("In rt.ScreenRecorder.instantiate: thread manager is shutting down")
            return
        end

        self._worker = rt.Thread("common/screen_recorder_worker.lua")
        self._worker:signal_connect("shutdown", function()
            self._main_to_worker:push({
                type = MessageType.SHUTDOWN
            })
        end)

        self._worker:start(
            self._main_to_worker:get_native(),
            self._worker_to_main:get_native(),
            MessageType
        )
    end
end

--- @brief
function rt.ScreenRecorder:start(path)
    if self._is_recording == true then
        self._pending_start = true
        self._pending_start_path = path
        self:stop()
        return
    elseif self._is_stopping == true then
        self._pending_start = true
        self._pending_start_path = path
        return
    end

    self:_start_recording(path)
end

--- @brief
function rt.ScreenRecorder:_start_recording(path)
    if self._worker == nil or self._worker_is_shutdown == true or rt.ThreadManager:get_is_shutdown_active() then
        rt.critical("In rt.ScreenRecorder.start: worker is not available")
        return
    end

    local prefix = path or rt.settings.screen_recorder.default_export_prefix
    if bd.is_file(prefix) then
        rt.error("In rt.ScreenRecorder.start: file object at `", prefix, "` is not a directory")
        return
    end

    if not bd.exists(prefix) then bd.create_directory(prefix) end
    self._path = bd.join_path(prefix, string.unique_timestamp())
    bd.create_directory(self._path)

    self:_init_texture()
    self._frame_index = 0
    self._next_frame_index_to_send = 0
    self._frame_has_been_queued = false
    self._readbacks:clear()
    self._is_stopping = false

    local w, h, mode = love.window.getMode()
    mode.vsync = 0 -- no vsync
    love.window.setMode(w, h, mode)
    rt.SceneManager:set_use_fixed_fps(true)
    rt.SceneManager:set_use_fixed_timestep(true)

    self._main_to_worker:push({
        type = MessageType.RECORDING_START,
        path = self._path
    })
    self._is_recording = true
end

--- @brief
function rt.ScreenRecorder:_init_texture()
    local w, h = rt.SceneManager:get_size()
    if self._texture == nil or self._texture:get_width() ~= w or self._texture:get_height() ~= h then
        self._texture = rt.RenderTexture(w, h, {
            format = rt.TextureFormat.RGBA8
        })
    end
end

--- @brief
function rt.ScreenRecorder:_queue_frame()
    self._frame_has_been_queued = true

    local frame_i = self._frame_index
    self._frame_index = self._frame_index + 1
    -- store index alongside readback so it can be unpacked in order later
    self._readbacks:push_back(
        love.graphics.readbackTextureAsync(self._texture:get_native()),
        frame_i
    )
end

--- @brief
function rt.ScreenRecorder:stop()
    if self._is_recording == false or self._is_stopping == true then return end

    if self._frame_has_been_queued ~= true then
        self:_queue_frame() -- push last readback
    end
    self._is_stopping = true
    self:notify_end_of_frame()
end

--- @brief
function rt.ScreenRecorder:bind()
    if self._texture == nil then self:_init_texture() end
    self._frame_has_been_queued = false
    self._texture:bind()
end

--- @brief
function rt.ScreenRecorder:unbind()
    if self._texture == nil then self:_init_texture() end
    self._texture:unbind()
end

--- @brief
function rt.ScreenRecorder:draw()
    if self._texture == nil then self:_init_texture() end
    love.graphics.setColor(1, 1, 1, 1)
    self._texture:draw()
end

--- @brief
function rt.ScreenRecorder:get_is_recording()
    return self._is_recording
end

--- @brief
function rt.ScreenRecorder:notify_end_of_frame(delta)
    if self._is_recording == true and self._is_stopping == false then
        self:_queue_frame()
    end

    -- work through worker responses
    while self._worker_to_main:get_n_messages() > 0 do
        local message = self._worker_to_main:pop()
        if message.type == MessageType.ERROR then
            if message.fatal == true then
                rt.fatal(message.error, message.traceback)
            else
                rt.critical(message.error, message.traceback)
            end
        elseif message.type == MessageType.SHUTDOWN_RESPONSE then
            self._worker_is_shutdown = true
        else
            rt.error("In rt.ScreenRecorder.notify_end_of_frame: unhandled message type `", message.type, "`")
        end
    end

    if self._is_recording == true then
        while true do
            local node = self._readbacks:get_front_node()
            if node == nil then break end

            local readback, frame_i = node:unpack()
            if readback:isComplete() ~= true then break end

            assert(readback:isComplete() == true, "is complete")
            assert(readback:getBufferData() ~= nil, "buffer still nil")

            self._readbacks:pop_front()

            self._main_to_worker:push({
                type = MessageType.FRAME,
                frame_index = frame_i,
                data = readback:getImageData(),
                use_ffmpeg = self._use_ffmpeg,
                path = bd.join_path(self._path, string.format(rt.settings.screen_recorder.frame_name_pattern, frame_i))
            })

            self._next_frame_index_to_send = frame_i + 1
        end

        if self._is_stopping == true and self._next_frame_index_to_send == self._frame_index then
            -- finish recording
            self._main_to_worker:push({
                type = MessageType.RECORDING_END
            })

            local w, h, mode = love.window.getMode()
            mode.vsync = rt.GameState:get_vsync_mode()
            love.window.setMode(w, h, mode)
            rt.SceneManager:set_use_fixed_fps(false)
            rt.SceneManager:set_use_fixed_timestep(true)

            self._is_recording = false
            self._is_stopping = false

            if self._frame_index == 0 then
                -- no frames pushed yet
                bd.remove_directory(self._path)
            end

            if self._pending_start == true then
                local path = self._pending_start_path
                self._pending_start = false
                self._pending_start_path = nil
                self:_start_recording(path)
            end
        end
    end
end

--- @brief
function rt.ScreenRecorder:notify_resize(width, height)
    if self._texture ~= nil then
        self:_init_texture()
    end

    if self._is_recording == true then
        rt.critical("In rt.ScreenRecorder: trying to resize screen mid-recording, the resulting video file may be corrupted")
    end
end