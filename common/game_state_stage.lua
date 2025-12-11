require "common.stage_grade"
require "common.translation"

rt.settings.game_state.stage = {
    grade_flow_thresholds = {
        [rt.StageGrade.S] = 0.995, -- precentage
        [rt.StageGrade.A] = 0.95,
        [rt.StageGrade.B] = 0.85,
        [rt.StageGrade.C] = 0.6,
        [rt.StageGrade.F] = 0
    },

    grade_time_thresholds  = {
        [rt.StageGrade.S] = 1, -- fraction of target time
        [rt.StageGrade.A] = 1.05,
        [rt.StageGrade.B] = 1.5,
        [rt.StageGrade.C] = 2,
        [rt.StageGrade.F] = 5
    },

    coin_thresholds = {
        [rt.StageGrade.S] = 0, -- fraction of missing coins
        [rt.StageGrade.A] = 1 - 0.9,
        [rt.StageGrade.B] = 1 - 0.6,
        [rt.StageGrade.C] = 1 - 0.5,
        [rt.StageGrade.F] = math.huge
    }
}

local _debug_output = false

local warn = function(i, name)
    rt.warning("In rt.Translation: stage entry `",  i,  "` does not have `",  name,  "` property")
end


--- @brief
function rt.GameState:_initialize_stage()
    if self._stage_initialized == true then return end

    -- non state stage data, cf. common/game_state for persistent data
    self._stages = {}
    self._stage_id_to_i = {}

    local path_prefix = rt.settings.overworld.stage_config.config_path

    for i, entry in pairs(rt.Translation.stages) do
        local id = entry.id
        if id == nil then
            rt.error("In rt.Translation: stage entry `",  i,  "` does not have an id")
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

        -- extract number of coins from config file
        local config = ow.StageConfig(id)
        local n_coins, n_checkpoints = 0, 0
        for layer_i = 1, config:get_n_layers() do
            for object in values(config:get_layer_object_wrappers(layer_i)) do
                if object.class == "Coin" then
                    n_coins = n_coins + 1
                elseif object.class == "Checkpoint" or object.class == "PlayerGoal" then
                    -- player spawn not counted
                    n_checkpoints = n_checkpoints + 1
                end
            end
        end

        local stage = {
            id = id,
            config = config,
            path = path_prefix .. "/" .. id .. ".lua",
            title = title,
            difficulty = difficulty,
            description = description,
            target_time = target_time,
            n_coins = n_coins,
            index = i,
            splits = {
                n_segments = n_checkpoints,
                best_segments = table.rep(0, n_checkpoints), -- best time for individual segments
                best_run = table.rep(0, n_checkpoints) -- overall splits of best run
            }
        }

        if _debug_output then
            local t = 0
            for segment_i = 1, n_checkpoints do
                t = t + rt.random.number(0, 10)
                stage.splits.best_segments[segment_i] = t
                stage.splits.best_run[segment_i] = t
            end
        end

        self._stages[i] = stage
        self._stage_id_to_i[id] = i
    end

    self._stage_initialized = true
end

--- @brief
function rt.GameState:_get_stage(id, scope)
    self:_initialize_stage()
    local stage = self._stages[self._stage_id_to_i[id]]
    if stage == nil then
        rt.error("In rt.GameState.", scope, "`: no stage with id `", id, "`")
    end
    return stage
end

--- @brief
function rt.GameState:reinitialize_stage(stage_id)
    local i = self._stage_id_to_i[stage_id]
    local stage_entry = self._stages[i]
    local entry = rt.Translation.stages[i]

    local id = entry.id
    if id == nil then
        rt.error("In rt.Translation: stage entry `",  i,  "` does not have an id")
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

    local config = ow.StageConfig(id)
    local n_coins, n_checkpoints = 0, 0
    for layer_i = 1, config:get_n_layers() do
        for object in values(config:get_layer_object_wrappers(layer_i)) do
            if object.class == "Coin" then
                n_coins = n_coins + 1
            elseif object.class == "Checkpoint" or object.class == "PlayerGoal" then
                n_checkpoints = n_checkpoints + 1
            end
        end
    end

    local stage = {
        id = id,
        config = config,
        path = stage_entry.path,
        title = title,
        difficulty = difficulty,
        description = description,
        target_time = target_time,
        n_coins = n_coins,
        index = i,
        splits = {
            n_segments = n_checkpoints,
            best_segments = table.rep(0, n_checkpoints), -- best time for individual segments
            best_run = table.rep(0, n_checkpoints) -- overall splits of best run
        }
    }

    self._stages[i] = stage

    if _debug_output then
        local t = 0
        for segment_i = 1, n_checkpoints do
            t = t + rt.random.number(0, 10)
            stage.splits.best_segments[segment_i] = t
            stage.splits.best_run[segment_i] = t
        end
    end
end

--- @brief
function rt.GameState:get_stage_exists(id)
    self:_initialize_stage()
    for entry in values(self._stages) do
        if entry.id == id then
            return true
        end
    end

    return false
