require "common.scene"
require "common.input_subscriber"
require "common.game_state"
require "common.translation"
require "overworld.stage_config"

rt.settings.menu.stage_select_scene = {
    max_difficulty = 5
}

--- @class mn.StageSelectScene
mn.StageSelectScene = meta.class("StageSelectScene", rt.Scene)

--[[
Stage Properties:
    Name
    Best Time Any%
    Best Time 100%
    coins total
]]--

local _filled_star = "\u{2605}"
local _outlined_star = "\u{2606}"
local _long_dash = "\u{2014}"

--- @brief
local function _create_difficulty_label(score)
    local n_filled = 0
    local out = {}
    for i = 1, rt.settings.menu.stage_select_scene.max_difficulty do
        if n_filled < score then
            table.insert(out, _filled_star)
            n_filled = n_filled + 1
        else
            table.insert(out, _outlined_star)
        end
    end

    return table.concat(out)
end

local function _create_flow_percentage_label(fraction)
    local percentage = math.floor(fraction * 1000) / 10
    if math.fmod(percentage, 1) == 0 then
        return percentage .. ".0%"
    else
        return percentage .. "%"
    end
end

local function _create_grade_label(grade)
    if grade == rt.StageGrade.DOUBLE_S then
        return "<wave><rainbow>SS</rainbow></wave>"
    elseif grade == rt.StageGrade.S then
        return "<color=YELLOW>S</color>"
    elseif grade == rt.StageGrade.A then
        return "<color=GREEN>A</color>"
    elseif grade == rt.StageGrade.F then
        return "<outline_color=WHITE><color=BLACK>F</color></outline_color>"
    elseif grade == rt.StageGrade.NONE then
        return _long_dash -- long dash
    end
end

--- @brief
function mn.StageSelectScene:instantiate()
    meta.install(self, {
        _elements = {},
    })

    local translation = rt.Translation.stage_select_scene
    local header_prefix, header_postfix = "<b>", "</b>"
    self._title_header_label = rt.Label(header_prefix .. translation.title_header .. header_postfix)
    self._difficulty_header_label = rt.Label(header_prefix .. translation.difficulty_header .. header_postfix)
    self._flow_header_label = rt.Label(header_prefix .. translation.flow_header .. header_postfix)
    self._time_header_label = rt.Label(header_prefix .. translation.time_header .. header_postfix)
    self._grade_header_label = rt.Label(header_prefix .. translation.grade_header .. header_postfix)

    local title_prefix, title_postfix = "", ""
    local difficulty_prefix, difficulty_postfix = "", ""
    local flow_prefix, flow_postfix = "", ""
    local time_prefix, time_postfix = "", ""
    local grade_prefix, grade_postfix = "<b><o>", "</b></o>"

    local grade_font, grade_font_mono = rt.settings.font.default_large, rt.settings.font.default_mono_large

    for id in values(rt.GameState:list_stage_ids()) do
        local was_beaten = rt.GameState:get_stage_was_beaten(id)

        local title = rt.GameState:get_stage_title(id)
        local difficulty = _create_difficulty_label(rt.GameState:get_stage_difficulty(id))
        local best_time = not was_beaten and _long_dash or string.format_time(rt.GameState:get_stage_best_time(id))
        local best_flow = not was_beaten and _long_dash or _create_flow_percentage_label(rt.GameState:get_stage_best_flow_percentage(id))
        local grade = not was_beaten and _long_dash or _create_grade_label(rt.GameState:get_stage_grade(id))

        table.insert(self._elements, {
            id = id,

            title_label = rt.Label(title_prefix .. title .. title_postfix),
            difficulty_label = rt.Label(difficulty_prefix .. difficulty .. difficulty_postfix),
            flow_label = rt.Label(flow_prefix .. best_flow .. flow_postfix),
            time_label = rt.Label(time_prefix .. best_time .. time_postfix),
            grade_label = rt.Label(grade_prefix .. grade .. grade_postfix, grade_font, grade_font_mono),

            x = 0,
            y = 0,
            width = 1,
            height = 1,
        })
    end

    self._input = rt.InputSubscriber()
end

--- @brief
function mn.StageSelectScene:realize()
    for element in values(self._elements) do
        for label in range(
            element.title_label,
            element.difficulty_label,
            element.flow_label,
            element.time_label,
            element.grade_label
        ) do
            label:realize()
        end
    end

    for label in range(
        self._title_header_label,
        self._difficulty_header_label,
        self._flow_header_label,
        self._time_header_label,
        self._grade_header_label
    ) do
        label:realize()
    end
end

