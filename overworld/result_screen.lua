require "common.smoothed_motion_1d"
require "menu.stage_grade_label"
require "common.translation"
require "common.label"

rt.settings.overworld.result_screen = {
    fraction_speed = 1, -- fraction / s
    label_speed = 20, -- px / s
}

--- @class ow.ResultScreen
ow.ResultsScreen = meta.class("ResultScreen", rt.Widget)

local _shader

local _HIDDEN, _SHOWN = 0, 1

--- @brief
function ow.ResultsScreen:instantiate()
    if _shader == nil then _shader = rt.Shader("overworld/result_screen.glsl") end

    self._last_window_height = love.graphics.getHeight()
    local translation, settings = rt.Translation.result_screen, rt.settings.overworld.result_screen

    self._fraction = _HIDDEN
    self._fraction_motion = rt.SmoothedMotion1D(self._fraction, settings.fraction_speed)

    self._flow_label = rt.Label("<b>" .. translation.flow .. "</b>")
    self._time_label = rt.Label("<b>" .. translation.time .. "</b>")
    self._coins_label = rt.Label("<b>" .. translation.coins .. "</b>")

    self._flow_motion = rt.SmoothedMotion1D(0, settings.label_speed)
    self._time_motion = rt.SmoothedMotion1D(0, settings.label_speed)
    self._coins_motion = rt.SmoothedMotion1D(0, settings.label_speed)

    self._flow_grade = mn.StageGradeLabel(rt.StageGrade.S, rt.FontSize.GIGANTIC)
    self._time_grade = mn.StageGradeLabel(rt.StageGrade.A, rt.FontSize.HUGE)
    self._coins_grade = mn.StageGradeLabel(rt.StageGrade.B, rt.FontSize.HUGE)
end

--- @brief
function ow.ResultsScreen:realize()
    for widget in range(
        self._flow_label,
        self._time_label,
        self._coins_label,
        self._flow_grade,
        self._time_grade,
        self._coins_grade
    ) do
        widget:realize()
    end
end

--- @brief
function ow.ResultsScreen:size_allocate(x, y, width, height)
    local grade_w, grade_h = self._flow_grade:measure()
    self._flow_grade:reformat(x + 0.5 * width - grade_w, y + 0.5 * height - grade_h)
end

--- @brief
function ow.ResultsScreen:update(delta)
    for widget in range(
        self._flow_label,
        self._time_label,
        self._coins_label,
        self._flow_grade,
        self._time_grade,
        self._coins_grade
    ) do
        widget:update(delta)
    end
end

--- @brief
function ow.ResultsScreen:close()
    self._fraction = _HIDDEN
end

--- @brief
function ow.ResultsScreen:present()
    self._fraction = _SHOWN

    self._flow_grade:pulse()
end

--- @brief
function ow.ResultsScreen:draw()
    self._flow_grade:draw()
end

--- @brief
function ow.ResultsScreen:get_is_active()
    return self._fraction == _SHOWN
end


