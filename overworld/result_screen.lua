require "common.smoothed_motion_1d"
require "menu.stage_grade_label"
require "common.translation"
require "common.label"

rt.settings.overworld.result_screen = {
    fraction_motion_duration = 2, -- total duration of reveal / hide, seconds
    fraction_motion_ramp = 10, -- how fast motion approaches target
    slope = 0.3, -- how diagonal shape is
    label_roll_speed = 1, -- fraction per second
}

--- @class ow.ResultScreen
ow.ResultsScreen = meta.class("ResultScreen", rt.Widget)

local _shader

local _HIDDEN, _SHOWN = 1, 0

local _value_prefix, _value_postfix = "<o>", "</o>"
local _prefix_prefix, _prefix_postfix = "<b><o>", "</b></o>"
local _title_prefix, _title_postfix = "<b><u><o>", "</o></u></b>"

local _new_state = function(title, time, time_grade, flow, flow_grade, n_coins, coins_grade, total_grade)
    local speed = rt.settings.overworld.result_screen.label_roll_speed
    return {
        title = title,

        flow_target = flow, -- percentage in [0, 1]
        flow_current = 0,
        flow_speed = 1 / speed * 100, -- percent per second

        time_target = time, -- seconds
        time_current = 0,
        time_speed = 1 / speed, -- seconds per second

        coins_target = n_coins, -- integer
        coins_current = 0,
        coins_speed = 1 / speed * 20,

        flow_grade = flow_grade,
        time_grade = time_grade,
        coins_grade = coins_grade,
        total_grade = total_grade,

        get_flow = function(self)
            return _value_prefix .. string.format_percentage(self.flow_current) .. _value_postfix
        end,

        get_time = function(self)
            return _value_prefix .. string.format_time(self.time_current) .. _value_postfix
        end,

        get_coins = function(self)
            return _value_prefix .. self.coins_current .. " / " .. self.coins_target .. _value_postfix
        end,

        get_time_grade = function(self) return self.time_grade end,
        get_flow_grade = function(self) return self.flow_grade end,
        get_coins_grade = function(self) return self.coins_grade end,
        get_total_grade = function(self) return self.coins_grade end,

        get_title = function(self)
            return "<b><o><u>" .. self.title .. "</u></o></b>"
        end,

        update = function(self,  delta)
            local _step = function(current, target, speed)
                local step = (target - current) * speed * delta
                local new_current = current + step
                if new_current > target then new_current = target end
                return new_current, new_current ~= current
            end

            local time_updated, flow_updated, coins_updated

            self.time_current, time_updated = _step(self.time_current, self.time_target, self.time_speed)
            self.flow_current, flow_updated = _step(self.flow_current, self.flow_target, self.flow_speed)
            self.coins_current, coins_updated = _step(self.coins_current, self.coins_target, self.coins_speed)

            return time_updated, flow_updated, coins_updated
        end
    }
end

--- @brief
function ow.ResultsScreen:instantiate()
    if _shader == nil then _shader = rt.Shader("overworld/result_screen.glsl") end

    self._last_window_height = love.graphics.getHeight()
    local translation, settings = rt.Translation.result_screen, rt.settings.overworld.result_screen

    self._fraction = _HIDDEN
    self._fraction_motion = rt.SmoothedMotion1D(
        self._fraction,
        1 / settings.fraction_motion_duration,
        settings.fraction_motion_ramp
    )

    -- result screen state for easier access and tweening
    local state = _new_state(
        "TITLE",
        0, -- time
        rt.StageGrade.NONE,
        0, -- flow,
        rt.StageGrade.NONE,
        0, -- coins
        rt.StageGrade.NONE,
        rt.StageGrade.NONE -- total
    )
    self._state = state

    self._title_label = rt.Label(state:get_title())

    self._flow_label = rt.Label(_prefix_prefix .. translation.flow .. _prefix_postfix)
    self._time_label = rt.Label(_prefix_prefix .. translation.time .. _prefix_postfix)
    self._coins_label = rt.Label(_prefix_prefix .. translation.coins .. _prefix_postfix)

    self._flow_value_label = rt.Label(state:get_flow())
    self._time_value_label = rt.Label(state:get_time())
    self._coins_value_label = rt.Label(state:get_coins())

    self._flow_grade = mn.StageGradeLabel(state:get_flow_grade(), rt.FontSize.HUGE)
    self._time_grade = mn.StageGradeLabel(state:get_time_grade(), rt.FontSize.HUGE)
    self._coins_grade = mn.StageGradeLabel(state:get_coins_grade(), rt.FontSize.HUGE)
    self._total_grade = mn.StageGradeLabel(state:get_total_grade(), rt.FontSize.GIGANTIC)

    self._mesh = nil
    self._mesh_width = 0
end

--- @brief
function ow.ResultsScreen:realize()
    for widget in range(
        self._title_label,
        self._flow_label,
        self._time_label,
        self._coins_label,
        self._flow_value_label,
        self._time_value_label,
        self._coins_value_label,
        self._flow_grade,
        self._time_grade,
        self._coins_grade,
        self._total_grade
    ) do
        widget:realize()
    end
end

