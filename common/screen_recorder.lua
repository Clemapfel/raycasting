require "common.thread"

rt.settings.screen_recorder = {
    target_fps = 60
}

--- @class rt.ScreenRecorder
rt.ScreenRecorder = meta.class("ScreenRecorder")

local MessageType = {
    SHUTDOWNN = "SHUTDOWN",
    SHUTDOWN_RESPONSE = "SHUTDOWN_RESPONSE",
    IMAGE = "HANDLE_IMAGE",
    READBACK = "READBACK"
}

local _worker, _main_to_worker, _worker_to_main

--- @brief
function rt.ScreenRecorder:instantiate()
    self._is_active = false
    self._active_directory = nil
    self._current_frame_i = 0

    self._hdr_before = nil
    self._fixed_timestep_before = nil

    self._frame_queue = {}
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

    if self._texture == nil then self:_initialize(love.graphics.getDimensions()) end

    if self._is_active == true then
        self:stop_recording()
    end

    self._fixed_timestep_before = rt.SceneManager:get_use_fixed_timestep()
    self._vsync_before = rt.GameState:get_vsync_mode()

    rt.GameState:set_vsync_mode(rt.VSyncMode.OFF)
    rt.SceneManager:set_use_fixed_timestep(true)

    -- get temporal hash, has no meaning other than getting sub-second precision on filenames
    local hash_n_digits = 5
    local hash = tostring(math.floor(os.time() % 10^hash_n_digits))
    while hash_n_digits < 5 do
        hash_n_digits = "0" .. hash_n_digits
    end

    self._active_directory = "temp/" .. os.date("%Y_%m_%d_%H_%M_%S") .. "_" .. hash
    bd.create_directory(self._active_directory)

    self._frame_index = 0
    self._is_active = true

    rt.log("In rt.ScreenRecorder: starting recording at `", self._active_directory, "`")
end

--- @brief
function rt.ScreenRecorder:_get_filename()
    local index = self._frame_index
    local name = tostring(index)
    while #name < 6 do
        name = "0" .. name
    end

    return bd.join_path(self._active_directory, "_" .. name .. ".png")
end

--- @brief
function rt.ScreenRecorder:_initialize(width, height)
    self._texture = rt.RenderTexture(width, height, rt.TextureFormat.RGBA8)
end

--- @brief
function rt.ScreenRecorder:bind()
    if self._is_active ~= true then return end
    self._texture:bind()
end

--- @brief
function rt.ScreenRecorder:unbind()
    if self._is_active ~= true then return end
    self._texture:unbind()
end

--- @brief
function rt.ScreenRecorder:draw()
    if self._is_active ~= true then return end
    love.graphics.reset()
    love.graphics.setColor(1, 1, 1, 1)
    self._texture:draw()
end

--- @brief
function rt.ScreenRecorder:update(delta)
    if self._is_active ~= true then return end

    local screen_w, screen_h = love.graphics.getDimensions()
    if self._texture:get_width() ~= screen_w or self._texture:get_height() ~= screen_h then
        self:_initialize(screen_w, screen_h)
    end

    table.insert(self._frame_queue, love.graphics.readbackTextureAsync(self._texture:get_native()))

    while #self._frame_queue > 0 do
        local readback = self._frame_queue[1]
        readback:update()
        if readback:isComplete() then
            _main_to_worker:push({
                type = MessageType.HANDLE_IMAGE,
                data = readback:getImageData(),
                file_name = self:_get_filename()
            })
        elseif readback:hasError() then
            rt.error("In rt.ScreenRecorder.update: `readbackTextureAsync` errored")
        else
            break
        end

        -- error or complete
        table.remove(self._frame_queue, 1)
    end

    self._frame_index = self._frame_index + 1

    while _worker_to_main:get_n_messages() > 0 do
        local message = _worker_to_main:pop()
        if message.type == MessageType.SHUTDOWN_RESPONSE then
            if message.success ~= true then
                rt.error("In rt.ScreenRecorder: thread errored on shutdown: ", message.error)
            end
        else
            rt.error("In rt.ScreenRecorder: unhandled message type `", message.type, "`")
        end
    end
end

--- @brief
function rt.ScreenRecorder:get_is_recording()
    return self._is_active
end

--- @brief
function rt.ScreenRecorder:stop_recording()
    rt.SceneManager:set_use_fixed_timestep(self._fixed_timestep_before)
    rt.GameState:set_vsync_mode(self._vsync_before)
    self._is_active = false

    rt.log("In rt.ScreenRecorder: finished recording at `", self._active_directory, "`")
end