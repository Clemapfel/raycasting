require "common.smoothed_motion_1d"
require "menu.stage_grade_label"
require "common.translation"
require "common.label"

rt.settings.overworld.result_screen = {
    fraction_motion_duration = 2, -- total duration of reveal / hide, seconds
    fraction_motion_ramp = 10, -- how fast motion approaches target
    slope = 0.3, -- how diagonal shape is
    label_roll_duration = 2, -- seconds

    flow_step = 1 / 100, -- fraction
    time_step = 0.2, -- seconds
    coins_step = 1, -- count

    flow_steps_per_second = 5,
    time_steps_per_second = 20,
    coins_steps_per_second = 1
}

--- @class ow.ResultScreen
ow.ResultsScreen = meta.class("ResultScreen", rt.Widget)

local _shader
local _HIDDEN, _SHOWN = 1, 0

local _mix_step = function(lower, upper, fraction, step_size)
    local interpolated = math.mix(lower, upper, fraction)
    return math.ceil(interpolated / step_size) * step_size
end

local _new_state = function(title, time, time_grade, flow, flow_grade, n_coins, coins_grade, total_grade)
    local speed = rt.settings.overworld.result_screen.label_roll_speed
    return {
        title = title,

        flow_target = flow, -- percentage in [0, 1]
        flow_current = 0,
        flow_start = 0,

        time_target = time, -- seconds
        time_current = 0,
        time_start = 0,

        coins_target = n_coins, -- integer
        coins_current = 0,
        coins_start = 0,

        elapsed = 0,

        flow_grade = flow_grade,
        time_grade = time_grade,
        coins_grade = coins_grade,
        total_grade = total_grade,

        get_flow = function(self)
            return string.format_percentage(self.flow_current)
        end,

        get_time = function(self)
            return string.format_time(self.time_current)
        end,

        get_coins = function(self)
            return self.coins_current .. " / " .. self.coins_target
        end,

        get_time_grade = function(self) return self.time_grade end,
        get_flow_grade = function(self) return self.flow_grade end,
        get_coins_grade = function(self) return self.coins_grade end,
        get_total_grade = function(self) return self.coins_grade end,

        get_title = function(self)
            return "<b><o><u>" .. self.title .. "</u></o></b>"
        end,

        update = function(self, delta)
            local settings = rt.settings.overworld.result_screen
            self.elapsed = self.elapsed + delta

            -- increase value but round to nearest step
            local time_step = settings.time_step
            local flow_step = settings.flow_step
            local coins_step = settings.coins_step

            local time_delta = math.abs(self.time_target - self.time_start)
            local flow_delta = math.abs(self.flow_target - self.flow_start)
            local coins_delta = math.abs(self.coins_target - self.coins_start)

            local max_delta = math.max(time_delta, flow_delta, coins_delta)
            local time_speed = max_delta / time_delta  * settings.label_roll_duration
            local flow_speed = max_delta / flow_delta * settings.label_roll_duration
            local coins_speed = max_delta / coins_delta * settings.label_roll_duration

            local time_before = self.time_current
            if self.time_current < self.time_target then
                self.time_current = math.min(self.time_current + time_step, self.time_target)
            elseif self.time_current > self.time_target then
                self.time_current = math.max(self.time_current - time_step, self.time_target)
            end
            self.time_current = math.clamp(
                _mix_step(self.time_start, self.time_target, self.elapsed / time_speed, time_step),
                self.time_start, self.time_target
            )

            local flow_before = self.flow_current
            if self.flow_current < self.flow_target then
                self.flow_current = math.min(self.flow_current + flow_step, self.flow_target)
            elseif self.flow_current > self.flow_target then
                self.flow_current = math.max(self.flow_current - flow_step, self.flow_target)
            end
            self.flow_current = math.clamp(
                _mix_step(self.flow_start, self.flow_target, self.elapsed / flow_speed, flow_step),
                self.flow_start, self.flow_current
            )

            local coins_before = self.coins_current
            if self.coins_current < self.coins_target then
                self.coins_current = math.min(self.coins_current + coins_step, self.coins_target)
            elseif self.coins_current > self.coins_target then
                self.coins_current = math.max(self.coins_current - coins_step, self.coins_target)
            end
            self.coins_current = math.clamp(
                _mix_step(self.coins_start, self.coins_target, self.elapsed / coins_speed, coins_step),
                self.coins_start, self.coins_target
            )

            return time_before ~= self.time_current, flow_before ~= self.flow_current, coins_before ~= self.coins_current
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

    local prefix, postfix = "<b><o>", "</b></o>"
    self._flow_label = rt.Label(prefix .. translation.flow .. postfix)
    self._time_label = rt.Label(prefix .. translation.time .. postfix)
    self._coins_label = rt.Label(prefix .. translation.coins .. postfix)

    local glyph_properties = {
        font_size = rt.FontSize.REGULAR,
        justify_mode = rt.JustifyMode.CENTER,
        style = rt.FontStyle.BOLD,
        is_outlined = true
    }

    self._flow_value_label = rt.Glyph(state:get_flow(), glyph_properties)
    self._time_value_label = rt.Glyph(state:get_time(), glyph_properties)
    self._coins_value_label = rt.Glyph(state:get_coins(), glyph_properties)

    self._flow_grade = mn.StageGradeLabel(state:get_flow_grade(), rt.FontSize.HUGE)
    self._time_grade = mn.StageGradeLabel(state:get_time_grade(), rt.FontSize.HUGE)
    self._coins_grade = mn.StageGradeLabel(state:get_coins_grade(), rt.FontSize.HUGE)
    self._total_grade = mn.StageGradeLabel(state:get_total_grade(), rt.FontSize.GIGANTIC)

    self._mesh = nil
    self._mesh_width = 0
end

--- @brief
function ow.ResultsScreen:realize()
    if self:already_realized() then return end

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

    local value_area_w = width - 2 * m - (max_grade_w + max_prefix_w)

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

        value:reformat(
            x + max_prefix_w,
            current_y + 0.5 * max_h - 0.5 * prefix_h,
            value_area_w, math.huge
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
            label:set_text(value)

            if label:get_is_realized() then
                local new_w, new_h = label:measure()
                label:reformat(x + w - new_w, y)
            end
        end
    end

    _update(time, self._time_value_label, self._state:get_time())
    _update(flow, self._flow_value_label, self._state:get_flow())
    _update(coins, self._coins_value_label, self._state:get_coins())
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
        elapsed = 0,
        title = title,
        time_target = time,
        time_current = state.time_start,
        time_grade = time_grade,

        flow_target = flow,
        flow_current = state.flow_start,
        flow_grade = flow_grade,

        coins_target = n_coins,
        coins_current = state.coins_start,
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


