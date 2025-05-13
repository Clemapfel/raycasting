require "common.translation"
require "common.smoothed_motion_1d"
require "common.font"
require "common.widget"
require "common.label"

rt.settings.overworld.results_screen = {
    reveal_duration = 0.5,
    hide_duration = 0.5,
    score_reveal_duration = 0.75,
}

--- @class ow.ResultsScreen
ow.ResultsScreen = meta.class("ResultsScreen", rt.Widget)

local _prefix, _postfix = "<o>", "</o>"
local _REVEALED, _HIDDEN = 0, 1

--- @brief
function ow.ResultsScreen:instantiate()

    local font, font_mono = rt.settings.font.default_large, rt.settings.font.default_mono_large

    local Label = function(text)
        return rt.Label(_prefix .. text .. _postfix, font, font_mono)
    end

    self._flow_percentage = 0
    self._flow_percentage_prefix_label = Label(rt.Translation.overworld_scene.results_screen.flow_percentage)
    self._flow_percentage_colon_label = Label(":")
    self._flow_percentage_label = Label("0")

    self._time = 0
    self._time_prefix_label = Label(rt.Translation.overworld_scene.results_screen.time)
    self._time_colon_label = Label(":")
    self._time_label = Label("0")

    self._background_reveal_animation = rt.TimedAnimation(rt.settings.overworld.results_screen.reveal_duration, _HIDDEN, _REVEALED, rt.InterpolationFunctions.SINUSOID_EASE_OUT)
    self._background_hide_animation = rt.TimedAnimation(rt.settings.overworld.results_screen.hide_duration, _REVEALED, _HIDDEN, rt.InterpolationFunctions.SINUSOID_EASE_IN)
    self._is_revealing = false
    self._presented = false
end

--- @brief
function ow.ResultsScreen:realize()
    for label in range(
        self._flow_percentage_prefix_label,
        self._flow_percentage_colon_label,
        self._flow_percentage_label,
        self._time_prefix_label,
        self._time_colon_label,
        self._time_label
    ) do
        label:set_justify_mode(rt.JustifyMode.LEFT)
        label:realize()
    end
end

--- @brief
function ow.ResultsScreen:size_allocate(x, y, width, height)
    if self._presented then return end

    self._position = 0

    local row_h = -math.huge
    local max_prefix_w = -math.huge
    for prefix in range(
        self._flow_percentage_prefix_label,
        self._time_prefix_label
    ) do
        local w, h = prefix:measure()
        max_prefix_w = math.max(max_prefix_w, w)
        row_h = math.max(row_h, h)
    end

    local colon_w, _ = self._flow_percentage_colon_label:measure()

    local max_value_w = -math.huge
    for value in range(
        self._flow_percentage_label,
        self._time_label
    ) do
        local w, h = value:measure()
        max_value_w = math.max(max_value_w, w)
        row_h = math.max(row_h, h)
    end

    local m = rt.settings.margin_unit
    local left_margin, top_margin = 2 * m, 2 * m
    local current_y = top_margin

    local prefix_x = left_margin
    local colon_x = prefix_x + max_prefix_w + 2 * m
    local value_x = colon_x + 4 * m

    self._time_prefix_label:reformat(prefix_x, current_y, math.huge)
    self._time_colon_label:reformat(colon_x, current_y, math.huge)
    self._time_label:reformat(value_x, current_y, math.huge)

    current_y = current_y + row_h + m

    self._flow_percentage_prefix_label:reformat(prefix_x, current_y, math.huge)
    self._flow_percentage_colon_label:reformat(colon_x, current_y, math.huge)
    self._flow_percentage_label:reformat(value_x, current_y, math.huge)
end

--- @brief
function ow.ResultsScreen:present(time, flow_percentage)
    meta.assert(time, "Number", flow_percentage, "Number")
    self._presented = true
    self._flow_percentage_label:set_text(_prefix .. "<mono>" .. flow_percentage .. "</mono>" .. _postfix)
    self._time_label:set_text(_prefix .. "<mono>" .. string.format_time(time) .. "</mono>" .. _postfix)
    self:reformat()

    self._is_revealing = true
end

--- @brief
function ow.ResultsScreen:close()
    self._is_revealing = false
end

--- @brief
function ow.ResultsScreen:get_is_active()
    return self._is_revealing
end

--- @brief
function ow.ResultsScreen:update(delta)
    local value
    if self._is_revealing then
        self._background_reveal_animation:update(delta)
        value = self._background_reveal_animation:get_value()
        self._background_hide_animation:set_elapsed((1 - self._background_reveal_animation:get_elapsed() / self._background_reveal_animation:get_duration()) * self._background_hide_animation:get_duration())
    else
        self._background_hide_animation:update(delta)
        value = self._background_hide_animation:get_value()
        self._background_reveal_animation:set_elapsed((1 - self._background_hide_animation:get_elapsed() / self._background_hide_animation:get_duration()) * self._background_reveal_animation:get_duration())
    end

    self._position = value
end

--- @brief
function ow.ResultsScreen:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push()
    love.graphics.translate(self._position * self._bounds.width, 0)
    --love.graphics.rectangle("fill", self._bounds.x, self._bounds.y, self._bounds.width, self._bounds.height)

    love.graphics.translate(self._bounds.x, self._bounds.y)
    for label in range(
        self._flow_percentage_prefix_label,
        self._flow_percentage_colon_label,
        self._flow_percentage_label,
        self._time_prefix_label,
        self._time_colon_label,
        self._time_label
    ) do
        label:draw()
    end

    love.graphics.pop()
end