--- @brief
function mn.StageSelectScene:size_allocate(x, y, width, height)
    local max_title_w, max_difficulty_w, max_flow_w, max_time_w, max_grade_w = -math.huge, -math.huge, -math.huge, -math.huge, -math.huge
    local max_h = -math.huge
    local n_elements = 0
    local sorted = {}
    for element in values(self._elements) do
        local title_w, title_h = element.title_label:measure()
        max_title_w = math.max(max_title_w, title_w)

        local difficulty_w, difficulty_h = element.difficulty_label:measure()
        max_difficulty_w = math.max(max_difficulty_w, difficulty_w)

        local flow_w, flow_h = element.flow_label:measure()
        max_flow_w = math.max(max_flow_w, flow_w)

        local time_w, time_h = element.time_label:measure()
        max_time_w = math.max(max_time_w, time_w)

        local grade_w, grade_h = element.grade_label:measure()
        max_grade_w = math.max(max_grade_w, grade_w)

        max_h = math.max(title_h, difficulty_h, flow_h, time_h) -- not grade_h
        n_elements = n_elements + 1

        table.insert(sorted, element)
    end

    local title_header_w, title_header_h = self._title_header_label:measure()
    local difficulty_header_w, difficulty_header_h = self._difficulty_header_label:measure()
    local flow_header_w, flow_header_h = self._flow_header_label:measure()
    local time_header_w, time_header_h = self._time_header_label:measure()
    local grade_header_w, grade_header_h = self._grade_header_label:measure()

    local max_header_h = math.max(max_h, title_header_h, difficulty_header_h, flow_header_h, time_header_h)
    max_title_w = math.max(max_title_w, title_header_w)
    max_difficulty_w = math.max(max_difficulty_w, difficulty_header_w)
    max_flow_w = math.max(max_flow_w, flow_header_w)
    max_time_w = math.max(max_time_w, time_header_w)
    max_grade_w = math.max(max_grade_w, grade_header_w)

    table.sort(sorted, function(a, b)
        return rt.GameState:get_stage_difficulty(a.id) < rt.GameState:get_stage_difficulty(b.id)
    end)

    local list_w = width
    local m = rt.settings.margin_unit
    local horizontal_padding = 2 * m
    local vertical_padding = 0.5 * m
    local total_w = max_title_w + max_difficulty_w + max_flow_w + max_time_w + max_grade_w
    local horizontal_margin = (list_w - total_w - 2 * horizontal_padding) / (5 - 1)

    self._list_x, self._list_y = 0, max_header_h + m
    local current_y = 0
    for element in values(sorted) do
        local current_x = 0

        element.x = current_x
        element.y = current_y

        current_x = current_x + horizontal_padding

        element.title_label:reformat(current_x, 0 + vertical_padding, math.huge)
        current_x = current_x + horizontal_margin + max_title_w

        element.difficulty_label:reformat(current_x, 0 + vertical_padding, math.huge)
        current_x = current_x + horizontal_margin + max_difficulty_w

        local time_w, time_h = element.time_label:measure()
        element.time_label:reformat(current_x + max_time_w - time_w, 0 + vertical_padding, math.huge)
        current_x = current_x + horizontal_margin + max_time_w

        local flow_w, flow_h = element.flow_label:measure()
        element.flow_label:reformat(current_x + max_flow_w - flow_w, 0 + vertical_padding, math.huge)
        current_x = current_x + horizontal_margin + max_flow_w

        local grade_w, grade_h = element.grade_label:measure()
        element.grade_label:reformat(
            current_x + 0.5 * max_grade_w - 0.5 * grade_w,
            0.5 * (max_h + 2 * vertical_padding) - 0.5 * grade_h,
            math.huge
        )
        current_x = current_x + horizontal_margin + max_grade_w

        current_x = current_x + horizontal_padding

        element.height = 2 * vertical_padding + max_h
        element.width = current_x - self._list_x

        current_y = current_y + element.height
    end

    do
        current_y = 0
        local current_x = 0
        current_x = current_x + horizontal_padding

        self._title_header_label:reformat(current_x, current_y + vertical_padding, math.huge)
        current_x = current_x + horizontal_margin + max_title_w

        self._difficulty_header_label:reformat(current_x, current_y + vertical_padding, math.huge)
        current_x = current_x + horizontal_margin + max_difficulty_w

        self._time_header_label:reformat(current_x, current_y + vertical_padding, math.huge)
        current_x = current_x + horizontal_margin + max_time_w

        self._flow_header_label:reformat(current_x, current_y + vertical_padding, math.huge)
        current_x = current_x + horizontal_margin + max_flow_w

        self._grade_header_label:reformat(current_x, current_y + vertical_padding, math.huge)
        current_x = current_x + horizontal_margin + max_grade_w

        current_x = current_x + horizontal_padding
    end
end

--- @brief
function mn.StageSelectScene:update(delta)
    for element in values(self._elements) do
        element.grade_label:update(delta)
    end
end

--- @brief
function mn.StageSelectScene:draw()
    local corner_radius = 1

    love.graphics.push()
    love.graphics.translate(self._list_x, self._list_y)
    for element in values(self._elements) do
        rt.Palette.BACKGROUND:bind()
        love.graphics.rectangle("fill", element.x, element.y, element.width, element.height, corner_radius)
        rt.Palette.BACKGROUND_OUTLINE:bind()
        love.graphics.rectangle("line", element.x, element.y, element.width, element.height, corner_radius)
    end

    for element in values(self._elements) do
        love.graphics.push()
        love.graphics.translate(element.x, element.y)

        for label in range(
            element.title_label,
            element.difficulty_label,
            element.flow_label,
            element.time_label,
            element.grade_label
        ) do
            label:draw()
        end

        love.graphics.pop()
    end
    love.graphics.pop()

    for label in range(
        self._title_header_label,
        self._difficulty_header_label,
        self._flow_header_label,
        self._time_header_label,
        self._grade_header_label
    ) do
        label:draw()
    end
end

--- @brief
function mn.StageSelectScene:enter()
    self._input:activate()
end

--- @brief
function mn.StageSelectScene:exit()
    self._input:deactivate()
end
