require "common.music_manager_instance"

rt.MusicManager = meta.as_singleton(rt.MusicManager)
assert(rt.MusicManager ~= nil)

local main_to_worker, worker_to_main, MessageType = ...

local message_type_to_handler = {
    [MessageType.PLAY] = function(message)
        rt.MusicManager:play(message.id, message.loop_id)
    end,

    [MessageType.STOP] = function(message)
        rt.MusicManager:stop(message.should_reset_playback)
    end,

    [MessageType.UNPAUSE] = function(message)
        rt.MusicManager:unpause()
    end,

    [MessageType.PAUSE] = function(message)
        rt.MusicManager:pause()
    end,

    [MessageType.ADD_EFFECT] = function(message)
        rt.MusicManager:add_effect(message.native)
    end,

    [MessageType.REMOVE_EFFECT] = function(message)
        rt.MusicManager:remove_effect(message.native)
    end,

    [MessageType.SET_FILTER] = function(message)
        rt.MusicManager:set_filter(message.t)
    end,

    [MessageType.REMOVE_FILTER] = function(message)
        rt.MusicManager:remove_filter()
    end,

    [MessageType.SET_PITCH] = function(message)
        rt.MusicManager:set_pitch(message.pitch)
    end,

    [MessageType.SET_VOLUME] = function(message)
        rt.MusicManager:set_volume(message.volume)
    end,

    [MessageType.RESET] = function(message)
        rt.MusicManager:reset()
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
    for signal in values(rt.MusicManager:signal_list_signals()) do
        rt.MusicManager:signal_connect(signal, function(_, ...)
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
        safe_call(rt.MusicManager.update, rt.MusicManager, delta)
        last_update = love.timer.getTime()
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