require "common.label"
require "menu.stage_grade_label"
require "menu.stage_preview"
require "overworld.coin_particle"
require "overworld.objects.coin"

rt.settings.menu.stage_select_item = {
    coin_radius = 8,
    coins_max_n_per_row = 7,
    coins_n_rows = 2
}

--- @class mn.StageSelectItem
mn.StageSelectItem = meta.class("StageSelectItem", rt.Widget)

local _long_dash = "\u{2014}"

local _regular = rt.Font("assets/fonts/Baloo2/Baloo2-SemiBold.ttf")
local _bold = rt.Font("assets/fonts/Baloo2/Baloo2-Bold.ttf")
local _extra_bold = rt.Font("assets/fonts/Baloo2/Baloo2-ExtraBold.ttf")

local _format_count = function(x, y)
    local x_str = tostring(x)
    local y_str = tostring(y)

    while #x_str < 2 do x_str = " " .. x_str end
    while #y_str < 2 do y_str = " " .. y_str end

    return string.paste(x_str, " / ", y_str)
end

--- @brief
function mn.StageSelectItem:instantiate(stage_id)
    meta.assert(stage_id, "String")
    self._id = stage_id
    self._hrule_callbacks = {}
    
    local translation = rt.Translation.stage_select_item
    local title_prefix, title_postfix = "<b><u>", "</u></b>"
    local flow_prefix, flow_postfix = "", ""
    local time_prefix, time_postfix = "", ""
    local coins_prefix, coins_postfix = "", ""
    local grade_prefix, grade_postfix = "<b><o>", "</b></o>"
    local prefix_prefix, prefix_postfix = "", ""
    local description_prefix, description_postfix = "<color=GRAY>", "</color>"
    local header_prefix, header_postfix = "", ""
    local colon = "<color=GRAY>:</color>"

    local state, id = rt.GameState, self._id
    local time_grade, flow_grade, coin_grade, total_grade = state:get_stage_grades(id)

    local title = state:get_stage_name(id)
    local was_cleared = state:get_stage_was_cleared(id)
    local time = not was_cleared and _long_dash or string.format_time(state:get_stage_best_time(id))
    local flow = not was_cleared and _long_dash or string.format_percentage(state:get_stage_best_flow_percentage(id))
    local description = state:get_stage_description(id)
    local coins = _format_count(
        state:get_stage_n_coins_collected(id), state:get_stage_n_coins(id)
    )

    local function extra_bold(text) return rt.Label(text, rt.FontSize.BIG, _extra_bold) end
    local function bold(text) return rt.Label(text, rt.FontSize.BIG, _bold) end
    local function regular(text) return rt.Label(text, rt.FontSize.BIG, _regular) end
    local function small(text) return rt.Label(text, rt.FontSize.BIG, _regular)  end

    local grade_font_size = rt.FontSize.LARGER

    meta.install(self, {
        _title_label = extra_bold(title_prefix .. title .. title_postfix),

        _stage_preview = mn.StagePreview(stage_id),

        _flow_prefix_label = bold(prefix_prefix .. translation.flow_prefix .. prefix_postfix),
        _flow_colon_label = regular(colon),
        _flow_value_label = regular(flow_prefix .. flow .. flow_postfix),

        _flow_grade_prefix_label = regular(prefix_prefix .. translation.flow_grade_prefix .. prefix_postfix),
        _flow_grade_colon = regular(colon),
        _flow_grade = mn.StageGradeLabel(flow_grade, grade_font_size),

        _time_prefix_label = bold(prefix_prefix ..translation.time_prefix .. prefix_postfix),
        _time_colon_label = regular(colon),
        _time_value_label = regular(time_prefix .. time .. time_postfix),

        _time_grade_prefix_label = regular(prefix_postfix .. translation.time_grade_prefix .. prefix_postfix),
        _time_grade_colon = regular(colon),
        _time_grade = mn.StageGradeLabel(time_grade, grade_font_size),

        _coins_prefix_label = bold(prefix_prefix .. translation.coins_prefix .. prefix_postfix),
        _coins_colon_label = regular(colon),
        _coins_value_label = regular(coins_prefix .. coins .. coins_postfix),

        _coins_grade_prefix_label = regular(prefix_prefix .. translation.coins_grade_prefix .. prefix_postfix),
        _coins_grade_colon = regular(colon),
        _coins_grade = mn.StageGradeLabel(coin_grade, grade_font_size),

        _description_label = rt.Label(description_prefix .. description .. description_postfix, rt.FontSize.SMALL)
    })