--- @brief
function ow.ResultsScreen:size_allocate(x, y, width, height)
    local mesh_x, mesh_y, mesh_w = x, y, width
    local mesh_slope = rt.settings.overworld.result_screen.slope
    x = x - mesh_w * mesh_slope
    self._mesh = rt.Mesh({
        { mesh_x,                      mesh_y + 0 * height, 0, 0, 1, 1, 1, 1 },
        { mesh_x + mesh_w * (1 + mesh_slope),              mesh_y + 0 * height, 1, 0, 1, 1, 1, 0 },
        { mesh_x + mesh_w * (1 + mesh_slope),              mesh_y + 1 * height, 1, 1, 1, 1, 1, 0 },
        { mesh_x + mesh_w * mesh_slope, mesh_y + 1 * height, 0, 1, 1, 1, 1, 1 }
    })

    local m = rt.settings.margin_unit
    local current_y = 2 * m

    local title_w, title_h = self._title_label:measure()
    self._title_label:reformat(x + width - title_w, y)
    current_y = current_y + title_h + m

    local max_prefix_w, max_grade_w = -math.huge, -math.huge
    for label in range(self._time_label, self._flow_label, self._coins_label) do
        max_prefix_w = math.max(max_prefix_w, select(1, label:measure()))
    end

    for grade in range(self._time_grade, self._flow_grade, self._coins_grade) do
        max_grade_w = math.max(max_grade_w, select(1, grade:measure()))
    end

    local _reformat = function(prefix, value, grade)
        local prefix_w, prefix_h = prefix:measure()
        local value_w, value_h = value:measure()
        local grade_w, grade_h = grade:measure()
        local max_h = math.max(prefix_h, value_h, grade_h)

        prefix:reformat(
            x,
            current_y + 0.5 * max_h - 0.5 * prefix_h,
            math.huge, math.huge
        )

        value:set_justify_mode(rt.JustifyMode.CENTER)
        value:reformat(
            x + max_prefix_w,
            current_y + 0.5 * max_h - 0.5 * prefix_h,
            width - 2 * m - (max_grade_w + max_prefix_w), math.huge
        )

        grade:reformat(
            x + width - m - grade_w,
            current_y + 0.5 * max_h - 0.5 * grade_h,
            grade_w, grade_h
        )

        current_y = current_y + max_h
    end

    _reformat(self._time_label, self._time_value_label, self._time_grade)
    _reformat(self._flow_label, self._flow_value_label, self._flow_grade)
    _reformat(self._coins_label, self._coins_value_label, self._coins_grade)

    local total_w, total_h = self._total_grade:measure()
    self._total_grade:reformat(
        x + 0.5 * width - 0.5 * total_w,
        current_y,
        total_w, total_h
    )
end

--- @brief
function ow.ResultsScreen:_update_labels(time, flow, coins)
    if self:get_is_realized() ~= true then return end

    local _update = function(should_update, label, value)
        if should_update == true then
            local x, y = label:get_position()
            local w, h = label:measure()
            label:set_text(_value_prefix .. value .. _value_postfix)

            if label:get_is_realized() then
                local new_w, new_h = label:measure()
                label:reformat(x + w - new_w, y)
            end
        end
    end

    _update(time, self._time_label, self._state:get_time())
    _update(flow, self._flow_label, self._state:get_flow())
    _update(coins, self._coins_label, self._state:get_coins())
end

--- @brief
function ow.ResultsScreen:update(delta)
    self:_update_labels(self._state:update(delta))

    for widget in range(
        self._title_label,
        self._flow_label,
        self._time_label,
        self._coins_label,
        self._flow_value_label,
        self._time_value_label,
        self._coins_value_label,
        self._flow_grade,
        self._time_grade,
        self._coins_grade,
        self._total_grade
    ) do
        widget:update(delta)
    end

    local fraction = self._fraction_motion:update(delta)
    self._mesh_offset = fraction * self._mesh_width
end

--- @brief
--- @param title String stage title
--- @param flow_percentage Number in [0, 100]
--- @param flow_grade rt.StageGrade
--- @param time Number seconds
--- @param time_grade rt.StageGrade
--- @param coins Number integer
--- @param coins_grade rt.StageGrade
--- @param total_grade rt.StageGrade
function ow.ResultsScreen:present(title, time, time_grade, flow, flow_grade, n_coins, max_n_coins, coins_grade, total_grade)
    meta.assert(
        title, "String",
        time, "Number",
        time_grade, "Number",
        flow, "Number",
        flow_grade, "Number",
        n_coins, "Number",
        max_n_coins, "Number",
        coins_grade, "Number",
        total_grade, "Number"
    )

    local state = self._state
    if state.time_grade ~= time_grade then self._time_grade:set_grade(time_grade) end
    if state.flow_grade ~= flow_grade then self._flow_grade:set_grade(flow_grade) end
    if state.coins_grade ~= time_grade then self._coins_grade:set_grade(coins_grade) end

    if state.title ~= title then
        local x, y = self._tite
    end

    meta.install(state, {
        title = title,
        time_current = time,
        time_grade = time_grade,
        flow_current = flow,
        flow_grade = flow_grade,
        coins_current = n_coins,
        coins_grade = coins_grade
    })

    self:_update_labels(true, true, true)
    self._fraction_motion:set_target_value(_SHOWN)
end

--- @brief
function ow.ResultsScreen:close()
    self._fraction_motion:set_target_value(_HIDDEN)
end

--- @brief
function ow.ResultsScreen:draw()
    love.graphics.push()
    _shader:bind()
    _shader:send("fraction", 1 - self._fraction_motion:get_value())
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    self._mesh:draw()
    _shader:unbind()
    love.graphics.pop()

    for widget in range(
        self._title_label,
        self._flow_label,
        self._time_label,
        self._coins_label,
        self._flow_value_label,
        self._time_value_label,
        self._coins_value_label,
        self._flow_grade,
        self._time_grade,
        self._coins_grade,
        self._total_grade
    ) do
        widget:draw()
    end
end

--- @brief
function ow.ResultsScreen:get_is_active()
    return self._fraction_motion:get_target_value() == _SHOWN
end


