--- @class rt.StateMachine
rt.StateMachine = meta.class("StateMachine")
meta.add_signals(rt.StateMachine,
    "added",   -- (rt.StateMachine, id : ID) -> nil
    "removed", -- (rt.StateMachine, id : ID) -> nil
    "update",  -- (rt.StateMachine, id : ID, ... : Any) -> nil
    "enter",   -- (rt.StateMachine, current : ID, previous : ID, ... : Any) -> nil
    "exit"     -- (rt.StateMachine, current : ID, previous : ID, ... : Any) -> nil
)

local _valid_keys = {
    on_enter = mt.Function,  -- (next : ID, ...) -> nil
    on_exit = mt.Function,   -- (previous : ID, ...) -> nil
    on_update = mt.Function, -- (...) -> nil
    on_added = mt.Function,  -- () -> nil
    on_removed = mt.Function -- () -> nil
}

local function _get_entry(scope, self, id)
    local entry = self._states[id]
    if entry == nil then
        rt.error("In rt.StateMachine.", scope, ": no state with id `", id, "`, was add_state called?")
    end
    return entry
end

--- @brief
function rt.StateMachine:instantiate(id, config, ...)
    meta.assert(id, mt.Any, config, mt.Optional(mt.Table))
    self._states = {}
    self._current_state_id = id
    self:add_state(id, config, ...)

    -- initial state enter
    local entry = _get_entry("instantiate", self, self._current_state_id)
    if meta.is_function(entry.on_enter) then
        entry.on_enter()
        self:signal_emit("enter", self._current_state_id, nil)
    end
end

local _validate_config = function(scope, id, config)
    if config ~= nil then
        meta.assert_argument_type(config, mt.Table)
        for key in keys(config) do
            if _valid_keys[key] == nil then
                rt.error("In rt.StateMachine.", scope, ": for state `", id, "`, unknown config key `", key, "`")
            end
        end

        for key, value in pairs(config) do
            if not meta.isa(value, _valid_keys[key]) then
                rt.error("In rt.StateMachine.", scope, ": for state `", id, "`: config key `", key, "` is a `", meta.typeof(value), "`, expected `", _valid_keys[key], "`")
            end
        end
    end
end

--- @brief
function rt.StateMachine:add_state(...)
    local to_trigger = {}
    for i = 1, select("#", ...), 2 do
        local id = select(i + 0, ...)
        local config = select(i + 1, ...)

        meta.assert_argument_type(id, mt.Any, i)

        if self._states[id] ~= nil then
            rt.warning("In rt.StateMachine.add_state: trying to add state `", id, "`, but it already exists")
            -- overwrite anyway
        end

        local entry = { id = id }

        if config ~= nil then
            meta.assert_argument_type(config, mt.Table, i +1)
            _validate_config("add_state", id, config)
            for key, f in pairs(config) do
                entry[key] = f
            end
        end

        self._states[id] = entry
        table.insert(to_trigger, entry)
    end

    for _, entry in ipairs(to_trigger) do
        if meta.is_function(entry.on_added) then
            entry.on_added(entry.id)
        end

        self:signal_emit("added", entry.id)
    end

    return self
end
rt.StateMachine.add_states = rt.StateMachine.add_state

--- @brief
function rt.StateMachine:remove_state(...)
    local to_trigger = {}
    for i = 1, select("#", ...), 1 do
        local id =  select(i + 0, ...)
        meta.assert_argument_type(id, mt.Any, i)

        local entry = _get_entry("remove_state", self, id)
        if entry ~= nil then
            self._states[id] = nil
            table.insert(to_trigger, entry)
        end
    end

    for _, entry in ipairs(to_trigger) do
        if meta.is_function(entry.on_removed) then
            entry.on_removed(entry.id)
        end

        self:signal_emit("removed", entry.id)
    end

    return self
end
rt.StateMachine.remove_states = rt.StateMachine.remove_state

--- @brief
function rt.StateMachine:get_state()
    return self._current_state_id
end

--- @brief
function rt.StateMachine:set_state(next_id, ...)
    meta.assert(next_id, mt.Any)

    local previous_id = self._current_state_id
    local previous_state = _get_entry("set_state", self, previous_id)
    local next_state = _get_entry("set_state", self, next_id)

    if next_id == previous_id then return self end

    if previous_state.on_exit ~= nil then
        previous_state.on_exit(next_id, ...)
    end
    self:signal_emit("exit", self._current_state_id, previous_id, ...)

    self._current_state_id = next_id

    if next_state.on_enter ~= nil then
        next_state.on_enter(previous_id, ...)
    end
    self:signal_emit("enter", self._current_state_id, previous_id, ...)

    return self
end

--- @brief
function rt.StateMachine:update(...)
    local current = _get_entry("update", self, self._current_state_id)
    if meta.is_function(current.on_update) then
        current.on_update(...)
    end

    self:signal_emit("update", self._current_state_id, ...)
end

--- @brief
function rt.StateMachine:set_state_callbacks(id, config)
    meta.assert(id, mt.Any, config, mt.Optional(mt.Table))
    local entry = _get_entry("set_state_callbacks", self, id)
    if entry ~= nil then
        if config ~= nil then
            _validate_config("set_state_callbacks", id, config)
            for key, f in pairs(config) do
                entry[key] = f
            end
        else
            for key in keys(_valid_keys) do
                entry[key] = nil
            end
        end
    end
end

--- @brief
function rt.StateMachine:has_state(id)
    meta.assert(id, mt.Any)
    return self._states[id] ~= nil
end