end

--- @brief
function rt.GameState:get_stage_best_time(id)
    meta.assert(id, "String")
    if _debug_output then return rt.random.number(1, 100) end

    self:_initialize_stage()

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
    if _debug_output then return rt.random.number(0, 1) end
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
function rt.GameState:get_stage_is_coin_collected(stage_id, coin_i)
    meta.assert(stage_id, "String", coin_i, "Number")
    if _debug_output then return false end
    local stage = self:_get_stage(stage_id, "get_stage_is_coin_collected")
    if coin_i > stage.n_coins then
        rt.error("In rt.GameState.get_stage_is_coin_collected: coin index `", coin_i, "` is out of bounds, stage `", stage_id, "` only has ", stage.n_coins, " coins")
    end

    local entry = self._state.stage_results[stage_id]
    if entry == nil then return false end
    return entry.collected_coins[coin_i] == true
end

--- @brief
function rt.GameState:set_stage_is_coin_collected(stage_id, coin_i, collected)
    if collected == nil then collected = true end
    meta.assert(stage_id, "String", coin_i, "Number", collected, "Boolean")
    local stage = self:_get_stage(stage_id, "set_stage_is_coin_collected")
    if coin_i > stage.n_coins then
        rt.error("In rt.GameState.set_stage_is_coin_collected: coin index `", coin_i, "` is out of bounds, stage `", stage_id, "` only has ", stage.n_coins, " coins")
    end

    local entry = self._stage.stage_results[stage_id]
    if entry == nil then
        entry = {}
        self._state.stage_results[entry] = entry
    end

    if collected == true then
        entry.collected_coins[coin_i] = true
    else
        entry.collected_coins[coin_i] = nil
    end
end

--- @brief
function rt.GameState:get_stage_n_coins(id)
    meta.assert(id, "String")
    local stage = self:_get_stage(id, "set_stage_coin_collected")
    return stage.n_coins
end

--- @brief
function rt.GameState:get_stage_was_cleared(id)
    meta.assert(id, "String")
    if _debug_output then return true end
    local _ = self:_get_stage(id, "get_stage_was_cleared")

    local entry = self._state.stage_results[id]
    if entry == nil or entry.was_cleared == nil then
        return false
    else
        return entry.was_cleared
    end
end

--- @brief
function rt.GameState:set_stage_was_cleared(id, b)
    meta.assert(id, "String")
    if _debug_output then return true end
    local _ = self:_get_stage(id, "set_stage_was_cleared")

    local entry = self._state.stage_results[id]
    if entry == nil then
        entry = {}
        self._state.stage_results[id] = entry
    end
    entry.was_cleared = b
end

--- @brief
function rt.GameState:get_stage_is_hundred_percented(id)
    meta.assert(id, "String")
    if _debug_output then return true end
    local _ = self:_get_stage(id, "get_stage_is_hundred_percented")

    -- all coins collected
    for i = 1, self:get_stage_n_coins(id) do
        if self:get_stage_is_coin_collected(id, i) == false then return false end
    end

    local time_grade, flow_grade, coin_grade, total_grade = rt.GameState:get_stage_grades(id)
    return time_grade == rt.StageGrade.S
end

--- @brief
function rt.GameState:get_stage_name(id)
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

--- @brief Convert time to grade (faster time = better grade)
function rt.GameState:time_to_time_grade(time, target_time)
    meta.assert(time, "Number", target_time, "Number")
    local time_fraction = time / target_time  -- FIXED: was target_time / time
    local time_thresholds = rt.settings.game_state.stage.grade_time_thresholds

    for grade in range(
        rt.StageGrade.S,
        rt.StageGrade.A,
        rt.StageGrade.B,
        rt.StageGrade.C,
        rt.StageGrade.F
    ) do
        if time_fraction <= time_thresholds[grade] then  -- FIXED: was > now <=
            return grade
        end
    end

    return rt.StageGrade.F  -- FIXED: was NONE, should be F for worst case
end

--- @brief Convert flow percentage to grade (higher flow = better grade)
function rt.GameState:flow_to_flow_grade(flow)
    meta.assert(flow, "Number")
    local flow_thresholds = rt.settings.game_state.stage.grade_flow_thresholds

    for grade in range(
        rt.StageGrade.S,
        rt.StageGrade.A,
        rt.StageGrade.B,
        rt.StageGrade.C,
        rt.StageGrade.F
    ) do
        if flow >= flow_thresholds[grade] then  -- FIXED: was < now >=
            return grade
        end
    end

    return rt.StageGrade.F
end

--- @brief Convert coins collected to grade (fewer coins missing = better grade)
function rt.GameState:n_coins_to_coin_grade(n_coins, max_n_coins)
    meta.assert(n_coins, "Number", max_n_coins, "Number")
    local coin_thresholds = rt.settings.game_state.stage.coin_thresholds
    local n_coins_missing = max_n_coins - n_coins

    for grade in range(
        rt.StageGrade.S,
        rt.StageGrade.A,
        rt.StageGrade.B,
        rt.StageGrade.C,
        rt.StageGrade.F
    ) do
        if n_coins_missing <= math.floor(max_n_coins * coin_thresholds[grade]) then  -- FIXED: was >= now <=
            return grade
        end
    end

    return rt.StageGrade.NONE
