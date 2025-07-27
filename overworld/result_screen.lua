require "common.smoothed_motion_1d"
require "menu.stage_grade_label"
require "common.translation"
require "common.label"

rt.settings.overworld.result_screen = {
    fraction_motion_duration = 2, -- total duration of reveal / hide, seconds
    fraction_motion_ramp = 10, -- how fast motion approaches target
    slope = 0.3, -- how diagonal shape is

    flow_step = 1 / 100, -- fraction
    time_step = 0.2, -- seconds
    coins_step = 1, -- count

    roll_animation_duration = 2, -- seconds
    reveal_animation_duration = 0.5,
    scale_animation_duration = 0.5,
    max_scale = 3
}

--- @class ow.ResultScreen
ow.ResultsScreen = meta.class("ResultScreen", rt.Widget)

local _shader
local _HIDDEN, _SHOWN = 1, 0

local _mix_step = function(lower, upper, fraction, step_size)
    local interpolated = math.mix(lower, upper, fraction)
    return math.ceil(interpolated / step_size) * step_size
end

local _format_flow = function(fraction, start, target)
    local step = rt.settings.overworld.result_screen.flow_step
    local value = math.clamp(
        _mix_step(start, target, fraction, step),
        math.min(start, target),
        math.max(start, target)
    )
    return string.format_percentage(value)
end

local _format_time = function(fraction, start, target)
    local step = rt.settings.overworld.result_screen.time_step
    local value = math.clamp(
        _mix_step(start, target, fraction, step),
        math.min(start, target),
        math.max(start, target)
    )

    return string.format_time(value)
end

local _format_coins = function(fraction, start, target, max)
    local step = rt.settings.overworld.result_screen.coins_step
    local value = math.clamp(
        _mix_step(start, target, fraction, step),
        math.min(start, target),
        math.max(start, target)
    )

    return math.round(value) .. " / " .. math.round(max)
end

--- @brief
function ow.ResultsScreen:instantiate()
    if _shader == nil then _shader = rt.Shader("overworld/result_screen.glsl") end

    self._last_window_height = love.graphics.getHeight()
    local translation, settings = rt.Translation.result_screen, rt.settings.overworld.result_screen

    self._mesh = nil
    self._mesh_offset = 0

    -- config
    self._title = "NO TITLE"
    self._flow_target = 0
    self._flow_current = 0
    self._flow_start = 0

    self._time_target = 0 -- seconds
    self._time_current = 0
    self._time_start = 0

    self._coins_target = 0 -- integer
    self._coins_current = 0
    self._coins_start = 0
    self._coins_max = 0

    self._flow_grade = rt.StageGrade.NONE
    self._time_grade = rt.StageGrade.NONE
    self._coins_grade = rt.StageGrade.NONE
    self._total_grade = rt.StageGrade.NONE

    self._title_label = rt.Label("<b><o><u>" .. self._title .. "</b></o></u>", rt.FontSize.BIG)

    local prefix, postfix = "<b><o>", "</b></o>"
    self._flow_prefix_label = rt.Label(prefix .. translation.flow .. postfix)
    self._time_prefix_label = rt.Label(prefix .. translation.time .. postfix)
    self._coins_prefix_label = rt.Label(prefix .. translation.coins .. postfix)

    local glyph_properties = {
        font_size = rt.FontSize.REGULAR,
        justify_mode = rt.JustifyMode.CENTER,
        style = rt.FontStyle.BOLD,
        is_outlined = true
    }

    self._flow_value_label = rt.Glyph(_format_flow(0, 0, self._flow_current), glyph_properties)
    self._time_value_label = rt.Glyph(_format_time(0, 0, self._time_current), glyph_properties)
    self._coins_value_label = rt.Glyph(_format_coins(0, 0, self._coins_current, 0), glyph_properties)

    self._flow_grade_label = mn.StageGradeLabel(self._flow_grade, rt.FontSize.HUGE)
    self._time_grade_label = mn.StageGradeLabel(self._time_grade, rt.FontSize.HUGE)
    self._coins_grade_label = mn.StageGradeLabel(self._coins_grade, rt.FontSize.HUGE)
    self._total_grade_label = mn.StageGradeLabel(self._total_grade, rt.FontSize.GIGANTIC)

    -- animation

    local _new_reveal_animation = function()
        return rt.TimedAnimation(
            settings.reveal_animation_duration,
            _HIDDEN, _SHOWN,
            rt.InterpolationFunctions.LINEAR
        )
    end

    self._max_scale = settings.max_scale
    local _new_scale_animation = function()
        return rt.TimedAnimation(
            settings.scale_animation_duration,
            1, 0,
            rt.InterpolationFunctions.LINEAR
        )
    end

    local _new_opacity_animation = function()
        return rt.TimedAnimation(
            settings.scale_animation_duration, -- sic
            0, 1,
            rt.InterpolationFunctions.LINEAR
        )
    end

    local _new_roll_animation = function()
        return rt.TimedAnimation(
            settings.roll_animation_duration,
            0, 1,
            rt.InterpolationFunctions.LINEAR
        )
    end

    self._title_reveal_animation = _new_reveal_animation()
    self._title_label_offset = 0

    self._time_prefix_reveal_animation = _new_reveal_animation()
    self._time_value_reveal_animation = _new_reveal_animation()
    self._time_value_roll_animation = _new_roll_animation()
    self._time_grade_scale_animation = _new_scale_animation()
    self._time_grade_opacity_animation = _new_opacity_animation()
    self._time_prefix_offset = 0 -- max offsets
    self._time_value_offset = 0
    self._time_grade_center_x = 0
    self._time_grade_center_y = 0

    self._flow_prefix_reveal_animation = _new_reveal_animation()
    self._flow_value_reveal_animation = _new_reveal_animation()
    self._flow_value_roll_animation = _new_roll_animation()
    self._flow_grade_scale_animation = _new_scale_animation()
    self._flow_grade_opacity_animation = _new_opacity_animation()
    self._flow_prefix_offset = 0
    self._flow_value_offset = 0
    self._flow_grade_center_x = 0
    self._flow_grade_center_y = 0

    self._coins_prefix_reveal_animation = _new_reveal_animation()
    self._coins_value_reveal_animation = _new_reveal_animation()
    self._coins_value_roll_animation = _new_roll_animation()
    self._coins_grade_scale_animation = _new_scale_animation()
    self._coins_grade_opacity_animation = _new_opacity_animation()
    self._coins_prefix_offset = 0
    self._coins_value_offset = 0
    self._coins_grade_center_x = 0
    self._coins_grade_center_y = 0

    self._total_grade_scale_animation = _new_scale_animation()
    self._total_grade_opacity_animation = _new_opacity_animation()
    self._total_grade_center_x = 0
    self._total_grade_center_y = 0

    self._shader_fraction = _HIDDEN
    self._shader_fraction_motion = rt.SmoothedMotion1D(
        self._shader_fraction,
        1 / settings.fraction_motion_duration,
        settings.fraction_motion_ramp
    )

    self._time_grade_label:set_opacity(self._time_grade_opacity_animation:get_value())
    self._flow_grade_label:set_opacity(self._flow_grade_opacity_animation:get_value())
    self._coins_grade_label:set_opacity(self._coins_grade_opacity_animation:get_value())
    self._total_grade_label:set_opacity(self._total_grade_opacity_animation:get_value())
