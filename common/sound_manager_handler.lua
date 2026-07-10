require "common.thread"
require "common.channel"
require "common.sound_effect"

--- @class rt.SoundManagerHandler
rt.SoundManagerHandler = meta.class("SoundManagerHandler")
meta.add_signals(rt.SoundManagerHandler, -- same as rt.SoundManager
    "sound_done" -- (rt.SoundManager, sound_id, handler_id)
)

local MessageType = {}
for id in range(
    "SHUTDOWN",
    "SHUTDOWN_RESPONSE",
    "ERROR",
    "NOTIFY_STATE",
    "SIGNAL_EMIT",
    "PREALLOCATE",
    "SET_PLAYER_POSITION",
    "SET_POSITION",
    "PLAY",
    "STOP",
    "SET_GLOBAL_VOLUME",
    "SET_VOLUME",
    "SET_PITCH",
    "SET_FILTER",
    "REMOVE_FILTER",
    "ADD_EFFECT",
    "REMOVE_EFFECT"
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

NOTIFY_STATE: worker -> main
    type : MessageType
    sound_id_to_active_handlers : Table<String, Table<Number>>

SIGNAL_EMIT: worker -> main
    type : MessageType
    signal : String
    args : Table<Any>

SET_PLAYER_POSITION: main -> worker
    type : MessageType
    position_x : Number
    position_y : Number

SET_POSITION: main -> worker
    type : MessageType
    handler_id : Number
    position_x : Number?
    position_y : Number?

PLAY: main -> worker
    type : MessageType
    id : String
    config : Table? -- pitch, position_x, position_y, should_loop

STOP: main -> worker
    type : MessageType
    handler_id : Number
    fade_out_duration : Number?

SET_GLOBAL_VOLUME: main -> worker
    type : MessageType
    value : Number

SET_VOLUME: main -> worker
    type : MessageType
    handler_id : Number
    volume : Number
    use_smoothing : Boolean

SET_PITCH: main -> worker
    type : MessageType
    handler_id : Number
    pitch : Number
    use_smoothing : Boolean

SET_FILTER: main -> worker
    type : MessageType
    handler_id : Number
    t : Number

REMOVE_FILTER: main -> worker
    type : MessageType
    handler_id : Number

ADD_EFFECT: main -> worker
    type : MessageType
    handler_id : Number
    native : Object -- native handle from rt.SoundEffect:get_native()

REMOVE_EFFECT: main -> worker
    type : MessageType
    handler_id : Number
    native : Object -- native handle from rt.SoundEffect:get_native()
]]

--- @brief
function rt.SoundManagerHandler:instantiate()
    self._sound_id_to_active_handlers = {}
    self._current_handler_id = 1

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
function rt.SoundManagerHandler:set_player_position(position_x, position_y)
    meta.assert(position_x, mt.Number, position_y, mt.Number)

    self._main_to_worker:push({
        type = MessageType.SET_PLAYER_POSITION,
        position_x = position_x,
        position_y = position_y
    })
end

--- @brief
function rt.SoundManagerHandler:set_position(handler_id, position_x, position_y)
    meta.assert(handler_id, mt.Number, position_x, mt.Optional(mt.Number), position_y, mt.Optional(mt.Number))

    self._main_to_worker:push({
        type = MessageType.SET_POSITION,
        handler_id = handler_id,
        position_x = position_x, -- can be nil
        position_y = position_y
    })
end

--- @brief
function rt.SoundManagerHandler:play(id, config)
    meta.assert(id, mt.String, config, mt.Optional(mt.Table))

    self._current_handler_id = self._current_handler_id + 1
    self._main_to_worker:push({
        type = MessageType.PLAY,
        id = id,
        handler_id = self._current_handler_id,
        config = config
    }) -- pitch, position_x, position_y, should_loop

    return self._current_handler_id
end

