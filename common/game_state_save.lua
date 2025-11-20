local MessageType = {
    CREATE_SAVE = 0,
    CREATE_SAVE_SUCCESS = 1,
    LOAD_SAVE = 2,
    LOAD_SAVE_SUCCESS = 3,
    SHUTDOWN = 4,
    ERROR = 5,
}

local function _verify_state(tbl)
    if type(tbl) ~= "table" then
        rt.error("In rt.GameState.save: state is not a serializable entity")
    end

    for key, value in pairs(tbl) do
        if type(key) == "function" or type(value) == "function" then
            return false
        end

        if type(value) == "table" then
            if not _verify_state(value) then
                return false
            end
        end
    end

    return true
end

function rt.GameState:_init_save_worker()
    if self._save_worker == nil then
        require "common.thread"
        local worker = {
            thread = rt.Thread("common/game_state_save_worker.lua"),
            main_to_worker = rt.Channel(),
            worker_to_main = rt.Channel()
        }

        worker.thread:signal_connect("shutdown", function(self)
            worker.main_to_worker:push({
                type = MessageType.SHUTDOWN
            })
        end)

        if not rt.ThreadManager:shutdown_active() then
            worker.thread:start(
                worker.main_to_worker:get_native(),
                worker.worker_to_main:get_native(),
                MessageType
            )
        end

        self._save_worker = worker
    end
end

--- @brief
function rt.GameState:save()
    self:_init_save_worker()
    _verify_state(self._state)

    local worker = self._save_worker

    if worker.thread:get_is_running() then
        self._save_worker.main_to_worker:push({
            type = MessageType.CREATE_SAVE,
            state = self._state
        })
    end
end

function rt.GameState:load()
    self:_init_save_worker()

    local worker = self._save_worker

    if worker.thread:get_is_running() then
        self._save_worker.main_to_worker:push({
            type = MessageType.LOAD_SAVE
        })
    end
end

--- @brief
function rt.GameState:_update_save_worker()
    self:_init_save_worker()
    local worker = self._save_worker
    while worker.thread:get_is_running() and worker.worker_to_main:get_n_messages() > 0 do
        local message = worker.worker_to_main:pop()
        if message.type == MessageType.CREATE_SAVE_SUCCESS then
            -- { type, path }
            rt.log("Successfully saved to `" .. message.path .. "`")
        elseif message.type == MessageType.LOAD_SAVE_SUCCESS then
            -- { type, path, state }
            rt.log("Successfully loaded save from `" .. message.path .. "`")

            for key, value in message.state do
                self._state[key] = value
            end
        elseif message.type == MessageType.ERROR then
            -- { type, reason }
            rt.error("In rt.GameState:_update_save_worker: Thread error: ", message.reason)
        end
    end
end
