require "common.label"
require "menu.stage_grade_label"
require "overworld.coin_particle"

rt.settings.menu.stage_select_item = {
    coin_radius = 20
}

--- @class mn.StageSelectItem
mn.StageSelectItem = meta.class("StageSelectItem", rt.Widget)

local _long_dash = "\u{2014}"
local function _create_flow_percentage_label(fraction)
    local percentage = math.floor(fraction * 1000) / 10
    if math.fmod(percentage, 1) == 0 then
        return percentage .. ".0%"
    else
        return percentage .. "%"
    end
end

local _filled_star = "\u{2605}"
local _outlined_star = "\u{2606}"
local function _create_difficulty_label(score)
    local n_filled = 0
    local out = {}
    for i = 1, 5 do
        if n_filled < score then
            table.insert(out, _filled_star)
            n_filled = n_filled + 1
        else
            table.insert(out, _outlined_star)
        end
    end

    return table.concat(out)
end

local function _create_grade_label(grade)
    if grade == rt.StageGrade.DOUBLE_S then
        return "<wave><rainbow>SS</rainbow></wave>"
    elseif grade == rt.StageGrade.S then
        return "<color=GREEN>S</color>"
    elseif grade == rt.StageGrade.A then
        return "<color=YELLOW>A</color>"
    elseif grade == rt.StageGrade.B then
        return "<color=ORANGE>B</color>"
    elseif grade == rt.StageGrade.F then
        return "<outline_color=WHITE><color=BLACK>F</color></outline_color>"
    elseif grade == rt.StageGrade.NONE then
        return _long_dash -- long dash
    end
end

local _regular = rt.Font("assets/fonts/Baloo2/Baloo2-SemiBold.ttf")
local _bold = rt.Font("assets/fonts/Baloo2/Baloo2-Bold.ttf")
local _extra_bold = rt.Font("assets/fonts/Baloo2/Baloo2-ExtraBold.ttf")

--- @brief
function mn.StageSelectItem:instantiate(stage_id)
    meta.assert(stage_id, "String")
    self._id = stage_id
    
    local translation = rt.Translation.menu_scene.stage_select
    local title_prefix, title_postfix = "<b><u>", "</u></b>"
    local flow_prefix, flow_postfix = "", ""
    local time_prefix, time_postfix = "", ""
    local grade_prefix, grade_postfix = "<b><o>", "</b></o>"
    local difficulty_prefix, difficulty_postfix = "", ""
    local prefix_prefix, prefix_postfix = "", ""
    local description_prefix, description_postfix = "<color=GRAY>", "</color>"
    local header_prefix, header_postfix = "", ""
    local colon = "<color=GRAY>:</color>"

    local game_state, id = rt.GameState, self._id
    
    local title = game_state:get_stage_title(id)
    local was_beaten = game_state:get_stage_was_beaten(id)
    local n_coins = game_state:get_stage_n_coins(id)

    local time = not was_beaten and _long_dash or string.format_time(game_state:get_stage_best_time(id))
    local flow = not was_beaten and _long_dash or _create_flow_percentage_label(game_state:get_stage_best_flow_percentage(id))
    local grade = not was_beaten and _long_dash or _create_grade_label(game_state:get_stage_grade(id))
    local difficulty = _create_difficulty_label(game_state:get_stage_difficulty(id))
    local description = game_state:get_stage_description(id)
    local time_grade, flow_grade, total_grade = game_state:get_stage_grades(id)

    local function extra_bold(text) return rt.Label(text, rt.FontSize.BIG, _extra_bold) end
    local function bold(text) return rt.Label(text, rt.FontSize.REGULAR, _bold) end
    local function regular(text) return rt.Label(text, rt.FontSize.REGULAR, _regular) end

    meta.install(self, {
        _title_label = extra_bold(title_prefix .. title .. title_postfix),

        _flow_prefix_label = bold(prefix_prefix .. translation.flow_prefix .. prefix_postfix),
        _flow_colon_label = regular(colon),
        _flow_value_label = bold(flow_prefix .. flow .. flow_postfix),
        _flow_grade = mn.StageGradeLabel(flow_grade, rt.FontSize.BIG),

        _time_prefix_label = bold(prefix_prefix ..translation.time_prefix .. prefix_postfix),
        _time_colon_label = regular(colon),
        _time_value_label = bold(time_prefix .. time .. time_postfix),
        _time_grade = mn.StageGradeLabel(time_grade, rt.FontSize.BIG),

        _coins_prefix_label = bold(prefix_prefix .. translation.coins_prefix .. prefix_postfix),
        _coins_colon_label = regular(colon),
        _coins = {},

        _difficulty_prefix_label = rt.Label(prefix_prefix ..translation.difficulty_prefix .. prefix_postfix),
        _difficulty_colon_label = rt.Label(colon),
        _difficulty_value_label = rt.Label(difficulty_prefix .. difficulty .. difficulty_postfix),

        _description_label = rt.Label(description_prefix .. description .. description_postfix, rt.FontSize.SMALL),
        _total_grade = mn.StageGradeLabel(total_grade, rt.FontSize.HUGE),
    })


    for i = 1, n_coins do
        table.insert(self._coins, {
            coin = ow.CoinParticle(
                rt.settings.menu.stage_select_item.coin_radius,
                not rt.GameState:get_stage_was_coin_collected(id, i)
            ),
            x = 0,
            y = 0,
        })
    end
