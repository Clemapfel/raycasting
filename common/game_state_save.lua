local MessageType = {
    CREATE_SAVE = 0,
    CREATE_SAVE_SUCCESS = 1,
    LOAD_SAVE = 2,
    LOAD_SAVE_SUCCESS = 3,
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
end

--- @brief
function rt.GameState:save()
    self:_init_save_worker()
    _verify_state(self._state)

    local worker = self._save_worker
    self._save_worker.main_to_worker:push({
        type = MessageType.CREATE_SAVE,
        state = self._state
    })
end

function rt.GameState:load()
    self:_init_save_worker()

    local worker = self._save_worker
    self._save_worker.main_to_worker:push({
        type = MessageType.LOAD_SAVE
    })
end

--- @brief
function rt.GameState:_update_save_worker()
    local worker = self._save_worker
    while worker.worker_to_main:getCount() > 0 do
        local message = worker.worker_to_main:pop()
        if message.type == MessageType.CREATE_SAVE_SUCCESS then
            -- { type, path }
            rt.log("Successfully saved to `" .. message.path .. "`")
        elseif message.type == MessageType.LOAD_SAVE_SUCCESS then
            -- { type, path, state }
            rt.log("Succesfully loaded save from `" .. message.path .. "`")
            self._state = message.state
        elseif message.type == MessageType.ERROR then
            -- { type, reason }
            rt.warning("In rt.GameState:_update_save_worker: Thread error: " .. message.reason)
        end
    end
end