end

--- @brief
function mn.StageSelectItem:size_allocate(x, y, width, height)
    self._hrules = {}
    local m = rt.settings.margin_unit
    local hrule_height = 2

    local outer_margin = 2 * m
    local current_x, current_y = x + outer_margin, y

    self._title_label:reformat(0, 0, math.huge, math.huge)
    local title_w, title_h = self._title_label:measure()
    self._title_label:reformat(x + 0.5 * width - 0.5 * title_w, current_y, math.huge, math.huge)
    current_y = current_y + title_h + m

    local preview_w = 300 * rt.get_pixel_scale()
    local preview_h = preview_w / (16 / 9)
    local preview_x = x + 0.5 * width - 0.5 * preview_w
    local preview_y = current_y

    self._stage_preview:reformat(
        preview_x, preview_y, preview_w, preview_h
    )

    current_y = current_y + preview_h + m

    local hrule_width = preview_w
    self._hrule_callbacks = {
        function()
            love.graphics.setLineWidth(hrule_height * rt.get_pixel_scale())
            love.graphics.setLineJoin("none")
        end
    }

    table.insert(self._hrule_callbacks, function()
        love.graphics.line(
            preview_x , preview_y,
            preview_x + preview_w, preview_y,
            preview_x + preview_w, preview_y + preview_h,
            preview_x, preview_y + preview_h,
            preview_x , preview_y
        )
    end)

    local push_hrule = function(y)
        table.insert(self._hrule_callbacks, function()
            local x = x + 0.5 * width - 0.5 * hrule_width
            love.graphics.line(x, y, x + hrule_width, y)
        end)
    end

    --[[
    self._description_label:reformat(0, current_y, math.huge, math.huge)
    local description_w, description_h = self._description_label:measure()
    self._description_label:reformat(x + 0.5 * width - 0.5 * description_w, current_y, math.huge, math.huge)
    current_y = current_y + description_h + m

    table.insert(self._hrules, {
        x + 0.5 * width - 0.5 * hrule_width, current_y, hrule_width, hrule_height
    })

    current_y = current_y + m

    ]]--

    -- best

    local function measure(...)
        local max_w, max_h = -math.huge, -math.huge
        for i = 1, select("#", ...) do
            select(i, ...):reformat(0, 0, math.huge, math.huge)
            local w, h = select(i, ...):measure()
            max_w = math.max(max_w, w)
            max_h = math.max(max_h, h)
        end
        return max_w, max_h
    end

    local prefix_w, prefix_h = measure(self._flow_prefix_label, self._time_prefix_label, self._coins_prefix_label)
    local value_w, value_h = measure(self._flow_value_label, self._time_value_label, self._coins_value_label)
    local colon_w, colon_h = measure(self._flow_colon_label, self._time_colon_label, self._coins_colon_label)

    local prefix_x = x + outer_margin
    local max_value_h = math.max(prefix_h, value_h, colon_h)
    local total_value_w = prefix_w + colon_w + value_w + 2 * m
    local colon_x = math.max(x + 0.5 * width - 0.5 * colon_w, prefix_w + m)
    for tuple in range(
        { self._time_prefix_label, self._time_colon_label, self._time_value_label },
        { self._coins_prefix_label, self._coins_colon_label, self._coins_value_label } --,
        -- { self._flow_prefix_label, self._flow_colon_label, self._flow_value_label }
    ) do
        local prefix, colon, value = table.unpack(tuple)

        for label in range(prefix, colon, value) do
            label:set_justify_mode(rt.JustifyMode.LEFT)
        end

        local current_prefix_w, current_prefix_h = prefix:measure()
        prefix:reformat(prefix_x, current_y + 0.5 * max_value_h - 0.5 * current_prefix_h)

        local current_value_w, current_value_h = value:measure()
        local right_x = colon_x + colon_w + 0.5 * (x + width - (colon_x + colon_w))
        value:reformat(right_x - 0.5 * current_value_w, current_y + 0.5 * max_value_h - 0.5 * current_value_h)

        local current_colon_w, current_colon_h = colon:measure()
        colon:reformat(colon_x, current_y + 0.5 * max_value_h - 0.5 * current_colon_h)

        current_y = current_y + max_value_h
    end

    local value_area_target_w = 2 * prefix_w + 4 * outer_margin

    current_y = current_y + m
    push_hrule(current_y)
    current_y = current_y + m

    -- columns

    for prefix in range(
        self._time_grade_prefix_label,
        self._flow_grade_prefix_label,
        self._coins_grade_prefix_label
    ) do
        prefix:reformat(0, 0, width / 3)
    end

    local max_grade_w, max_grade_h = measure(
        self._time_grade,
        self._flow_grade,
        self._coins_grade
    )

    local max_prefix_w, max_prefix_h = measure(
        self._time_grade_prefix_label,
        self._flow_grade_prefix_label,
        self._coins_grade_prefix_label
    )

    local column_w = math.max(max_grade_w, max_prefix_w, 1 / 3 * title_w, 1 / 3 * value_area_target_w)
    local column_x, column_y = x + outer_margin + 0.5 * (width - 2 * outer_margin) - (3 / 2) * column_w, current_y
    local column_h = -math.huge
    for column in range(
        { self._coins_grade_prefix_label, self._coins_grade },
        { self._time_grade_prefix_label, self._time_grade  },
        { self._flow_grade_prefix_label, self._flow_grade  }
    ) do
        local prefix, grade = table.unpack(column)

        local prefix_w, prefix_h = prefix:measure()
        local grade_w, grade_h = grade:measure()

        local local_y = column_y
        prefix:reformat(column_x + 0.5 * column_w - 0.5 * prefix_w, local_y)
        local_y = local_y + prefix_h
        grade:reformat(column_x + 0.5 * column_w - 0.5 * grade_w, local_y)
        local_y = local_y + grade_h

        column_x = column_x + column_w
        current_y = math.max(current_y, local_y)
    end

    current_y = current_y + m
    push_hrule(current_y)
    current_y = current_y + m
    current_y = current_y + outer_margin

    self._final_width = math.max(
        title_w,
        value_area_target_w,
        3 * column_w
    ) + 2 * outer_margin
    self._final_height = current_y - y

    self._last_window_height = love.graphics.getHeight()