end

--- @brief
function mn.StageSelectItem:measure()
    local title_w, title_h = self._title_label:measure()
    return 250, 500
end

--- @brief
function mn.StageSelectItem:size_allocate(x, y, width, height)
    local title_w, title_h = self._title_label:measure()

    local max_prefix_w = -math.huge
    for prefix in range(
        self._flow_prefix_label,
        self._time_prefix_label,
        self._coins_prefix_label,
        self._difficulty_prefix_label
    ) do
        max_prefix_w = math.max(max_prefix_w, select(1, prefix:measure()))
    end

    self._title_label:set_justify_mode(rt.JustifyMode.CENTER)
    self._title_label:reformat(x, y, width, math.huge)

end

--- @brief
function mn.StageSelectItem:realize()
    local x, y = 100, 50
    for widget in range(
        self._title_label,
        self._flow_prefix_label,
        self._flow_colon_label,
        self._flow_value_label,
        self._flow_grade,
        self._time_prefix_label,
        self._time_colon_label,
        self._time_value_label,
        self._time_grade,
        self._coins_prefix_label,
        self._coins_colon_label,
        self._difficulty_prefix_label,
        self._difficulty_colon_label,
        self._difficulty_value_label,
        self._description_label,
        self._total_grade
    ) do
        widget:realize()
    end
end

--- @brief
function mn.StageSelectItem:draw()
    for to_draw in range(
        self._title_label,
        self._flow_prefix_label,
        self._flow_colon_label,
        self._flow_value_label,
        self._flow_grade,
        self._time_prefix_label,
        self._time_colon_label,
        self._time_value_label,
        self._time_grade,
        self._coins_prefix_label,
        self._coins_colon_label,
        self._difficulty_prefix_label,
        self._difficulty_colon_label,
        self._difficulty_value_label,
        self._description_label,
        self._total_grade
    ) do
        to_draw:draw()
    end

    for entry in values(self._coins) do
        entry.coin:draw(entry.x, entry.y)
    end
end

--- @brief
function mn.StageSelectItem:get_stage_id()
    return self._id
end

--- @brief
function mn.StageSelectItem:create_from_state()

    local time_grade, flow_grade, total_grade = rt.GameState:get_stage_grades(self._id)

    self._time_grade:set_grade(time_grade)
    self._flow_grade:set_grade(flow_grade)
    self._total_grade:set_grade(total_grade)

    for coin_i, entry in ipairs(self._coins) do
        local is_collected = rt.GameState:get_stage_was_coin_collected(self._id, coin_i)
        entry.coin:set_is_outline(is_collected)
    end
end