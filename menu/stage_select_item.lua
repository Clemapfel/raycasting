require "common.label"
require "menu.stage_grade_label"
require "overworld.coin_particle"
require "overworld.objects.coin"

rt.settings.menu.stage_select_item = {
    coin_radius = 16,
    coins_max_n_per_row = 7,
    coins_n_rows = 2
}

--- @class mn.StageSelectItem
mn.StageSelectItem = meta.class("StageSelectItem", rt.Widget)

local _long_dash = "\u{2014}"
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
    local time_grade, flow_grade, coin_grade, total_grade = game_state:get_stage_grades(id)

    local title = game_state:get_stage_title(id)
    local was_cleared = game_state:get_stage_was_cleared(id)
    local time = not was_cleared and _long_dash or string.format_time(game_state:get_stage_best_time(id))
    local flow = not was_cleared and _long_dash or string.format_percentage(game_state:get_stage_best_flow_percentage(id))
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
        coin:set_is_outline(not rt.GameState:get_stage_was_coin_collected(self._id, i))

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
    if self._final_width == nil or self._last_window_height ~= love.graphics.getHeight() then
        self:reformat()
    end

    return self._final_width, self._final_height
end

--- @brief
function mn.StageSelectItem:size_allocate(x, y, width, height)
    local m = rt.settings.margin_unit

    if self._last_window_height ~= love.graphics.getHeight() then
        self:_init_coins()
    end

    local outer_margin = 2 * m
    local v_margin = 4 * m
    local current_x, current_y = x + outer_margin, y
    self._hrules = {}
    local hrule_h = 2 * rt.get_pixel_scale()

    local origin_width = width
    do -- precompute width
        if not self:get_is_realized() then self:realize() end
        local coin_r = rt.settings.menu.stage_select_item.coin_radius
        local n_coins = rt.settings.menu.stage_select_item.coins_max_n_per_row
        local coin_m = _coin_xm
        width = 2 * coin_r * n_coins + coin_m * (n_coins - 1) + 2 * outer_margin
        width = width * rt.get_pixel_scale()
    end

    local title_w, title_h = self._title_label:measure()
    self._title_label:reformat(x + 0.5 * width - 0.5 * title_w, current_y, width, math.huge)
    current_y = current_y + title_h

    local coin_width, coin_height, coin_r
    do -- coins local alignment
        coin_r = rt.settings.menu.stage_select_item.coin_radius * rt.get_pixel_scale()
        local n_coins = #self._coins
        local n_rows = rt.settings.menu.stage_select_item.coins_n_rows

        -- round robin distribute coins
        local row_i_to_n_coins = {}
        local row_i_to_width = {}
        local row_i_to_coins = {}

        for i = 1, n_rows do
            row_i_to_n_coins[i] = 0
            row_i_to_width[i] = 0
            row_i_to_coins[i] = {}
        end

        for i = 1, n_coins do
            local row_index = ((i - 1) % n_rows) + 1
            row_i_to_n_coins[row_index] = row_i_to_n_coins[row_index] + 1
        end

        local true_n_rows = 0
        for row_i = 1, n_rows do
            if row_i_to_n_coins[row_i] > 0 then true_n_rows = true_n_rows + 1 end
        end

        local coin_max_xm = _coin_xm * rt.get_pixel_scale()
        local coin_ym = 0

        coin_height = true_n_rows * 2 * coin_r + (true_n_rows - 1) * coin_ym
        coin_width = width - 2 * outer_margin - 2 * coin_r

        local coin_x, coin_y = 0, 0
        local coin_i = 1
        for row_i = 1, true_n_rows do
            local n_coins_per_row = row_i_to_n_coins[row_i]
            local coin_xm = math.min((coin_width - n_coins_per_row * 2 * coin_r) / (n_coins_per_row - 1), coin_max_xm)

            for i = 1, n_coins_per_row do
                local coin = self._coins[coin_i]
                coin.x, coin.y = coin_x, coin_y

                coin_x = coin_x + 2 * coin_r + coin_xm
                row_i_to_width[row_i] = row_i_to_width[row_i] + 2 * coin_r + ternary(i == n_coins_per_row, 0, coin_xm)
                table.insert(row_i_to_coins[row_i], coin)
                coin_i = coin_i + 1
            end

            coin_y = coin_y + 2 * coin_r + coin_ym
            coin_x = 0
        end

        -- center
        for row_i = 1, n_rows do
            local coins = row_i_to_coins[row_i]
            local row_w = row_i_to_width[row_i]

            local offset = x + 0.5 * width - 0.5 * row_w + coin_r
            for coin in values(coins) do
                coin.x = coin.x + offset
            end
        end
    end

    -- value labels
    local left_x = x + 0.5 * width - 0.5 * coin_width
    local right_x = x + 0.5 * width + 0.5 * coin_width

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

    current_y = current_y + m
    if #self._coins > 0 then
        current_y = current_y + coin_r
    end

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
        local grade_prefix_x = left_x
        local area_w = right_x - left_x
        local grade_x = math.mix(left_x, right_x, 0.5) + 0.25 * area_w

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
                grade_x - 0.5 * grade_w, current_y + 0.5 * max_h - 0.5 * grade_h,
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
        self._total_grade:reformat(grade_x, current_y, grade_w, grade_h)

        local total_grade_prefix_w, total_grade_prefix_h = self._total_grade_prefix:measure()
        self._total_grade_prefix:reformat(
            grade_x - m - total_grade_prefix_w,
            current_y + 0.5 * grade_h - total_grade_prefix_h,
            math.huge, math.huge
        )

        current_y = current_y + grade_h
    end

    self._final_height = current_y - y
    self._final_width = width

    self._bounds.width, self._bounds.height = self._final_width, self._final_height

    self._last_window_height = love.graphics.getHeight()
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
    local time_grade, flow_grade, coin_grade, total_grade = rt.GameState:get_stage_grades(self._id)

    self._time_grade:set_grade(time_grade)
    self._flow_grade:set_grade(flow_grade)
    self._coins_grade:set_grade(coin_grade)
    self._total_grade:set_grade(total_grade)

    for coin_i, entry in ipairs(self._coins) do
        local is_collected = not rt.GameState:get_stage_was_coin_collected(self._id, coin_i)
        entry.coin:set_is_outline(is_collected)
    end
end