local MessageType = {
    CREATE_SAVE = 0,
    ERROR = 1,
    SUCCESS = 2
}

--- @brief
function rt.GameState:_initialize_save()
    if self._save_worker == nil then
        local worker = {
            thread = love.thread.newThread("common/game_state_save_worker.lua"),
            main_to_worker = love.thread.newChannel(),
            worker_to_main = love.thread.newChannel()
        }

        worker.thread:start(
            worker.main_to_worker,
            worker.worker_to_main,
            MessageType
        )

        self._save_worker = worker
    end

    self:save()
end

--- @brief
function rt.GameState:save()
    local worker = self._save_worker
    self._save_worker.main_to_worker:push({
        type = MessageType.CREATE_SAVE,
        state = self._state
    })
end


--- @brief
function rt.GameState:_update_save_worker()
    local worker = self._save_worker
    while worker.worker_to_main:getCount() > 0 do
        local message = worker.worker_to_main:pop()
        if message.type == MessageType.SUCCESS then
            -- { type, path }
            rt.log("Successfully saved to `" .. message.path .. "`")
        elseif message.type == MessageType.ERROR then
            -- { type, reason }
            rt.error("In rt.GameState:_update_save_worker: Thread error: " .. message.reason)
        end
    end
end
