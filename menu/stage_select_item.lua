require "common.label"
require "menu.stage_grade_label"
require "overworld.coin_particle"
require "overworld.objects.coin"

rt.settings.menu.stage_select_item = {
    coin_radius = 19,
    coins_max_n_per_row = 5,
}

--- @class mn.StageSelectItem
mn.StageSelectItem = meta.class("StageSelectItem", rt.Widget)

local _long_dash = "\u{2014}"
local function _create_flow_percentage_label(fraction)
    local percentage = math.floor(fraction * 1000) / 10
    if math.fmod(percentage, 1) == 0 then
        return percentage .. ".0 %"
    else
        return percentage .. " %"
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
    elseif grade == rt.StageGrade.A then
        return "<color=GREEN>S</color>"
    elseif grade == rt.StageGrade.B then
        return "<color=YELLOW>A</color>"
    elseif grade == rt.StageGrade.C then
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
    self._hrules = {}
    
    local translation = rt.Translation.stage_select_item
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
    local time_grade, flow_grade, coin_grade, total_grade = game_state:get_stage_grades(id)
    local time = not was_beaten and _long_dash or string.format_time(game_state:get_stage_best_time(id))
    local flow = not was_beaten and _long_dash or _create_flow_percentage_label(game_state:get_stage_best_flow_percentage(id))
    local difficulty = _create_difficulty_label(game_state:get_stage_difficulty(id))
    local description = game_state:get_stage_description(id)

    local function extra_bold(text) return rt.Label(text, rt.FontSize.BIG, _extra_bold) end
    local function bold(text) return rt.Label(text, rt.FontSize.REGULAR, _bold) end
    local function regular(text) return rt.Label(text, rt.FontSize.REGULAR, _regular) end
    local function small(text) return rt.Label(text, rt.FontSize.SMALL, _regular)  end

    meta.install(self, {
        _title_label = extra_bold(title_prefix .. title .. title_postfix),

        _flow_prefix_label = bold(prefix_prefix .. translation.flow_prefix .. prefix_postfix),
        _flow_colon_label = regular(colon),
        _flow_value_label = regular(flow_prefix .. flow .. flow_postfix),

        _flow_grade_prefix = bold(prefix_prefix .. translation.flow_grade_prefix .. prefix_postfix),
        _flow_grade_colon = regular(colon),
        _flow_grade = mn.StageGradeLabel(flow_grade, rt.FontSize.BIG),

        _time_prefix_label = bold(prefix_prefix ..translation.time_prefix .. prefix_postfix),
        _time_colon_label = regular(colon),
        _time_value_label = regular(time_prefix .. time .. time_postfix),

        _time_grade_prefix = bold(prefix_postfix .. translation.time_grade_prefix .. prefix_postfix),
        _time_grade_colon = regular(colon),
        _time_grade = mn.StageGradeLabel(time_grade, rt.FontSize.BIG),

        _coins = {},

        _coins_grade_prefix = bold(prefix_prefix .. translation.coins_grade_prefix .. prefix_postfix),
        _coins_grade_colon = regular(colon),
        _coins_grade = mn.StageGradeLabel(coin_grade, rt.FontSize.BIG),

        _difficulty_prefix_label = rt.Label(prefix_prefix ..translation.difficulty_prefix .. prefix_postfix),
        _difficulty_colon_label = rt.Label(colon),
        _difficulty_value_label = rt.Label(difficulty_prefix .. difficulty .. difficulty_postfix),

        _description_label = rt.Label(description_prefix .. description .. description_postfix, rt.FontSize.SMALL),
        _total_grade_prefix = regular(prefix_prefix .. translation.total_grade_prefix .. "<color=GRAY> <b>:</b></color>" .. prefix_postfix),
        _total_grade = mn.StageGradeLabel(total_grade, rt.FontSize.HUGE),
    })

    self:_init_coins()
    self._last_window_height = love.graphics.getHeight()
end

function mn.StageSelectItem:_init_coins()
    local n_coins = rt.GameState:get_stage_n_coins(self._id)

    for i = 1, n_coins do
        local coin = ow.CoinParticle(
            rt.settings.menu.stage_select_item.coin_radius * rt.get_pixel_scale(),
            not rt.GameState:get_stage_was_coin_collected(self._id, i)
        )
        coin:set_hue(ow.Coin.index_to_hue(i, n_coins))

        self._coins[i] = {
            coin = coin,
            x = 0,
            y = 0,
        }
    end
end

local _coin_xm = rt.settings.margin_unit

