--- @class rt.MusicManagerInterface
rt.MusicManagerInterface = meta.class("MusicManagerInterface")

local _success_postfix = "_success"
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
    _messages[message_id .. _success_postfix] = message_id .. _success_postfix
end

--- @brief
function rt.MusicManagerInterface:instantiate()
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
function rt.MusicManagerInterface:play(id, restart)
    self._main_to_worker:push({
        message_id = _messages.play,
        id = id,
        restart = restart
    })
end

--- @brief
function rt.MusicManagerInterface:pause()
    self._main_to_worker:push({
        message_id = _messages.pause
    })
end

--- @brief
function rt.MusicManagerInterface:unpause()
    self._main_to_worker:push({
        message_id = _messages.unpause
    })
end

--- @brief
function rt.MusicManagerInterface:stop()
    self._main_to_worker:push({
        message_id = _messages.stop
    })
end

--- @brief
function rt.MusicManagerInterface:set_volume(v)
    v = math.clamp(v, 0, 1)
    self._volume = v
    self._main_to_worker:push({
        message_id = _messages.set_volume,
        value = v
    })
end

--- @brief
function rt.MusicManagerInterface:get_volume()
    return self._volume
end