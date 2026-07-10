require "common.sound_manager_instance"

rt.SoundManager = meta.as_singleton(rt.SoundManager)
assert(rt.SoundManager ~= nil)

local main_to_worker, worker_to_main, MessageType = ...

local message_type_to_handler = {
    [MessageType.SHUTDOWN] = function(message)
        rt.SoundManager:shutdown()
    end,

    [MessageType.SET_PLAYER_POSITION] = function(message)
        rt.SoundManager:set_player_position(
            message.position_x, message.position_y
        )
    end,

    [MessageType.SET_POSITION] = function(message)
        rt.SoundManager:set_position(message.handler_id,
            message.position_x, message.position_y
        )
    end,

    [MessageType.PLAY] = function(message)
        rt.SoundManager:play(
            message.id,
            message.config
        )
    end,

    [MessageType.STOP] = function(message)
        rt.SoundManager:stop(
            message.handler_id,
            message.fade_out_duration
        )
    end,

    [MessageType.SET_GLOBAL_VOLUME] = function(message)
        rt.SoundManager:set_global_volume(message.value)
    end,

    [MessageType.SET_VOLUME] = function(message)
        rt.SoundManager:set_volume(
            message.handler_id,
            message.volume,
            message.use_smoothing
        )
    end,

    [MessageType.SET_PITCH] = function(message)
        rt.SoundManager:set_pitch(
            message.handler_id,
            message.pitch,
            message.use_smoothing
        )
    end,

    [MessageType.SET_FILTER] = function(message)
        rt.SoundManager:set_filter(
            message.handler_id,
            message.t
        )
    end,

    [MessageType.REMOVE_FILTER] = function(message)
        rt.SoundManager:remove_filter(
            message.handler_id
        )
    end,

    [MessageType.ADD_EFFECT] = function(message)
        rt.SoundManager:add_effect_native(
            message.handler_id,
            message.native
        )
    end,

    [MessageType.REMOVE_EFFECT] = function(message)
        rt.SoundManager:remove_effect_native(
            message.handler_id,
            message.native
        )
    end
}

local success, error_maybe = pcall(function()
    -- register hook to bubble up non-fatal errors and log messages
    rt.Log.set_message_hook(function(message)
        worker_to_main:push({
            type = MessageType.ERROR,
            error = message,
            traceback = debug.traceback(),
            fatal = false
        })
    end)

    -- forward signals
    for signal in values(rt.SoundManager:signal_list_signals()) do
        rt.SoundManager:signal_connect(signal, function(_, ...)
            worker_to_main:push({
                type = MessageType.SIGNAL_EMIT,
                signal = signal,
                args = { ... }
            })
        end)
    end

    local shutdown_active = false

    local step = rt.settings.sound_manager.update_step
    local last_update = love.timer.getTime()

    local safe_call = function(f, ...)
        local res = { pcall(f, ...) }
        if res[1] == true then
            table.remove(res, 1)
            return table.unpack(res)
        else
            worker_to_main:push({
                type = MessageType.ERROR,
                error = res[2],
                traceback = debug.traceback(),
                fatal = false
            })
        end
    end

    while true do
        local message
        if shutdown_active then
            message = main_to_worker:pop()
            if message == nil then return end
        end

        while main_to_worker:getCount() > 0 do
            message = main_to_worker:pop() -- non-blocking check

            if message ~= nil then
                local handler = message_type_to_handler[message.type]

                if message.type == MessageType.SHUTDOWN then
                    shutdown_active = true
                elseif handler == nil then
                    worker_to_main:push({
                        type = MessageType.ERROR,
                        error = "Unhandled message type `" .. tostring(message.type) .. "`",
                        traceback = debug.traceback(),
                        fatal = false
                    })
                else
                    safe_call(handler, message)
                end
            end
        end

        -- update
        local delta = love.timer.getTime() - last_update
        safe_call(rt.SoundManager.update, rt.SoundManager, delta)
        local sound_id_to_active_handlers = safe_call(
            rt.SoundManager._get_state, rt.SoundManager
        )
        last_update = love.timer.getTime()

        worker_to_main:push({
            type = MessageType.NOTIFY_STATE,
            sound_id_to_active_handlers = sound_id_to_active_handlers
        })

        love.timer.sleep(step)
    end
end) -- pcall

if success == false then
    worker_to_main:push({
        type = MessageType.ERROR,
        error = error_maybe,
        traceback = debug.traceback(),
        fatal = true
    })
end

worker_to_main:push({
    type = MessageType.SHUTDOWN_RESPONSE,
    success = success,
    error = error_maybe,
    traceback = debug.traceback()
})