--- @brief
function mn.StageSelectItem:measure()
    if self._final_height ~= nil then
        return self._final_width, self._final_height
    else
        local outer_margin = 2 * rt.settings.margin_unit
        local coin_r = rt.settings.menu.stage_select_item.coin_radius * rt.get_pixel_scale()
        local n_coins = rt.settings.menu.stage_select_item.coins_max_n_per_row
        local coin_m = _coin_xm

        return 2 * coin_r * n_coins + coin_m * (n_coins - 1), 100
    end
end

--- @brief
function mn.StageSelectItem:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit

    if self._last_window_height ~= love.graphics.getHeight() then
        self:_init_coins()
        self._last_window_height = love.graphics.getHeight()
    end

    local outer_margin = 2 * m
    local v_margin = 4 * m
    local current_x, current_y = x + outer_margin, y + outer_margin
    self._hrules = {}
    local hrule_h = 2 * rt.get_pixel_scale()

    local title_w, title_h = self._title_label:measure()
    self._title_label:set_justify_mode(rt.JustifyMode.CENTER)
    self._title_label:reformat(x, current_y, width, math.huge)
    current_y = current_y + title_h + outer_margin

    local coin_left_x, coin_right_x, coin_height
    do -- coins local alignment
        local coin_r = rt.settings.menu.stage_select_item.coin_radius
        local n_coins_per_row = math.min(
            rt.settings.menu.stage_select_item.coins_max_n_per_row,
            math.floor((width - 4 * m) / (2 * coin_r))
        )

        local coin_xm = _coin_xm
        local coin_ym = 0
        local coin_row_w = n_coins_per_row * coin_r + (coin_xm * (n_coins_per_row - 1))

        local coin_start_x = 0
        local coin_x, coin_y = coin_start_x, 0
        local n_in_row = 0
        local row_to_row_w = {}
        local current_row_w = 0
        local current_row = {}
        for i, coin in ipairs(self._coins) do
            coin.x, coin.y = coin_x, coin_y
            coin_x = coin_x + 2 * coin_r + coin_xm

            table.insert(current_row, coin)
            n_in_row = n_in_row + 1
            current_row_w = current_row_w + 2 * coin_r + coin_xm

            if n_in_row >= n_coins_per_row or i == #self._coins then
                row_to_row_w[current_row] = current_row_w

                current_row = {}
                current_row_w = 0
                n_in_row = 0
                coin_x = coin_start_x
                coin_y = coin_y + 2 * coin_r + coin_ym
            end
        end

        -- center
        coin_left_x, coin_right_x = math.huge, -math.huge
        local n_rows = 0
        for row, row_w in pairs(row_to_row_w) do
            local offset = x + 0.5 * width - 0.5 * row_w + coin_r
            for coin in values(row) do
                coin.x = coin.x + offset
                coin_left_x = math.min(coin_left_x, coin.x)
                coin_right_x = math.max(coin_right_x, coin.x)
            end
            n_rows = n_rows + 1
        end

        coin_left_x = coin_left_x - coin_r
        coin_right_x = coin_right_x + coin_r
        coin_height = n_rows * 2 * coin_r + (n_rows - 1) * coin_ym
    end

    -- value labels
    local left_x, right_x = coin_left_x, coin_right_x
    for prefix_colon_value in range(
        { self._time_prefix_label, self._time_colon_label, self._time_value_label },
        { self._flow_prefix_label, self._flow_colon_label, self._flow_value_label }
    ) do
        local prefix, colon, value, grade = table.unpack(prefix_colon_value)

        for label in range(prefix, colon, value) do
            label:set_justify_mode(rt.JustifyMode.LEFT)
        end

        local prefix_w, prefix_h = prefix:measure()
        local colon_w, colon_h = colon:measure()
        local value_w, value_h = value:measure()

        local max_h = math.max(prefix_h, colon_h, value_h)

        prefix:reformat(
            left_x,
            current_y + 0.5 * max_h - 0.5 * prefix_h,
            math.huge, math.huge
        )

        value:reformat(
            right_x - value_w,
            current_y + 0.5 * max_h - 0.5 * value_h,
            math.huge, math.huge
        )

        colon:reformat(
            left_x + 0.5 * (right_x - left_x) - 0.5 * colon_w,
            current_y + 0.5 * max_h - 0.5 * colon_h,
            math.huge, math.huge
        )

        current_y = current_y + max_h
    end

    current_y = current_y + v_margin

    -- coins y-alignment
    for coin in values(self._coins) do
        coin.y = coin.y + current_y
    end

    current_y = current_y + coin_height

    local hrule_x = left_x - m
    local hrule_width = (right_x - left_x) + 2 * m
    table.insert(self._hrules, {
        hrule_x, current_y, hrule_width, hrule_h
    })

    current_y = current_y + hrule_h + m

    -- grade summary
    local max_grade_prefix_w = -math.huge
    for label in range(
        self._time_grade_prefix,
        self._flow_grade_prefix,
        self._coins_grade_prefix
    ) do
        max_grade_prefix_w = math.max(max_grade_prefix_w, select(1, label:measure()))
    end

    local max_grade_w = -math.huge
    for grade in range(
        self._time_grade,
        self._flow_grade,
        self._coins_grade
    ) do
        max_grade_w = math.max(max_grade_w, select(1, grade:measure()))
    end

    do
        local grade_prefix_x = x + 0.5 * width - max_grade_prefix_w - m
        local grade_x = x + 0.5 * width + m + 0.5 * (0.5 * width - max_grade_prefix_w )

        for prefix_colon_grade in range(
            { self._time_grade_prefix, self._time_grade_colon, self._time_grade },
            { self._flow_grade_prefix, self._flow_grade_colon, self._flow_grade },
            { self._coins_grade_prefix, self._coins_grade_colon, self._coins_grade }
        ) do
            local prefix, colon, grade = table.unpack(prefix_colon_grade)

            for label in range(prefix, colon) do
                label:set_justify_mode(rt.JustifyMode.LEFT)
            end

            local prefix_w, prefix_h = prefix:measure()
            local colon_w, colon_h = colon:measure()
            local grade_w, grade_h = grade:measure()

            local max_h = math.max(prefix_h, colon_h, grade_h)

            prefix:reformat(
                grade_prefix_x, current_y + 0.5 * max_h - 0.5 * prefix_h,
                math.huge, math.huge
            )

            colon:reformat(
                x + 0.5 * width - 0.5 * colon_w, current_y + 0.5 * max_h - 0.5 * prefix_h,
                math.huge, math.huge
            )

            grade:reformat(
                grade_x, current_y + 0.5 * max_h - 0.5 * grade_h,
                grade_w, grade_h
            )

            current_y = current_y + max_h
        end
    end

    current_y = current_y + hrule_h + m

    table.insert(self._hrules, {
        hrule_x, current_y, hrule_width, hrule_h
    })

    -- total
    do
        current_y = current_y + m
        local grade_w, grade_h = self._total_grade:measure()
        local grade_x = x + 0.5 * width - 0.5 * grade_w
        self._total_grade:reformat(grade_x, current_y)

        local total_grade_prefix_w, total_grade_prefix_h = self._total_grade_prefix:measure()
        self._total_grade_prefix:reformat(
            grade_x - m - total_grade_prefix_w,
            current_y + 0.5 * grade_h - total_grade_prefix_h,
            math.huge
        )

        current_y = current_y + grade_h + outer_margin
    end

    self._final_height = current_y - y
    self._final_width = hrule_width + 2 * outer_margin
