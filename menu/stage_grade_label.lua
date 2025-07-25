require "common.stage_grade"
require "common.font"
require "common.palette"
require "common.translation"

rt.settings.menu.stage_grade_label = {
    --font_path = "assets/fonts/RubikSprayPaint/RubikSprayPaint-Regular.ttf",
    --font_path = "assets/fonts/Bowlby_One_SC/Bowlby_One",
    font_id = "RubikSprayPaint",
    --font_id = "RubikSprayPaint"

    pulse_duration = 2,
    max_scale = 1.5
}

--- @class mn.StageGradeLabel
mn.StageGradeLabel = meta.class("StageGradeLabel", rt.Widget)

local _font, _shader_sdf, _shader_no_sdf

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

    self._pulse_active = false
    self._pulse_elapsed = 0
    self._pulse_fraction = math.huge
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
--- @brief
function mn.StageGradeLabel:draw()
    local label_cx = self._label_x + 0.5 * self._label_w
    local label_cy = self._label_y + 0.5 * self._label_h
    local scale = math.mix(
        1,
        rt.settings.menu.stage_grade_label.max_scale,
        rt.InterpolationFunctions.ENVELOPE(self._pulse_fraction, 0.2, 0.4)
    )

    -- SDF shader
    _shader_sdf:bind()
    if self._pulse_active then
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
    _shader_no_sdf:send("elapsed", rt.SceneManager:get_elapsed() + meta.hash(self)) -- prevent synching of shader
    _shader_no_sdf:send("use_highlight",
        self._grade == rt.StageGrade.A or
            self._grade == rt.StageGrade.B or
            self._grade == rt.StageGrade.C
    )
    _shader_no_sdf:send("use_rainbow",
        self._grade == rt.StageGrade.S
    )
    _shader_no_sdf:send("fraction", self._pulse_fraction)

    self._color:bind()

    if self._pulse_active then
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
    if self._pulse_active == true then
        self._pulse_elapsed = self._pulse_elapsed + delta
        self._pulse_fraction = math.min(self._pulse_elapsed / rt.settings.menu.stage_grade_label.pulse_duration, 1)
        if self._pulse_fraction >= 1 then
            self._pulse_active = false
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
    self._label_no_sdf = love.graphics.newTextBatch(_font:get_native(self._font_size, rt.FontStyle.REGULAR, false), text)
    self._label_sdf = love.graphics.newTextBatch(_font:get_native(self._font_size, rt.FontStyle.REGULAR, true), text)
    self._color = rt.Palette[self._grade]
end

--- @brief
function mn.StageGradeLabel:pulse()
    self._pulse_elapsed = 0
    self._pulse_fraction = 0
    self._pulse_active = true
end

--- @brief
function mn.StageGradeLabel:skip()
    self._pulse_elapsed = math.huge
    self._pulse_fraction = 1
    self._pulse_active = false
end
