require "common.stage_grade"
require "common.font"
require "common.palette"
require "common.translation"
require "common.timed_animation"

rt.settings.menu.stage_grade_label = {
    --font_path = "assets/fonts/RubikSprayPaint/RubikSprayPaint-Regular.ttf",
    --font_path = "assets/fonts/Bowlby_One_SC/Bowlby_One",
    font_id = "RubikSprayPaint",
    --font_id = "RubikSprayPaint"

    pulse_duration = 2, -- seconds
    pulse_shine_fraction = 0.25, -- how long letter stays scaled, fraction
    max_scale = 1.5
}

--- @class mn.StageGradeLabel
mn.StageGradeLabel = meta.class("StageGradeLabel", rt.Widget)
meta.add_signal(mn.StageGradeLabel, "pulse_done")

local _font, _shader_sdf, _shader_no_sdf

local _atlas = {}
do -- caches love.TextBatches
    for size in values(meta.instances(rt.FontSize)) do
        local row = _atlas[size]
        if row == nil then
            row = {}
            _atlas[size] = row
        end

        for grade in values(meta.instances(rt.StageGrade)) do
            local entry = row[grade]
            if entry == nil then
                entry = {
                    sdf = nil,
                    no_sdf = nil
                }
                row[grade] = entry
            end
        end
    end
end

--- @brief
function mn.StageGradeLabel:instantiate(grade, size)
    meta.assert_enum_value(grade, rt.StageGrade, 1)
    meta.assert_enum_value(size, rt.FontSize)

    self._grade = grade
    self._font_size = size
    self._label_no_sdf = nil
    self._label_sdf = nil
    self._label_text = ""
    self._label_x, self._label_y, self._label_w, self._label_h = 0, 0, 0, 0
    self._color = rt.Palette.WHITE
    self._last_window_height = love.graphics.getHeight()

    self._opacity = 1

    if _font == nil then
        local id = rt.settings.menu.stage_grade_label.font_id
        _font = rt.Font("assets/fonts/" .. id .. "/" .. id .. "-Regular.ttf")
        --_font = rt.Font(rt.settings.menu.stage_grade_label.font_path)
    end
    if _shader_no_sdf == nil then _shader_no_sdf = rt.Shader("menu/stage_grade_label.glsl", { MODE = 0 }) end
    if _shader_sdf == nil then
        _shader_sdf = rt.Shader("menu/stage_grade_label.glsl", { MODE = 1 })
        _shader_sdf:send("white", { rt.Palette.WHITE:unpack() })
    end

    -- animation: scale to max, then start shine, wait for shine to finish before scaling back

    local total_duration = rt.settings.menu.stage_grade_label.pulse_duration
    local scale_attack = 0.25
    local scale_sustain = rt.settings.menu.stage_grade_label.pulse_shine_fraction
    self._shine_animation = rt.TimedAnimation(
        scale_sustain * total_duration,
        0, 1,
        rt.InterpolationFunctions.LINEAR
    )

    self._scale_animation = rt.TimedAnimation(
        total_duration,
        1, rt.settings.menu.stage_grade_label.max_scale,
        rt.InterpolationFunctions.ENVELOPE, scale_attack, scale_sustain
    )
    
    self._shine_delay = scale_attack
    self._animation_active = false
end

--- @brief
function mn.StageGradeLabel:realize()
    if self:already_realized() then return end
    self:_update_labels()
end

--- @brief
function mn.StageGradeLabel:size_allocate(x, y, width, height)
    local label_w, label_h = _font:measure(self._font_size, self._label_text)
    self._label_x = x-- + 0.5 * width - 0.5 * label_w
    self._label_y = y-- + 0.5 * width - 0.5 * label_h
    self._label_x, self._label_y = math.floor(self._label_x), math.floor(self._label_y)
    self._label_w, self._label_h = label_w, label_h
    if self._last_window_height ~= love.graphics.getHeight() then
        self:_update_labels()
        self._last_window_height = love.graphics.getHeight()
    end
end

