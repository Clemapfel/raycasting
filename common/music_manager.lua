--- @class rt.MusicManager
rt.MusicManager = meta.class("MusicManager")

local _messages = {}
for message_id in range(
    "instantiate",
    "play",
    "pause",
    "unpause",
    "stop",
    "set_volume"
) do
    _messages[message_id] = message_id
end

--- @brief
function rt.MusicManager:instantiate()
    self._thread = love.thread.newThread("common/music_manager_worker.lua")
    self._main_to_worker = love.thread.newChannel()
    self._worker_to_main = love.thread.newChannel()
    self._thread:start(
        self._main_to_worker,
        self._worker_to_main,
        _messages
    )

    self._main_to_worker:push({
        message_id = _messages.instantiate
    })

    self._volume = 1
    self:set_volume(rt.GameState:get_music_level())
end

--- @brief
function rt.MusicManager:play(id, restart)
    if restart == nil then restart = false end
    self._main_to_worker:push({
        message_id = _messages.play,
        id = id,
        restart = restart
    })
end

--- @brief
function rt.MusicManager:pause()
    self._main_to_worker:push({
        message_id = _messages.pause
    })
end

--- @brief
function rt.MusicManager:unpause()
    self._main_to_worker:push({
        message_id = _messages.unpause
    })
end

--- @brief
function rt.MusicManager:stop()
    self._main_to_worker:push({
        message_id = _messages.stop
    })
end

--- @brief
function rt.MusicManager:set_volume(v)
    v = math.clamp(v, 0, 1)
    self._volume = v
    self._main_to_worker:push({
        message_id = _messages.set_volume,
        value = v
    })
end

--- @brief
function rt.MusicManager:get_volume()
    return self._volume
end

rt.MusicManager = rt.MusicManager() -- singleton instance