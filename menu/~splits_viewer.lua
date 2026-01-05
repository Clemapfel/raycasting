rt.settings.menu.splits_viewer = {
    line_width = 4
}

--- @class mn.SplitsViewer
mn.SplitsViewer = meta.class("SplitsViewer", rt.Widget)

local _font = rt.Font("assets/fonts/Baloo2/Baloo2-Bold.ttf")

local _new_header = function(text)
    return rt.Label("<b><o>" .. text .. "</o></b>", rt.FontSize.REGULAR, _font)
end

local _new_value = function(text)
    return rt.Label("<mono><b><o>" .. text .. "</o></b></mono>", rt.FontSize.REGULAR) --, _font)
end

local _format_overall = function(time)
    return "<b><o><rainbow>" .. string.format_time(time) .. "</rainbow></o></b>"
end

--- @brief
function mn.SplitsViewer:instantiate(current, best)
    local translation = rt.Translation.splits_viewer
    self._current_header = _new_header(translation.current_header)
    self._delta_header = _new_header(translation.delta_header)
    self._best_header = _new_header(translation.best_header)

    self._overall_label = rt.Label("", rt.FontSize.LARGER)
    self._overall_prefix_label = _new_header(translation.overall_prefix)

    self._current_labels = {}
    self._delta_labels = {}
    self._best_labels = {}
    self._n_rows = 0

    self._header_hrule = { 0, 0, 1, 1 }
    self._column_vrules = {}

    if current ~= nil then
        self:create_from(current, best)
    end
end

--- @brief
function mn.SplitsViewer:realize()
    if self:already_realized() then return end
    for label in range(
        self._current_header,
        self._delta_header,
        self._best_header
    ) do
        label:set_justify_mode(rt.JustifyMode.CENTER)
        label:realize()
    end

    for other in range(
        self._overall_prefix_label,
        self._overall_label
    ) do
        other:set_justify_mode(rt.JustifyMode.LEFT)
        other:realize()
    end

    if self:get_is_realized() then
        for labels in range(
            self._current_labels,
            self._delta_labels,
            self._best_labels
        ) do
            for label in values(labels) do
                label:realize()
            end
        end

        self:reformat()
    end
end

--- @brief
function mn.SplitsViewer:create_from(currents, bests)
    meta.assert(currents, "Table", bests, "Table")

    self._current_labels = {}
    self._delta_labels = {}
    self._best_labels = {}

    local current_max_width = -math.huge
    local best_max_width = -math.huge
    local delta_max_width = -math.huge

    local unknown = rt.Translation.splits_viewer.unknown

    local overall_h = 0
    self._n_rows = 0
    local last_current = 0
    for i = 1, #bests do
        local current, best = currents[i], bests[i]

        if current ~= nil then
            last_current = current
        end

        local delta
        if current == nil then
            delta = 0
            current = string.format_time(best)
        else
            delta = best - current
            current = string.format_time(current)
        end

        if best == 0 then
            best = unknown
        else
            best = string.format_time(best)
        end

        if delta > 0 then
            delta = "-" .. string.format_time(math.abs(delta))
        elseif delta < 0 then
            delta = "+" .. string.format_time(math.abs(delta))
        else
            delta = " "
        end

        table.insert(self._current_labels, _new_value(current))
        table.insert(self._delta_labels, _new_value(delta))
        table.insert(self._best_labels, _new_value(best))
        self._n_rows = self._n_rows + 1
    end

    for labels in range(
        self._current_labels,
        self._delta_labels,
        self._best_labels
    ) do
        for label in values(labels) do
            label:set_justify_mode(rt.JustifyMode.RIGHT)
        end
    end

    self._overall_label:set_justify_mode(rt.JustifyMode.LEFT)
    self._overall_label:set_text(_format_overall(last_current))
    
    if self:get_is_realized() then
        for labels in range(
            self._current_labels,
            self._delta_labels,
            self._best_labels
        ) do
            for label in values(labels) do
                label:realize()
            end
        end
        
        self:reformat()
    end
end

--- @brief
function mn.SplitsViewer:size_allocate(x, y, width, height)
    local total_h = 0
    local current_max_width = -math.huge
    local best_max_width = -math.huge
    local delta_max_width = -math.huge

    local header_w, header_h = self._current_header:measure()

    for i = 1, self._n_rows do
        local current_label = self._current_labels[i]
        local delta_label = self._delta_labels[i]
        local best_label = self._best_labels[i]

        local current_w, current_h = current_label:measure()
        local delta_w, delta_h = delta_label:measure()
        local best_w, best_h = best_label:measure()

        current_max_width = math.max(current_max_width, current_w)
        delta_max_width = math.max(delta_max_width, delta_w)
        best_max_width = math.max(best_max_width, best_w)

        total_h = total_h + math.max(current_h, delta_h, best_h)
    end

    local col_width = math.max(math.max(current_max_width, best_max_width, delta_max_width), width / 3)

    local xm, ym = rt.settings.margin_unit, 0.5 * rt.settings.margin_unit

    self._current_header:reformat(x, y - ym, col_width)
    self._delta_header:reformat(x + col_width, y - ym, col_width)
    self._best_header:reformat(x + 2 * col_width, y - ym, col_width)

    local hrule_y = y + header_h
    self._header_hrule = { x, hrule_y, x + 3 * col_width, hrule_y }

    self._column_vrules = {
        { x , y, x, y + header_h + total_h },                           -- Left edge
        { x + col_width, y, x + col_width, y + header_h + total_h },   -- Between current and delta
        { x + 2 * col_width, y, x + 2 * col_width, y + header_h + total_h }, -- Between delta and best
        { x + 3 * col_width, y, x + 3 * col_width, y + header_h + total_h }  -- Right edge
    }

    local current_y = y + header_h + ym

    for i = 1, self._n_rows do
        local current_label = self._current_labels[i]
        local delta_label = self._delta_labels[i]
        local best_label = self._best_labels[i]

        current_label:reformat(x - xm, current_y, col_width)
        delta_label:reformat(x + col_width - xm, current_y, col_width)
        best_label:reformat(x + 2 * col_width - xm, current_y, col_width)

        local current_w, current_h = current_label:measure()
        local delta_w, delta_h = delta_label:measure()
        local best_w, best_h = best_label:measure()

        current_y = current_y +  math.max(current_h, delta_h, best_h)
    end
    
    local overall_w, overall_h = self._overall_label:measure()
    self._overall_label:reformat(x + 0.5 * width - 0.5 * overall_w, current_y, math.huge)

    local prefix_w, prefix_h = self._overall_prefix_label:measure()
    self._overall_prefix_label:reformat(x + 0.5 * width - 0.5 * overall_w - 2 * xm - prefix_w, current_y + ym, math.huge)
end

--- @brief
function mn.SplitsViewer:draw()
    -- Draw headers
    for header in range(
        self._current_header,
        self._delta_header,
        self._best_header,
        self._overall_label,
        self._overall_prefix_label
    ) do
        header:draw()
    end

    -- Draw data labels
    for labels in range(
        self._current_labels,
        self._delta_labels,
        self._best_labels
    ) do
        for label in values(labels) do
            label:draw()
        end
    end

    love.graphics.setLineWidth(rt.settings.menu.splits_viewer.line_width * rt.get_pixel_scale())
    love.graphics.line(self._header_hrule)
    for vrule in values(self._column_vrules) do
        love.graphics.line(vrule)
    end
end