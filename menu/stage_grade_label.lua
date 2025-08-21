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
}

--- @class mn.StageGradeLabel
mn.StageGradeLabel = meta.class("StageGradeLabel", rt.Widget)
meta.add_signal(mn.StageGradeLabel, "pulse_done")

local _font, _shader_sdf, _shader_no_sdf

local _atlas = {}

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
        self._input = rt.InputSubscriber()
        self._input:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "l" then
                _shader_sdf:recompile()
                _shader_no_sdf:recompile()
            end
        end)
    end

    if _shader_no_sdf == nil then _shader_no_sdf = rt.Shader("menu/stage_grade_label.glsl", { MODE = 0 }) end
    if _shader_sdf == nil then
        _shader_sdf = rt.Shader("menu/stage_grade_label.glsl", { MODE = 1 })
        _shader_sdf:send("white", { rt.Palette.WHITE:unpack() })
    end

    self._shine_animation = rt.TimedAnimation(
        rt.settings.menu.stage_grade_label.pulse_duration,
        0, 1,
        rt.InterpolationFunctions.LINEAR
    )
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

    love.graphics.draw(self._label_sdf, self._label_x, self._label_y)

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

    love.graphics.draw(self._label_no_sdf, self._label_x, self._label_y)

    _shader_no_sdf:unbind()
end

--- @brief
function mn.StageGradeLabel:measure()
    return _font:measure(self._font_size, self._label_text)
end

--- @brief
function mn.StageGradeLabel:update(delta)
    if self._animation_active == true then
        if self._shine_animation:update(delta) then
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

    local size = _font:get_actual_size(self._font_size)
    if _atlas[size] == nil then _atlas[size] = {} end
    if _atlas[size][self._grade] == nil then
        _atlas[size][self._grade] = {
            sdf = nil,
            no_sdf = nil
        }
    end

    local no_sdf = _atlas[size][self._grade].no_sdf
    if no_sdf == nil then
        no_sdf = love.graphics.newTextBatch(_font:get_native(self._font_size, rt.FontStyle.REGULAR, false), text)
        _atlas[size][self._grade].no_sdf = no_sdf
    end

    local sdf = _atlas[size][self._grade].sdf
    if sdf == nil then
        sdf = love.graphics.newTextBatch(_font:get_native(self._font_size, rt.FontStyle.REGULAR, true), text)
        _atlas[size][self._grade].sdf = sdf
    end

    self._label_no_sdf = no_sdf
    self._label_sdf = sdf
    self._color = rt.Palette[self._grade]
end

--- @brief
function mn.StageGradeLabel:pulse()
    self._animation_active = true
    self._shine_animation:reset()
end

--- @brief
function mn.StageGradeLabel:skip()
    self._pulse_active = false
    self._shine_animation:skip()
    self:signal_emit("pulse_done")
end

--- @brief
function mn.StageGradeLabel:set_opacity(value)
    self._opacity = value
end