end

--- @brief
function ow.ResultsScreen:realize()
    if self:already_realized() then return end

    for widget in range(
        self._title_label,
        self._flow_prefix_label,
        self._time_prefix_label,
        self._coins_prefix_label,
        self._flow_value_label,
        self._time_value_label,
        self._coins_value_label,
        self._flow_grade_label,
        self._time_grade_label,
        self._coins_grade_label,
        self._total_grade_label
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
    self._mesh_offset = mesh_w

    local m = rt.settings.margin_unit
    local current_y = 2 * m

    local title_w, title_h = self._title_label:measure()
    self._title_label:reformat(x + width - title_w, y)
    self._title_label_offset = select(1, self._title_label:get_position())
    current_y = current_y + title_h + m

    local max_prefix_w, max_grade_w = -math.huge, -math.huge
    for label in range(self._time_prefix_label, self._flow_prefix_label, self._coins_prefix_label) do
        max_prefix_w = math.max(max_prefix_w, select(1, label:measure()))
    end

    for grade in range(self._time_grade_label, self._flow_grade_label, self._coins_grade_label) do
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

        local grade_x, grade_y = x + width - m - grade_w, current_y + 0.5 * max_h - 0.5 * grade_h
        grade:reformat(grade_x, grade_y, grade_w, grade_h)

        current_y = current_y + max_h

        local prefix_offset = love.graphics.getWidth() - select(1, prefix:get_position())
        local value_offset = love.graphics.getWidth() - select(1, value:get_position())

        return prefix_offset, value_offset, grade_x + 0.5 * grade_w, grade_y + 0.5 * grade_h
    end

    self._time_prefix_offset, self._time_value_offset, self._time_grade_center_x, self._time_grade_center_y = _reformat(self._time_prefix_label, self._time_value_label, self._time_grade_label)
    self._flow_prefix_offset, self._flow_value_offset, self._flow_grade_center_x, self._flow_grade_center_y = _reformat(self._flow_prefix_label, self._flow_value_label, self._flow_grade_label)
    self._coins_prefix_offset, self._coins_value_offset, self._coins_grade_center_x, self._coins_grade_center_y = _reformat(self._coins_prefix_label, self._coins_value_label, self._coins_grade_label)

    local total_w, total_h = self._total_grade_label:measure()
    local total_x, total_y = x + 0.5 * width - 0.5 * total_w, current_y
    self._total_grade_label:reformat(total_x, total_y, total_w, total_h)
    self._total_grade_center_x, self._total_grade_center_y =  total_x + 0.5 * total_w, total_y + 0.5 * total_h
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

        return select(1, label:get_position())
    end

    self._time_value_offset = _update(time, self._time_value_label, self._config:get_time())
    self._flow_value_offset = _update(flow, self._flow_value_label, self._config:get_flow())
    self._coins_value_offset = _update(coins, self._coins_value_label, self._config:get_coins())
end

--- @brief
function ow.ResultsScreen:update(delta)
    self._shader_fraction = self._shader_fraction_motion:update(delta)
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

    self._title = title
    self._total_grade = total_grade

    self._time_target = time
    self._time_start = 0
    self._time_current = self._time_start
    self._time_grade_label:set_grade(time_grade)

    self._flow_target = flow
    self._flow_start = 0
    self._flow_current = self._flow_start
    self._flow_grade_label:set_grade(flow_grade)

    self._coins_max = max_n_coins
    self._coins_target = n_coins
    self._coins_start = 0
    self._coins_current = self._coins_start
    self._coins_grade_label:set_grade(time_grade)

    for animation in range(
        self._title_reveal_animation,

        self._time_prefix_reveal_animation,
        self._time_value_reveal_animation,
        self._time_value_roll_animation,
        self._time_grade_scale_animation,
        self._time_grade_opacity_animation,

        self._flow_prefix_reveal_animation,
        self._flow_value_reveal_animation,
        self._flow_value_roll_animation,
        self._flow_grade_scale_animation,
        self._flow_grade_opacity_animation,

        self._coins_prefix_reveal_animation,
        self._coins_value_reveal_animation,
        self._coins_value_roll_animation,
        self._coins_grade_scale_animation,
        self._coins_grade_opacity_animation,

        self._total_grade_scale_animation,
        self._total_grade_opacity_animation
    ) do
        animation:reset()
    end

    self._time_grade_label:set_opacity(self._time_grade_opacity_animation:get_value())
    self._flow_grade_label:set_opacity(self._flow_grade_opacity_animation:get_value())
    self._coins_grade_label:set_opacity(self._coins_grade_opacity_animation:get_value())
    self._total_grade_label:set_opacity(self._total_grade_opacity_animation:get_value())

    self._shader_fraction = _HIDDEN
    self._shader_fraction_motion:set_value(_HIDDEN)
    self._shader_fraction_motion:set_target_value(_SHOWN)
end

--- @brief
function ow.ResultsScreen:close()
    self._shader_fraction_motion:set_target_value(_HIDDEN)
end

local _draw_grade = function(grade, center_x, center_y, scale)
    love.graphics.push()
    love.graphics.translate(center_x, center_y)
    love.graphics.scale(scale, scale)
    love.graphics.translate(-center_x, -center_y)
    grade:draw()
    love.graphics.pop()
end

--- @brief
function ow.ResultsScreen:draw()
    love.graphics.push()
    love.graphics.translate(self._mesh_offset * self._shader_fraction, 0)

    love.graphics.push()
    _shader:bind()
    _shader:send("fraction", 1 - self._shader_fraction)
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    self._mesh:draw()
    _shader:unbind()
    love.graphics.pop()

    self._title_label:draw(self._title_reveal_animation:get_value() * self._title_label_offset)

    self._time_prefix_label:draw(self._time_prefix_reveal_animation:get_value() * self._time_prefix_offset)
    self._time_value_label:draw(self._time_value_reveal_animation:get_value() * self._time_value_offset)
    _draw_grade(
        self._time_grade_label,
        self._time_grade_center_x, self._time_grade_center_y,
        1 + self._time_grade_scale_animation:get_value() * self._max_scale
    )
    
    self._flow_prefix_label:draw(self._flow_prefix_reveal_animation:get_value() * self._flow_prefix_offset)
    self._flow_value_label:draw(self._flow_value_reveal_animation:get_value() * self._flow_value_offset)
    _draw_grade(
        self._flow_grade_label,
        self._flow_grade_center_x, self._flow_grade_center_y,
        1 + self._flow_grade_scale_animation:get_value() * self._max_scale
    )

    self._coins_prefix_label:draw(self._coins_prefix_reveal_animation:get_value() * self._coins_prefix_offset)
    self._coins_value_label:draw(self._coins_value_reveal_animation:get_value() * self._coins_value_offset)
    _draw_grade(
        self._coins_grade_label,
        self._coins_grade_center_x, self._coins_grade_center_y,
        1 + self._coins_grade_scale_animation:get_value() * self._max_scale
    )

    _draw_grade(
        self._total_grade_label,
        self._total_grade_center_x, self._total_grade_center_y,
        1 + self._total_grade_scale_animation:get_value() * self._max_scale
    )

    love.graphics.pop() -- shader fraction
end

--- @brief
function ow.ResultsScreen:get_is_active()
    return self._shader_fraction_motion:get_target_value() == _SHOWN
end


