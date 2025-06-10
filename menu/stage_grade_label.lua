require "common.stage_grade"
require "common.font"
require "common.palette"
require "common.translation"

rt.settings.menu.stage_grade_label = {
    font_path = "assets/fonts/RubikSprayPaint/RubikSprayPaint-Regular.ttf",
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
    self._label_x, self._label_y = 0, 0
    self._color = rt.Palette.WHITE
    self._elapsed = 0

    if _font == nil then _font = rt.Font(rt.settings.menu.stage_grade_label.font_path) end
    if _shader_no_sdf == nil then _shader_no_sdf = rt.Shader("menu/stage_grade_label.glsl", { MODE = 0 }) end
    if _shader_sdf == nil then
        _shader_sdf = rt.Shader("menu/stage_grade_label.glsl", { MODE = 1 })
        _shader_sdf:send("white", { rt.Palette.WHITE:unpack() })
    end

    -- TODO
    self._input = rt.InputSubscriber()
    self._input:signal_connect("keyboard_key_pressed", function(_, which)
        if which == "h" then
            _shader_no_sdf:recompile()
            _shader_sdf:recompile()
            _shader_sdf:send("white", { rt.Palette.WHITE:unpack() })
        end
    end)
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
end

--- @brief
function mn.StageGradeLabel:draw()
    _shader_sdf:bind()
    love.graphics.draw(self._label_sdf, self._label_x, self._label_y)
    _shader_sdf:unbind()

    _shader_no_sdf:bind()
    _shader_no_sdf:send("elapsed", self._elapsed)
    _shader_no_sdf:send("use_highlight",
        self._grade == rt.StageGrade.S or
        self._grade == rt.StageGrade.A or
        self._grade == rt.StageGrade.B
    )

    _shader_no_sdf:send("use_rainbow",
        self._grade == rt.StageGrade.SS
    )
    self._color:bind()
    love.graphics.draw(self._label_no_sdf, self._label_x, self._label_y)
    _shader_no_sdf:unbind()
end

--- @brief
function mn.StageGradeLabel:measure()
    return _font:measure(self._font_size, self._label_text)
end

--- @brief
function mn.StageGradeLabel:update(delta)
    self._elapsed = self._elapsed + delta
end

--- @brief
function mn.StageGradeLabel:_update_labels()
    local text = rt.Translation.stage_grade_to_string(self._grade)
    self._label_text = text
    self._label_no_sdf = love.graphics.newTextBatch(_font:get_native(self._font_size, rt.FontStyle.REGULAR, false), text)
    self._label_sdf = love.graphics.newTextBatch(_font:get_native(self._font_size, rt.FontStyle.REGULAR, true), text)
    self._color = rt.Palette[self._grade]
end
