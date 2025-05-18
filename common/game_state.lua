require "overworld.stage_config"
require "common.random"
require "common.scene_manager"
require "common.player"

rt.settings.game_state = {
    save_file = "debug_save.lua",
    grade_double_s_threshold = 0.998,
    grade_s_threshold = 0.95,
    grade_a_threshold = 0.85,
}

rt.StageGrade = meta.enum("StageGrade", {
    DOUBLE_S = "SS",
    S = "S",
    A = "A",
    F = "F",
    NONE = "NONE",
})

--- @brief rt.GameState
rt.GameState = meta.class("GameState")

--- @brief
function rt.GameState:instantiate()
    self._stages = {}
    self._stage_id_to_best_time = {}
    self._stage_id_to_best_flow = {}

    local prefix = rt.settings.overworld.stage_config.config_path
    for file in values(love.filesystem.getDirectoryItems(prefix)) do
        local id = string.match(file, "^([^~].*)%.lua$") -- .lua not starting with +
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

            local config = config_or_error
            local title = config["title"]
            if title == nil then
                title = id
                rt.warning("In mn.StageSelectScene: stage at `" .. path .. "` does not have `title` property")
            end

            local difficulty = config["difficulty"]
            if difficulty == nil then
                difficulty = 0
                rt.warning("In mn.StageSelectScene: stage at `" .. path .. "` does not have `difficulty` property")
            end

            self._stages[id] = {
                id = id,
                path = path,
                title = title,
                difficulty = difficulty,
                was_beaten = true,
                best_time = rt.random.number(0, 1000), -- seconds
                best_flow_percentage = rt.random.number(0.99, 1) -- fraction
            }

            -- TODO: load from safe file
        end
    end

    self._player = rt.Player()
end

--- @brief
function rt.GameState:_get_stage(id, scope)
    local stage = self._stages[id]
    if stage == nil then
        rt.error("In rt.GameState." .. scope .. "`: no stage with id `" .. id .. "`")
    end
    return stage
end

--- @brie
function rt.GameState:save()
    -- TODO
end

--- @brief
function rt.GameState:get_stage_best_time(id)
    meta.assert(id, "String")
    local stage = self:_get_stage(id, "get_stage_best_time")
    return stage.best_time
end

--- @brief
function rt.GameState:set_stage_best_time(id, seconds)
    meta.assert(id, "String", seconds, "Number")
    local stage = self:_get_stage(id, "set_stage_best_time")
    stage.best_time = seconds
    self:save()
end

--- @brief
function rt.GameState:get_stage_best_flow_percentage(id)
    meta.assert(id, "String")
    local stage = self:_get_stage(id, "get_stage_best_flow_percentage")
    return stage.best_flow_percentage
end

--- @brief
function rt.GameState:set_stage_best_flow_percentage(id, fraction)
    meta.assert(id, "String", fraction, "Number")
    assert(fraction >= 0 and fraction <= 1, "In rt.GameState.set_stage_best_flow_percentage: fraction is not in [0, 1]")
    local stage = self:_get_stage(id, "set_stage_best_flow_percentage")
    stage.best_flow_percentage = fraction
    self:save()
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
function rt.GameState:get_stage_was_beaten(id)
    local stage = self:_get_stage(id, "get_stage_was_beaten")
    return stage.was_beaten
end

--- @brief
function rt.GameState:get_stage_grade(id)
    -- TODO time
    local stage = self:_get_stage(id, "get_stage_grade")
    if stage.was_beaten == false then
        return rt.StageGrade.NONE
    end

    local flow = stage.best_flow_percentage
    if flow >= rt.settings.game_state.grade_double_s_threshold then
        return rt.StageGrade.DOUBLE_S
    elseif flow >= rt.settings.game_state.grade_s_threshold then
        return rt.StageGrade.S
    elseif flow >= rt.settings.game_state.grade_a_threshold then
        return rt.StageGrade.A
    else
        return rt.StageGrade.F
    end
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

rt.GameState = rt.GameState()