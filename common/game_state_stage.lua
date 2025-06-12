require "common.stage_grade"
require "common.translation"

rt.settings.game_state.stage = {
    grade_flow_threshold = {
        [rt.StageGrade.SS] = 0.995,
        [rt.StageGrade.S] = 0.95,
        [rt.StageGrade.A] = 0.85,
        [rt.StageGrade.B] = 0.6,
        [rt.StageGrade.F] = 0
    },

    grade_time_threshold  = {
        [rt.StageGrade.SS] = 1,
        [rt.StageGrade.S] = 1.05,
        [rt.StageGrade.A] = 1.5,
        [rt.StageGrade.B] = 2,
        [rt.StageGrade.F] = math.huge
    },
}

--- @brief
function rt.GameState:_initialize_stage()
    -- non state stage data, cf. common/game_state for persistent data
    self._stages = {}
    self._stage_id_to_i = {}

    local path_prefix = rt.settings.overworld.stage_config.config_path

    local warn = function(i, name)
        rt.warning("In rt.Translation: stage entry `" .. i .. "` does not have `" .. name .. "` property")
    end

    for i, entry in pairs(rt.Translation.stages) do
        local id = entry.id
        if id == nil then
            rt.error("In rt.Translation: stage entry `" .. i .. "` does not have an id")
        end

        local title = entry.title
        if title == nil then
            warn(i, "title")
            title = id
        end

        local description = entry.description
        if description == nil then
            warn(i, "description")
            description = "(no description)"
        end

        local difficulty = entry.difficulty
        if difficulty == nil then
            warn(i, "difficulty")
            difficulty = 0
        end

        local target_time = entry.target_time
        if target_time == nil then
            warn(i, "target_time")
            target_time = math.huge
        end

        local stage = {
            id = id,
            path = path_prefix .. "/" .. id .. ".lua",
            title = title,
            difficulty = difficulty,
            description = description,
            target_time = target_time,
            index = i
        }

        self._stages[i] = stage
        self._stage_id_to_i[id] = i
    end
end

--- @brief
function rt.GameState:_get_stage(id, scope)
    local stage = self._stages[self._stage_id_to_i[id]]
    if stage == nil then
        rt.error("In rt.GameState." .. scope .. "`: no stage with id `" .. id .. "`")
    end
    return stage
end

--- @brief
function rt.GameState:get_stage_best_time(id)
    meta.assert(id, "String")
    local entry = self._state.stage_results[id]
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
function rt.GameState:get_stage_index(id)
    local stage = self:_get_stage(id, "get_stage_index")
    return stage.index
end

--- @brief
--- @return (rt.StageGrade, rt.StageGrade, rt.StageGrade) time, flow, total
function rt.GameState:get_stage_grades(id)
    local stage = self:_get_stage(id, "get_stage_grades")

    if stage.was_beaten == false then
        return rt.StageGrade.NONE, rt.StageGrade.NONE, rt.StageGrade.NONE
    end

    local time, flow = self:get_stage_best_time(id), self:get_stage_best_flow_percentage(id)
    if time == nil or flow == nil then
        return rt.StageGrade.NONE, rt.StageGrade.NONE, rt.StageGrade.NONE
    end

    local time_fraction = self:get_stage_target_time(id) / time
    local flow_fraction = flow

    local time_threshold = rt.settings.game_state.stage.time_tresholds
    local time_grade = rt.StageGrade.NONE
    for grade in range(
        rt.StageGrade.SS,
        rt.StageGrade.S,
        rt.StageGrade.A,
        rt.StageGrade.B,
        rt.StageGrade.F
    ) do
        if time_fraction > time_threshold[grade] then
            time_grade = grade
            break
        end
    end

    local flow_thresholds = rt.settings.game_state.stage.flow_thresholds
    local flow_grade = rt.StageGrade.NONE
    for grade in range(
        rt.StageGrade.SS,
        rt.StageGrade.S,
        rt.StageGrade.A,
        rt.StageGrade.B,
        rt.StageGrade.F
    ) do
        if flow_fraction < flow_thresholds[grade] then
            flow_grade = grade
            break
        end
    end

    -- max, but for SS both have to be
    local total_grade = math.min(flow_grade, time_grade)
    if total_grade == rt.StageGrade.SS and (flow_grade ~= rt.StageGrade.SS or time_grade ~= rt.StageGrade.SS) then
        total_grade = rt.StageGrade.S
    end

    return time_grade, flow_grade, total_grade
end

--- @brief
function rt.GameState:list_stage_ids()
    local out = {}
    for _, entry in ipairs(self._stages) do
        table.insert(out, entry.id)
    end
    return out
end