--- @brief
function rt.SoundManagerHandler:stop(handler_id, fade_out_duration)
    meta.assert(handler_id, mt.Number, fade_out_duration, mt.Optional(mt.Number))

    self._main_to_worker:push({
        type = MessageType.STOP,
        handler_id = handler_id,
        fade_out_duration = fade_out_duration
    })
end

--- @brief
function rt.SoundManagerHandler:set_global_volume(value)
    meta.assert(value, mt.Number)

    self._main_to_worker:push({
        type = MessageType.SET_GLOBAL_VOLUME,
        value = value
    })
end

--- @brief
function rt.SoundManagerHandler:set_volume(handler_id, volume, use_smoothing)
    if use_smoothing == nil then use_smoothing = true end
    meta.assert(handler_id, mt.Number, volume, mt.Number, use_smoothing, mt.Boolean)

    self._main_to_worker:push({
        type = MessageType.SET_VOLUME,
        handler_id = handler_id,
        volume = volume,
        use_smoothing = use_smoothing
    })
end

--- @brief
function rt.SoundManagerHandler:set_pitch(handler_id, pitch, use_smoothing)
    if use_smoothing == nil then use_smoothing = true end
    meta.assert(handler_id, mt.Number, pitch, mt.Number, use_smoothing, mt.Boolean)

    self._main_to_worker:push({
        type = MessageType.SET_PITCH,
        handler_id = handler_id,
        pitch = pitch,
        use_smoothing = use_smoothing
    })
end

--- @brief
function rt.SoundManagerHandler:set_filter(handler_id, t)
    meta.assert(handler_id, mt.Number, t, mt.Number)

    self._main_to_worker:push({
        type = MessageType.SET_FILTER,
        handler_id = handler_id,
        t = t
    })
end

--- @brief
function rt.SoundManagerHandler:remove_filter(handler_id)
    meta.assert(handler_id, mt.Number)

    self._main_to_worker:push({
        type = MessageType.REMOVE_FILTER,
        handler_id = handler_id
    })
end

--- @brief
function rt.SoundManagerHandler:add_effect(handler_id, effect)
    meta.assert(handler_id, mt.Number, effect, rt.SoundEffect)

    self._main_to_worker:push({
        type = MessageType.ADD_EFFECT,
        native = effect:get_native()
    })
end

--- @brief
function rt.SoundManagerHandler:remove_effect(handler_id, effect)
    meta.assert(handler_id, mt.Number, effect, rt.SoundEffect)

    self._main_to_worker:push({
        type = MessageType.REMOVE_EFFECT,
        native = effect:get_native()
    })
end

--- @brief
function rt.SoundManagerHandler:list_active_handler_ids(sound_id)
    meta.assert(sound_id, mt.String)

    local ids = self._sound_id_to_active_handlers[sound_id]
    return ids ~= nil and ids or {}
end

--- @brief
function rt.SoundManagerHandler:has_handler_id(handler_id)
    meta.assert(handler_id, mt.Number)

    for sound_id, ids in pairs(self._sound_id_to_active_handlers) do
        for other in values(ids) do
            if other == handler_id then
                return true
            end
        end
    end

    return false
end

--- @brief
function rt.SoundManagerHandler:update(_)
    while self._worker_to_main:get_n_messages() > 0 do
        local message = self._worker_to_main:pop()
        if message.type == MessageType.ERROR then
            if message.fatal == true then
                rt.fatal(message.error, message.traceback)
            else
                rt.critical(message.error, message.traceback)
            end
        elseif message.type == MessageType.NOTIFY_STATE then
            self._sound_id_to_active_handlers = message.sound_id_to_active_handlers
        elseif message.type == MessageType.SIGNAL_EMIT then
            self:signal_emit(message.signal, table.unpack(message.args))
        elseif message.type == MessageType.SHUTDOWN_RESPONSE then
            if message.success == false then
                rt.error(message.error, message.traceback)
            end
        else
            rt.error("In rt.SoundManagerHandler.update: unhandled message type `", message.type, "`")
        end
    end
end