end

--- @brief
function mn.StageSelectItem:realize()
    local x, y = 100, 50
    for widget in range(
        self._title_label,
        self._flow_prefix_label,
        self._flow_colon_label,
        self._flow_value_label,
        self._flow_grade_prefix,
        self._flow_grade_colon,
        self._flow_grade,
        self._time_prefix_label,
        self._time_colon_label,
        self._time_value_label,
        self._time_grade_prefix,
        self._time_grade_colon,
        self._time_grade,
        self._coins_grade_prefix,
        self._coins_grade_colon,
        self._coins_grade,
        self._difficulty_prefix_label,
        self._difficulty_colon_label,
        self._difficulty_value_label,
        self._description_label,
        self._total_grade_prefix,
        self._total_grade
    ) do
        widget:realize()
    end
end

--- @brief
function mn.StageSelectItem:draw()
    for widget in range(
        self._title_label,
        self._flow_prefix_label,
        self._flow_colon_label,
        self._flow_value_label,
        self._flow_grade_prefix,
        --self._flow_grade_colon,
        self._flow_grade,
        self._time_prefix_label,
        self._time_colon_label,
        self._time_value_label,
        self._time_grade_prefix,
        --self._time_grade_colon,
        self._time_grade,
        self._coins_grade_prefix,
        --self._coins_grade_colon,
        self._coins_grade,
        self._difficulty_prefix_label,
        self._difficulty_colon_label,
        self._difficulty_value_label,
        self._description_label,
        self._total_grade_prefix,
        self._total_grade
    ) do
        widget:draw()
    end

    rt.Palette.FOREGROUND:bind()
    for hrule in values(self._hrules) do
        love.graphics.rectangle("fill", table.unpack(hrule))
    end

    for entry in values(self._coins) do
        entry.coin:draw(entry.x, entry.y)
    end

    love.graphics.setColor(1, 1, 1, 1)
    self:draw_bounds()
end

--- @brief
function mn.StageSelectItem:update(delta)
    for grade in range(
        self._time_grade,
        self._flow_grade,
        self._coins_grade,
        self._total_grade
    ) do
        grade:update(delta)
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