end

--- @brief
--- @return (rt.StageGrade, rt.StageGrade, rt.StageGrade) time, flow, total
function rt.GameState:get_stage_grades(id)
    local stage = self:_get_stage(id, "get_stage_grades")

    if _debug_output then
        local grades = {
            rt.StageGrade.S,
            rt.StageGrade.A,
            rt.StageGrade.B,
            rt.StageGrade.C,
            rt.StageGrade.F
        }
        return rt.random.choose(grades), rt.random.choose(grades), rt.random.choose(grades), rt.random.choose(grades)
    end

    local time, flow = self:get_stage_best_time(id), self:get_stage_best_flow_percentage(id)
    if stage.was_cleared == false or time == nil or flow == nil then
        return rt.StageGrade.NONE, rt.StageGrade.NONE, rt.StageGrade.NONE, rt.StageGrade.F
    end

    local target_time = self:get_stage_target_time(id)
    local flow_fraction = flow

    local max_n_coins = self:get_stage_n_coins(id)
    local n_coins = 0
    for i = 1, max_n_coins do
        if self:get_stage_is_coin_collected(id, i) == true then
            n_coins = n_coins + 1
        end
    end

    local time_grade = self:time_to_time_grade(time, target_time)
    local flow_grade = self:flow_to_flow_grade(flow)
    local coin_grade = self:n_coins_to_coin_grade(n_coins, max_n_coins)

    -- max, but for SS both have to be
    local total_grade = math.min(flow_grade, time_grade)
    if total_grade == rt.StageGrade.S and (flow_grade ~= rt.StageGrade.S or time_grade ~= rt.StageGrade.S and coin_grade ~= rt.StageGrade.S) then
        total_grade = rt.StageGrade.A
    end

    if total_grade == rt.StageGrade.NONE then total_grade = rt.StageGrade.F end
    return time_grade, flow_grade, coin_grade, total_grade
end

--- @brief
function rt.GameState:list_stage_ids()
    self:_initialize_stage()
    
    local out = {}
    for _, entry in ipairs(self._stages) do
        table.insert(out, entry.id)
    end
    return out
end

--- @brief
function rt.GameState:get_n_stages()
    self:_initialize_stage()
    return table.sizeof(self._stages)
end

--- @brief
function rt.GameState:get_next_stage(stage_id)
    self:_initialize_stage()

    for i, entry in ipairs(self._stages) do
        if entry.id == stage_id then
            local next_stage = self._stages[i+1]
            if next_stage == nil then
                return nil
            else
                return next_stage.id
            end
        end
    end

    rt.error("In rt.GameState.get_next_stage: no stage with id `", stage_id, "`")
end

--- @brief
function rt.GameState:stage_update_splits(stage_id, times)
    meta.assert(stage_id, "String")
    for i = 1, #times do
        meta.assert_typeof(times[i], "Number", i+1)
    end

    self:_initialize_stage()
    local entry = self:_get_stage(stage_id, "stage_update_best_splits")

    local n_segments = entry.splits.n_segments
    if n_segments ~= #times then
        rt.error("In rt.GameState:stage_update_best_splits: for stage `", stage_id, "`, expected `", n_segments, "` segments, got `", #times)
    end

    local current_sum, new_sum = 0, 0
    for i = 1, n_segments do
        -- replace per-segment time with new best
        local current = entry.splits.best_segments[i]
        local next = times[i]
        if next <= current then
            entry.splits.best_segments[i] = current
        end

        current_sum = current_sum + current
        new_sum = new_sum + next
    end

    -- replace total run splits
    if new_sum < current_sum then
        for i = 1, n_segments do
            entry.splits.best_run[i] = times[i]
        end
    end
end

--- @brief
--- @return Table<Number>
function rt.GameState:stage_get_splits_best_segments(stage_id)
    self:_initialize_stage()

    meta.assert(stage_id, "String")
    local entry = self:_get_stage(stage_id, "stage_get_splits")

    if entry ~= nil then
        return table.deepcopy(entry.splits.best_segments)
    else
        return {}
    end
end

--- @brief
--- @return Table<Number>
function rt.GameState:stage_get_splits_best_run(stage_id)
    self:_initialize_stage()

    meta.assert(stage_id, "String")
    local entry = self:_get_stage(stage_id, "stage_get_splits")

    if entry ~= nil then
        return table.deepcopy(entry.splits.best_run)
    else
        return {}
    end
end

--- @brief
function rt.GameState:stage_get_config(stage_id)
    self:_initialize_stage()

    meta.assert(stage_id, "String")
    local entry = self:_get_stage(stage_id, "stage_get_config")

    if entry ~= nil then
        return entry.config
    else
        return nil
    end
end