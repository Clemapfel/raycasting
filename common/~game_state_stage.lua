--- @class rt.StageGrade
rt.StageGrade = meta.enum("StageGrade", {
    S = 1,
    A = 2,
    B = 3,
    C = 4,
    F = 5,
    NONE = math.huge,
})

rt.settings.game_state.stage = {
    grade_flow_threshold = {
        [rt.StageGrade.S] = 0.995,
        [rt.StageGrade.A] = 0.95,
        [rt.StageGrade.B] = 0.85,
        [rt.StageGrade.C] = 0.6,
        [rt.StageGrade.F] = 0
    },

    grade_time_threshold  = {
        [rt.StageGrade.S] = 1,
        [rt.StageGrade.A] = 1.05,
        [rt.StageGrade.B] = 1.5,
        [rt.StageGrade.C] = 2,
        [rt.StageGrade.F] = math.huge
    },
}

--- @brief
function rt.GameState:_initialize_stage()
    -- non state stage data, cf. common/game_state for persistent data
    self._stages = {}
    self._stage_id_to_best_time = {}
    self._stage_id_to_best_flow = {}

    local prefix = rt.settings.overworld.stage_config.config_path
    for file in values(love.filesystem.getDirectoryItems(prefix)) do
        local id = string.match(file, "^([^~].*)%.lua$") -- .lua not starting with ~
        if id ~= nil then
            local path = prefix .. "/" .. id .. ".lua"
            local load_success, chunk_or_error, love_error = pcall(love.filesystem.load, path)
            if not load_success then
                rt.error("In mn.StageSelectScene: error when parsing file at `" .. path .. "`: " .. chunk_or_error)
                return
            end

            if love_error ~= nil then
                rt.error("In mn.StageSelectScene: error when loading file at `" .. path .. "`: " .. love_error)
                return
            end

            local chunk_success, config_or_error = pcall(chunk_or_error)
            if not chunk_success then
                rt.error("In mn.StageSelectScene: error when running file at `" .. path .. "`: " .. config_or_error)
                return
            end

            local _warning = function()  end -- TODO rt.warning

            local config = config_or_error
            local title = config["title"]
            if title == nil then
                title = id
                _warning("In mn.StageSelectScene: stage at `" .. path .. "` does not have `title` property")
            end

            local difficulty = config["difficulty"]
            if difficulty == nil then
                difficulty = 0
                _warning("In mn.StageSelectScene: stage at `" .. path .. "` does not have `difficulty` property")
            end

            local description = config["description"]
            if description == nil then
                description = "(no description)"
                _warning("In mn.StageSelectScene: stage at `" .. path .. "` does not have `description` property")
            end

            local target_time = config["target_time"]
            if target_time == nil then
                target_time = 0
                _warning("In mn.StageSelectScene: stage at `" .. path .. "` does not have `target_time` property")
            end

            self._stages[id] = {
                id = id,
                path = path,
                title = title,
                difficulty = difficulty,
                description = description,
                target_time = target_time
            }
        end
    end
end

--- @brief
function rt.GameState:_get_stage(id, scope)
    local stage = self._stages[id]
    if stage == nil then
        rt.error("In rt.GameState." .. scope .. "`: no stage with id `" .. id .. "`")
    end
    return stage
end

--- @brief
function rt.GameState:get_stage_best_time(id)
    meta.assert(id, "String")
    local entry = self._state.stages[id]
    if entry == nil or entry.best_time == nil then
        return nil
    else
        return entry.best_time
    end
end

--- @brief
function rt.GameState:set_stage_best_time(id, seconds)
    meta.assert(id, "String", seconds, "Number")
    local _ = self:_get_stage(id, "get_stage_best_time")

    if seconds < 0 then
        rt.error("In rt.GameState.set_stage_best_time: seconds are negative")
    end

    local entry = self._state.stage_results[id]
    if entry == nil then
        entry = {}
        self._state.stages[entry] = entry
    end
    entry.best_time = seconds
end