end

function mn.StageSelectItem:measure()
    self:reformat()
    return self._final_width, self._final_height
end

local _member_names
do
    _member_names = {}
    for which in range("flow", "coins", "time") do
        for name in range(
            "_" .. which .. "_prefix_label",
            "_" .. which .. "_colon_label",
            "_" .. which .. "_value_label",
            "_" .. which .. "_grade_prefix_label",
            "_" .. which .. "_grade_colon",
            "_" .. which .. "_grade"
        ) do
           table.insert(_member_names, name)
        end
    end
end

--- @brief
function mn.StageSelectItem:realize()
    for widget in range(
        self._title_label,
        self._description_label,
        self._stage_preview
    ) do
        widget:realize()
    end

    for name in values(_member_names) do
        self[name]:realize()
    end
end

--- @brief
function mn.StageSelectItem:draw()
    for name in values(_member_names) do
        self[name]:draw()
    end

    for widget in range(
        self._title_label,
        self._description_label,
        self._stage_preview
    ) do
        widget:draw()
    end

    rt.Palette.FOREGROUND:bind()

    for callback in values(self._hrule_callbacks) do
        callback()
    end
end

--- @brief
function mn.StageSelectItem:update(delta)
    for grade in range(
        self._time_grade,
        self._flow_grade,
        self._coins_grade
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
    rt.critical("In mn.StageSelectItem.create_from_state: TODO")
end