require "common.thread"
require "common.channel"
require "common.sound_effect"

--- @class rt.SoundManagerHandler
rt.MusicManagerHandler = meta.class("SoundManagerHandler")

local MessageType = {}
for id in range(
    "SHUTDOWN",
    "SHUTDOWN_RESPONSE",
    "ERROR",
    "SIGNAL_EMIT",
    "PLAY",
    "STOP",
    "UNPAUSE",
    "PAUSE",
    "ADD_EFFECT",
    "REMOVE_EFFECT",
    "SET_FILTER",
    "REMOVE_FILTER",
    "SET_PITCH",
    "RESET"
) do
    MessageType[id] = id
end

--[[
SHUTDOWN:  main -> worker
    type : MessageType

SHUTDOWN_RESPONSE: worker -> main
    type : MessageType
    success : Boolean
    error : String?
    traceback : String?

ERROR: worker -> main
    type : MessageType
    error : String
    fatal : Boolean

SIGNAL_EMIT: worker -> main
    type : MessageType
    signal : String
    args : Table<Any>

PLAY: main -> worker
    type : MessageType
    id : String?
    restart_if_active : Boolean?

STOP: main -> worker
    type : MessageType
    should_reset_playback : Boolean?

UNPAUSE: main -> worker
    type : MessageType

PAUSE: main -> worker
    type : MessageType

ADD_EFFECT: main -> worker
    type : MessageType
    native : String

REMOVE_EFFECT: main -> worker
    type : MessageType
    native : String

SET_FILTER: main -> worker
    type : MessageType
    t : Number

REMOVE_FILTER: main -> worker
    type : MessageType

SET_PITCH: main -> worker
    type : MessageType
    pitch : Number

SET_VOLUME: main -> worker
    type : MessageType
    volume : Number

RESET: main -> worker
    type : MessageType
]]

--- @brief
function rt.MusicManagerHandler:instantiate()
    self._worker = rt.Thread("common/sound_manager_worker.lua")
    self._main_to_worker = rt.Channel()
    self._worker_to_main = rt.Channel()

    self._worker:signal_connect("shutdown", function()
        self._main_to_worker:push({
            type = MessageType.SHUTDOWN
        })
    end)

    if not rt.ThreadManager:get_is_shutdown_active() then
        self._worker:start(
            self._main_to_worker:get_native(),
            self._worker_to_main:get_native(),
            MessageType
        )
    end
end

--- @brief
function rt.MusicManagerHandler:play(id, restart_if_active)
    meta.assert(id, mt.Optional(mt.String), restart_if_active, mt.Option(mt.String))

    self._main_to_worker:push({
        type = MessageType.PLAY,
        id = id,
        restart_if_active = restart_if_active
    })
end

--- @brief
function rt.MusicManagerHandler:stop(should_reset_playback)
    mt.assert(should_reset_playback, mt.Optional(mt.Boolean))

    self._main_to_worker:push({
        type = MessageType.STOP,
        should_reset_playback = should_reset_playback
    })
end

--- @brief
function rt.MusicManagerHandler:unpause()
    self._main_to_worker:push({
        type = MessageType.UNPAUSE
    })
end

--- @brief
function rt.MusicManagerHandler:pause()
    self._main_to_worker:push({
        type = MessageType.PAUSE
    })
end

--- @brief
function rt.MusicManagerHandler:add_effect(effect)
    meta.assert(effect, rt.SoundEffect)

    self._main_to_worker:push({
        type = MessageType.ADD_EFFECT,
        native = effect:get_native() -- String
    })
end

--- @brief
function rt.MusicManagerHandler:remove_effect(effect)
    meta.assert(effect, rt.SoundEffect)

    self._main_to_worker:push({
        type = MessageType.REMOVE_EFFECT,
        native = effect:get_native()
    })
end

--- @brief
function rt.MusicManagerHandler:set_filter(t)
    meta.assert(t, mt.Number)

    self._main_to_worker:push({
        type = MessageType.SET_FILTER,
        t = t
    })
end

--- @brief
function rt.MusicManagerHandler:set_pitch(pitch)
    meta.assert(pitch, mt.Number)

    self._main_to_worker:push({
        type = MessageType.SET_PITCH,
        pitch = pitch
    })
end

--- @brief
function rt.MusicManagerHandler:set_volume(volume)
    meta.assert(volume, mt.Number)

    self._main_to_worker:push({
        type = MessageType.SET_VOLUME,
        volume = volume
    })
end

--- @brief
function rt.MusicManagerHandler:reset()
    self._main_to_worker:push({
        type = MessageType.RESET
    })
end

--- @brief
function rt.MusicManagerHandler:update(_)
    while self._worker_to_main:get_n_messages() > 0 do
        local message = self._worker_to_main:pop()
        if message.type == MessageType.ERROR then
            if message.fatal == true then
                rt.fatal(message.error, message.traceback)
            else
                rt.critical(message.error, message.traceback)
            end
        elseif message.type == MessageType.SIGNAL_EMIT then
            self:signal_emit(message.signal, table.unpack(message.args))
        elseif message.type == MessageType.SHUTDOWN_RESPONSE then
            if message.success == false then
                rt.error(message.error, message.traceback)
            end
        else
            rt.error("In rt.MusicManagerHandler.update: unhandled message type `", message.type, "`")
        end
    end
end