--- @brief
function rt.GameState:get_stage_best_flow_percentage(id)
    meta.assert(id, "String")
    local _ = self:_get_stage(id, "get_stage_best_flow_percentage")

    local entry = self._state.stage_results[id]
    if entry == nil or entry.best_flow_percentage == nil then
        return nil
    else
        return entry.best_flow_percentage
    end
end

--- @brief
function rt.GameState:set_stage_best_flow_percentage(id, fraction)
    meta.assert(id, "String", fraction, "Number")
    local _ = self:_get_stage(id, "set_stage_best_flow_percentage")

    if fraction < 0 or fraction > 1 then
        rt.error("In rt.GameState.set_stage_best_flow_percentage: fraction is not in [0, 1]")
    end

    local entry = self._state.stage_results[id]
    if entry == nil then
        entry = {}
        self._state.stage_results[entry] = entry
    end
    entry.best_flow_percentage = fraction
end


--- @brief
function rt.GameState:get_stage_was_beaten(id)
    meta.assert(id, "String")
    local _ = self:_get_stage(id, "get_stage_was_beaten")

    local entry = self._state.stage_results[id]
    if entry == nil or entry.was_beaten == nil then
        return false
    else
        return entry.was_beaten
    end
end

--- @brief
function rt.GameState:set_stage_was_beaten(id, b)
    meta.assert(id, "String")
    local _ = self:_get_stage(id, "set_stage_was_beaten")

    local entry = self._state.stage_results[id]
    if entry == nil then
        entry = {}
        self._state.stage_results[id] = entry
    end
    entry.was_beaten = b
end

--- @brief
function rt.GameState:get_stage_title(id)
    local stage = self:_get_stage(id, "get_stage_name")
    return stage.title
end

--- @brief
function rt.GameState:get_stage_difficulty(id)
    local stage = self:_get_stage(id, "get_stage_difficulty")
    return stage.difficulty
end

--- @brief
function rt.GameState:get_stage_target_time(id)
    local stage = self:_get_stage(id, "get_stage_target_time")
    return stage.target_time
end

--- @brief
function rt.GameState:get_stage_description(id)
    local stage = self:_get_stage(id, "get_stage_description")
    return stage.description
end

--- @brief
--- @return (rt.StageGrade, rt.StageGrade, rt.StageGrade) time, flow, total
function rt.GameState:get_stage_grades(id)
    local stage = self:_get_stage(id, "get_stage_grades")

    if stage.was_beaten == false then
        return rt.StageGrade.NONE
    end

    local time, flow = self:get_stage_best_time(id), self:get_stage_best_flow(id)
    if time == nil or flow == nil then
        return rt.StageGrade.NONE
    end

    local time_fraction = self:get_stage_target_time(id) / time
    local flow_fraction = flow

    local time_threshold = rt.settings.game_state.stage.time_tresholds
    local time_grade = rt.StageGrade.NONE
    for grade in range(
        rt.StageGrade.S,
        rt.StageGrade.A,
        rt.StageGrade.B,
        rt.StageGrade.C,
        rt.StageGrade.F
    ) do
        if time_grade > time_threshold[grade] then
            time_grade = grade
            break
        end
    end

    local flow_thresholds = rt.settings.game_state.stage.flow_thresholds
    local flow_grade = rt.StageGrade.NONE
    for grade in range(
        rt.StageGrade.S,
        rt.StageGrade.A,
        rt.StageGrade.B,
        rt.StageGrade.C,
        rt.StageGrade.F
    ) do
        if flow_grade < flow_thresholds[grade] then
            flow_grade = grade
            break
        end
    end

    -- max, but for SS both have to be
    local total_grade = math.min(flow_grade, time_grade)
    if total_grade == rt.StageGrade.S and (flow_grade ~= rt.StageGrade.S or time_grade ~= rt.StageGrade.S) then
        total_grade = rt.StageGrade.A
    end

    return time_grade, flow_grade, total_grade
end

--- @brief
function rt.GameState:list_stage_ids()
    local out = {}
    for id in keys(self._stages) do
        table.insert(out, id)
    end
    return out
end

--- @brief
function rt.GameState:get_player()
    return self._player
end