--- @brief
function mn.StageGradeLabel:draw()
    if self._opacity == 0 then return end

    local label_cx = self._label_x + 0.5 * self._label_w
    local label_cy = self._label_y + 0.5 * self._label_h

    -- SDF shader
    _shader_sdf:bind()
    _shader_sdf:send("opacity", self._opacity)

    if self._animation_active then
        local scale = self._scale_animation:get_value()
        love.graphics.push()
        love.graphics.translate(label_cx, label_cy)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-label_cx, -label_cy)
        love.graphics.draw(self._label_sdf, self._label_x, self._label_y)
        love.graphics.pop()
    else
        love.graphics.draw(self._label_sdf, self._label_x, self._label_y)
    end

    _shader_sdf:unbind()

    -- Non-SDF shader
    _shader_no_sdf:bind()
    _shader_no_sdf:send("opacity", self._opacity)
    _shader_no_sdf:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self)) -- prevent synching of shader
    _shader_no_sdf:send("use_highlight",
        self._grade == rt.StageGrade.A or
            self._grade == rt.StageGrade.B or
            self._grade == rt.StageGrade.C
    )
    _shader_no_sdf:send("use_rainbow",
        self._grade == rt.StageGrade.S
    )

    if self._animation_active then
        _shader_no_sdf:send("fraction", self._shine_animation:get_value())
    else
        _shader_no_sdf:send("fraction", math.huge)
    end

    self._color:bind()

    if self._animation_active then
        local scale = self._scale_animation:get_value()
        love.graphics.push()
        love.graphics.translate(label_cx, label_cy)
        love.graphics.scale(scale, scale)
        love.graphics.translate(-label_cx, -label_cy)
        love.graphics.draw(self._label_no_sdf, self._label_x, self._label_y)
        love.graphics.pop()
    else
        love.graphics.draw(self._label_no_sdf, self._label_x, self._label_y)
    end

    _shader_no_sdf:unbind()
end

--- @brief
function mn.StageGradeLabel:measure()
    return _font:measure(self._font_size, self._label_text)
end

--- @brief
function mn.StageGradeLabel:update(delta)
    if self._animation_active == true then
        self._scale_animation:update(delta)

        local fraction = self._scale_animation:get_elapsed() / self._scale_animation:get_duration()
        if fraction > self._shine_delay then
            self._shine_animation:update(delta)
        end

        if self._scale_animation:get_is_done() and self._shine_animation:get_is_done() then
            if self._animation_active then
                self._animation_active = false
                self:signal_emit("pulse_done")
            end
        end
    end
end

--- @brief
function mn.StageGradeLabel:set_grade(grade)
    meta.assert_enum_value(grade, rt.StageGrade, 1)

    if self._grade ~= grade then
        self._grade = grade
        self:_update_labels()
    end
end

--- @brief
function mn.StageGradeLabel:get_grade()
    return self._grade
end

--- @brief
function mn.StageGradeLabel:set_font_size(size)
    meta.assert_enum_value(size, rt.FontSize, 1)

    if self._font_size ~= size then
        self._font_size = size
        self:_update_labels()
    end
end

--- @brief
function mn.StageGradeLabel:get_font_size()
    return self._font_size
end

--- @brief
function mn.StageGradeLabel:_update_labels()
    local text = rt.Translation.stage_grade_to_string(self._grade)
    self._label_text = text

    local no_sdf = _atlas[self._font_size][self._grade].no_sdf
    if no_sdf == nil then
        no_sdf = love.graphics.newTextBatch(_font:get_native(self._font_size, rt.FontStyle.REGULAR, false), text)
        _atlas[self._font_size][self._grade].no_sdf = no_sdf
    end

    local sdf = _atlas[self._font_size][self._grade].sdf
    if sdf == nil then
        sdf = love.graphics.newTextBatch(_font:get_native(self._font_size, rt.FontStyle.REGULAR, true), text)
        _atlas[self._font_size][self._grade].sdf = sdf

    end

    self._label_no_sdf = no_sdf
    self._label_sdf = sdf
    self._color = rt.Palette[self._grade]
end

--- @brief
function mn.StageGradeLabel:pulse()
    self._animation_active = true
    self._shine_animation:reset()
    self._scale_animation:reset()
end

--- @brief
function mn.StageGradeLabel:skip()
    self._pulse_active = false
    self._shine_animation:skip()
    self._scale_animation:skip()
end

--- @brief
function mn.StageGradeLabel:set_opacity(value)
    self._opacity = value
end
