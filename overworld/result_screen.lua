require "common.smoothed_motion_1d"
require "menu.stage_grade_label"
require "common.translation"
require "common.label"

rt.settings.overworld.result_screen = {
    fraction_motion_duration = 2, -- total duration of reveal / hide, seconds
    fraction_motion_ramp = 10, -- how fast motion approaches target
    slope = 0.3, -- how diagonal shape is

    flow_step = 1 / 100, -- fraction
    time_step = 1, -- seconds
    coins_step = 1, -- count

    roll_animation_duration = 1.0, -- seconds
    reveal_animation_duration = 1.0,
    scale_animation_duration = 1.0,
    max_scale = 3
}

--- @class ow.ResultScreen
ow.ResultsScreen = meta.class("ResultScreen", rt.Widget)

local _shader
local _title_font = rt.Font(
    "assets/fonts/Baloo2/Baloo2-SemiBold.ttf",
    "assets/fonts/Baloo2/Baloo2-Bold.ttf"
)

local _HIDDEN, _SHOWN, _CLOSED = 0, 1, 2

local _STATE_IDLE = -1
local _STATE_REVEALING = 0
local _STATE_TITLE = 1
local _STATE_TIME = 2
local _STATE_FLOW = 3
local _STATE_COINS = 4
local _STATE_TOTAL = 5
local _STATE_WAITING_FOR_EXIT = 6

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

    self._state = _STATE_IDLE

    -- config
    self._title = "NO TITLE"
    self._flow_target = 0
    self._flow_start = 0

    self._time_target = 0 -- seconds
    self._time_start = 0

    self._coins_target = 0 -- integer
    self._coins_start = 0
    self._coins_max = 0

    self._flow_grade = rt.StageGrade.NONE
    self._time_grade = rt.StageGrade.NONE
    self._coins_grade = rt.StageGrade.NONE
    self._total_grade = rt.StageGrade.NONE

    self._title_label = rt.Label("<b><o><u>" .. self._title .. "</b></o></u>", rt.FontSize.BIG, _title_font)

    local prefix, postfix = "<b><o>", "</b></o>"
    self._flow_prefix_label = rt.Label(prefix .. translation.flow .. postfix)
    self._time_prefix_label = rt.Label(prefix .. translation.time .. postfix)
    self._coins_prefix_label = rt.Label(prefix .. translation.coins .. postfix)

    local glyph_properties = {
        font_size = rt.FontSize.REGULAR,
        justify_mode = rt.JustifyMode.CENTER,
        style = rt.FontStyle.BOLD,
        is_outlined = true,
        font = _title_font
    }

    self._time_value_label = rt.Glyph(_format_time(0, 0, self._time_start), glyph_properties)
    self._flow_value_label = rt.Glyph(_format_flow(0, 0, self._flow_start), glyph_properties)
    self._coins_value_label = rt.Glyph(_format_coins(0, 0, self._coins_start, 0), glyph_properties)

    self._flow_grade_label = mn.StageGradeLabel(self._flow_grade, rt.FontSize.HUGE)
    self._time_grade_label = mn.StageGradeLabel(self._time_grade, rt.FontSize.HUGE)
    self._coins_grade_label = mn.StageGradeLabel(self._coins_grade, rt.FontSize.HUGE)
    self._total_grade_label = mn.StageGradeLabel(self._total_grade, rt.FontSize.GIGANTIC)

    -- animation

    local _new_reveal_animation = function()
        return rt.TimedAnimation(
            settings.reveal_animation_duration,
            _SHOWN, _HIDDEN,
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
    self._time_offset = 0 -- max offset
    self._time_grade_center_x = 0
    self._time_grade_center_y = 0
    self._waiting_for_time_grade = false
    self._time_grade_connected = false

    self._flow_prefix_reveal_animation = _new_reveal_animation()
    self._flow_value_reveal_animation = _new_reveal_animation()
    self._flow_value_roll_animation = _new_roll_animation()
    self._flow_grade_scale_animation = _new_scale_animation()
    self._flow_grade_opacity_animation = _new_opacity_animation()
    self._flow_offset = 0
    self._flow_grade_center_x = 0
    self._flow_grade_center_y = 0
    self._waiting_for_flow_grade = false
    self._flow_grade_connected = false

    self._coins_prefix_reveal_animation = _new_reveal_animation()
    self._coins_value_reveal_animation = _new_reveal_animation()
    self._coins_value_roll_animation = _new_roll_animation()
    self._coins_grade_scale_animation = _new_scale_animation()
    self._coins_grade_opacity_animation = _new_opacity_animation()
    self._coins_offset = 0
    self._coins_grade_center_x = 0
    self._coins_grade_center_y = 0
    self._waiting_for_coins_grade = false
    self._coins_grade_connected = false

    self._total_grade_scale_animation = _new_scale_animation()
    self._total_grade_opacity_animation = _new_opacity_animation()
    self._total_grade_center_x = 0
    self._total_grade_center_y = 0
    self._waiting_for_total_grade = false
    self._total_grade_connected = false

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
    local mesh_x, mesh_w = x, width
    local mesh_overfill = love.graphics.getWidth()

    local padding = 0
    local mesh_y = y - padding
    local mesh_h = height + 2 * padding
    local ratio = (mesh_w / (mesh_w + mesh_overfill)) * 2

    do
        local left = function() return 1, 1, 1, 1 end
        local right = function() return  0, 0, 0, 1  end

        local a = { mesh_x,                          mesh_y, 0, 0, left(0) }
        local b = { mesh_x + mesh_w,                 mesh_y, ratio, 0, right(0) }
        local c = { mesh_x + mesh_w + mesh_overfill, mesh_y, 2, 0, right(0) } -- sic, uv.x = 2 used for noise generation
        local d = { mesh_x,                          mesh_y + mesh_h, 0, 1, left(1) }
        local e = { mesh_x + mesh_w,                 mesh_y + mesh_h, ratio, 1, right(1) }
        local f = { mesh_x + mesh_w + mesh_overfill, mesh_y + mesh_h, 2, 1, right(1) }

        self._mesh = rt.Mesh({ a, b, c, d, e, f }, rt.MeshDrawMode.TRIANGLES)

        a, b, c, d, e, f = 1, 2, 3, 4, 5, 6
        self._mesh:set_vertex_map(
            a, b, d,
            b, d, e,
            b, c, e,
            c, e, f
        )

        self._mesh_inner_offset = mesh_w
        self._mesh_outer_offset = 2 * mesh_w
    end

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

        return prefix_offset, grade_x + 0.5 * grade_w, grade_y + 0.5 * grade_h
    end

    self._time_offset, self._time_grade_center_x, self._time_grade_center_y = _reformat(self._time_prefix_label, self._time_value_label, self._time_grade_label)
    self._flow_offset, self._flow_grade_center_x, self._flow_grade_center_y = _reformat(self._flow_prefix_label, self._flow_value_label, self._flow_grade_label)
    self._coins_offset, self._coins_grade_center_x, self._coins_grade_center_y = _reformat(self._coins_prefix_label, self._coins_value_label, self._coins_grade_label)

    local total_w, total_h = self._total_grade_label:measure()
    local total_x, total_y = x + 0.5 * width - 0.5 * total_w, current_y
    self._total_grade_label:reformat(total_x, total_y, total_w, total_h)
    self._total_grade_center_x, self._total_grade_center_y =  total_x + 0.5 * total_w, total_y + 0.5 * total_h
end

-- update aux

local function _update_label(label, value)
    local x, y = label:get_position()
    local w, h = label:measure()
    label:set_text(value)

    if label:get_is_realized() then
        local new_w, new_h = label:measure()
        label:reformat(x + w - new_w, y)
    end

    return select(1, label:get_position())
end

local _eps = 0.01


--- @brief
function ow.ResultsScreen:update(delta)
    if self._state > _STATE_IDLE then
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
            widget:update(delta)
        end
    end

    -- sequencing of animations, jump early if that part of the queue is not yet done
    local furthest_state = ternary(self:get_is_active(), _STATE_IDLE, _STATE_REVEALING)

    while true do -- while true loop used instead of gotos, because of local scope, always exits after 1 iteration

        self._shader_fraction = self._shader_fraction_motion:update(delta)
        if self._waiting_for_close then break end

        furthest_state = _STATE_TITLE

        if not self._title_reveal_animation:update(delta) then break end
        if not math.equals(self._shader_fraction, _SHOWN, _eps) then break end

        -- time

        furthest_state = _STATE_TIME

        if not math.nand(
            self._time_prefix_reveal_animation:update(delta),
            self._time_value_reveal_animation:update(delta)
        )
        then break end

        local time_value_roll_is_done = self._time_value_roll_animation:update(delta)
        _update_label(self._time_value_label, _format_time(self._time_value_roll_animation:get_value(), 0, self._time_target))

        if not time_value_roll_is_done then break end

        local time_opacity_is_done = self._time_grade_opacity_animation:update(delta)
        local time_scale_is_done = self._time_grade_scale_animation:update(delta)

        self._time_grade_label:set_opacity(self._time_grade_opacity_animation:get_value())

        if not (time_opacity_is_done and time_scale_is_done) then break end

        if self._time_grade_connected == false then
            self._time_grade_label:pulse()
            self._time_grade_label:signal_connect("pulse_done", function()
                self._waiting_for_time_grade = false
                return meta.DISCONNECT_SIGNAL
            end)
            self._time_grade_connected = true
        end
        if self._waiting_for_time_grade ~= false then break end

        -- flow

        furthest_state = _STATE_FLOW

        if not math.nand(
            self._flow_prefix_reveal_animation:update(delta),
            self._flow_value_reveal_animation:update(delta)
        ) then break end

        local flow_value_roll_is_done = self._flow_value_roll_animation:update(delta)
        _update_label(self._flow_value_label, _format_flow(
            self._flow_value_reveal_animation:get_value(),
            0, self._flow_target
        ))

        if not flow_value_roll_is_done then break end

        local flow_opacity_is_done = self._flow_grade_opacity_animation:update(delta)
        local flow_scale_is_done = self._flow_grade_scale_animation:update(delta)

        self._flow_grade_label:set_opacity(self._flow_grade_opacity_animation:get_value())

        if not (flow_opacity_is_done and flow_scale_is_done) then break end

        if self._flow_grade_connected == false then
            self._flow_grade_label:pulse()
            self._flow_grade_label:signal_connect("pulse_done", function()
                self._waiting_for_flow_grade = false
                return meta.DISCONNECT_SIGNAL
            end)
            self._flow_grade_connected = true
        end
        if self._waiting_for_flow_grade ~= false then break end

        -- coins

        furthest_state = _STATE_COINS

        if not math.nand(
            self._coins_prefix_reveal_animation:update(delta),
            self._coins_value_reveal_animation:update(delta)
        ) then break end

        local coins_value_roll_is_done = self._coins_value_roll_animation:update(delta)
        _update_label(self._coins_value_label, _format_coins(
            self._coins_value_roll_animation:get_value(),
            0, self._coins_target,
            self._coins_max
        ))

        if not coins_value_roll_is_done then break end

        local coins_opacity_is_done = self._coins_grade_opacity_animation:update(delta)
        local coins_scale_is_done = self._coins_grade_scale_animation:update(delta)

        self._coins_grade_label:set_opacity(self._coins_grade_opacity_animation:get_value())

        if not (coins_opacity_is_done and coins_scale_is_done) then break end

        if self._coins_grade_connected == false then
            self._coins_grade_label:pulse()
            self._coins_grade_label:signal_connect("pulse_done", function()
                self._waiting_for_coins_grade = false
                return meta.DISCONNECT_SIGNAL
            end)
            self._coins_grade_connected = true
        end
        if self._waiting_for_coins_grade ~= false then break end

        -- total

        furthest_state = _STATE_TOTAL

        local total_opacity_is_done = self._total_grade_opacity_animation:update(delta)
        local total_scale_is_done = self._total_grade_scale_animation:update(delta)

        self._total_grade_label:set_opacity(self._total_grade_opacity_animation:get_value())

        if not (total_opacity_is_done and total_scale_is_done) then break end

        if self._total_grade_connected == false then
            self._total_grade_label:pulse()
            self._total_grade_label:signal_connect("pulse_done", function()
                self._waiting_for_total_grade = false
                return meta.DISCONNECT_SIGNAL
            end)
            self._total_grade_connected = true
        end
        if self._waiting_for_total_grade ~= false then break end

        -- done, wait for user input

        furthest_state = _STATE_WAITING_FOR_EXIT
        self._waiting_for_close = true

    break end -- while true

    self._state = furthest_state
end

--- @brief
function ow.ResultsScreen:_reset()
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

    self._waiting_for_time_grade = true
    self._time_grade_connected = false
    self._waiting_for_flow_grade = true
    self._flow_grade_connected = false
    self._waiting_for_coins_grade = true
    self._coins_grade_connected = false
    self._waiting_for_total_grade = true
    self._total_grade_connected = false
    self._waiting_for_close = false

    self._state = _STATE_REVEALING
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
    self._time_grade_label:set_grade(time_grade)

    self._flow_target = flow
    self._flow_start = 0
    self._flow_grade_label:set_grade(flow_grade)

    self._coins_max = max_n_coins
    self._coins_target = n_coins
    self._coins_start = 0
    self._coins_grade_label:set_grade(time_grade)

    self:_reset()
    self._shader_fraction_motion:set_target_value(_SHOWN)
    self._state = _STATE_REVEALING

    -- TODO
    _shader:recompile()
end

--- @brief
function ow.ResultsScreen:close()
    for animation in range(
        self._title_reveal_animation,

        self._time_prefix_reveal_animation,
        self._time_value_reveal_animation,
        self._time_value_roll_animation,
        self._time_grade_scale_animation,
        self._time_grade_opacity_animation,
        self._time_grade_label,

        self._flow_prefix_reveal_animation,
        self._flow_value_reveal_animation,
        self._flow_value_roll_animation,
        self._flow_grade_scale_animation,
        self._flow_grade_opacity_animation,
        self._flow_grade_label,

        self._coins_prefix_reveal_animation,
        self._coins_value_reveal_animation,
        self._coins_value_roll_animation,
        self._coins_grade_scale_animation,
        self._coins_grade_opacity_animation,
        self._coins_grade_label,

        self._total_grade_scale_animation,
        self._total_grade_opacity_animation
    ) do
        animation:skip()
    end

    self._shader_fraction_motion:set_target_value(_CLOSED)
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

    -- 0-1: use inner offset, 1-2: add outer offset
    local offset = 0
    local fraction = 0
    if self._shader_fraction <= 1 then
        offset = self._shader_fraction * self._mesh_inner_offset
        fraction = self._shader_fraction
    else
        offset = self._mesh_inner_offset + (self._shader_fraction - 1) * self._mesh_outer_offset
        fraction = 1
    end

    local left_x = self._mesh_inner_offset
    love.graphics.translate(left_x - offset, 0)

    love.graphics.push()
    _shader:bind()
    _shader:send("black", { rt.Palette.BLACK:unpack() })
    _shader:send("fraction", fraction)
    _shader:send("elapsed", rt.SceneManager:get_elapsed())
    love.graphics.setColor(1, 1, 1, 1)
    self._mesh:draw()
    _shader:unbind()
    love.graphics.pop()

    self._title_label:draw(self._title_reveal_animation:get_value() * self._title_label_offset)

    self._time_prefix_label:draw(self._time_prefix_reveal_animation:get_value() * self._time_offset)
    self._time_value_label:draw(self._time_value_reveal_animation:get_value() * self._time_offset)
    _draw_grade(
        self._time_grade_label,
        self._time_grade_center_x, self._time_grade_center_y,
        1 + self._time_grade_scale_animation:get_value() * self._max_scale
    )
    
    self._flow_prefix_label:draw(self._flow_prefix_reveal_animation:get_value() * self._flow_offset)
    self._flow_value_label:draw(self._flow_value_reveal_animation:get_value() * self._flow_offset)
    _draw_grade(
        self._flow_grade_label,
        self._flow_grade_center_x, self._flow_grade_center_y,
        1 + self._flow_grade_scale_animation:get_value() * self._max_scale
    )

    self._coins_prefix_label:draw(self._coins_prefix_reveal_animation:get_value() * self._coins_offset)
    self._coins_value_label:draw(self._coins_value_reveal_animation:get_value() * self._coins_offset)
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

--- @brief
--- @brief
function ow.ResultsScreen:skip()
    -- Helper to skip all animations for a section
    local function skip_section(which)
        self["_" .. which .. "_prefix_reveal_animation"]:skip()
        self["_" .. which .. "_value_reveal_animation"]:skip()
        self["_" .. which .. "_value_roll_animation"]:skip()
        self["_" .. which .. "_grade_scale_animation"]:skip()
        self["_" .. which .. "_grade_opacity_animation"]:skip()
        self["_" .. which .. "_grade_connected"] = true
        self["_waiting_for_" .. which .. "_grade"] = false

        local grade = self["_" .. which .. "_grade_label"]
        grade:signal_disconnect_all()
        grade:set_opacity(1)
        grade:skip()
    end

    -- Skip logic: only skip to the NEXT state, not all future states
    if self._state <= _STATE_TITLE then
        self._shader_fraction_motion:skip()
        self._title_reveal_animation:skip()
    elseif self._state == _STATE_TIME then
        skip_section("time")
    elseif self._state == _STATE_FLOW then
        skip_section("flow")
    elseif self._state == _STATE_COINS then
        skip_section("coins")
    elseif self._state == _STATE_TOTAL then
        self._total_grade_scale_animation:skip()
        self._total_grade_opacity_animation:skip()
        self._total_grade_label:skip()
        self._total_grade_label:signal_disconnect_all()
        self._total_grade_label:set_opacity(1)
        self._waiting_for_total_grade = false
        self._total_grade_connected = true
    end

    -- Force update to advance state machine and update visuals
    self:update(0)
end


