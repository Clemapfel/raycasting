--- @class mn.StageClearedLabel
mn.StageClearedLabel = meta.class("StageClearedlabel", rt.Widget)

--- @class mn.StageClearedState
mn.StageClearedState = meta.enum("StageClearedState", {
    NOT_CLEARED = 0,
    CLEARED = 1,
    HUNDRED_PERCENTED = 2
})

local _font = rt.Font("assets/fonts/RubikSprayPaint/RubikSprayPaint-Regular.ttf")

--- @brief
function mn.StageClearedLabel:instantiate()
    local cleared_prefix, cleared_postfix = "<o><color=GRAY_3>", "</color></o>"
    local hundred_prefix, hundred_postfix = "<b><o><wave><rainbow>", "</wave></rainbow></o></b>"
    local translation = rt.Translation.menu_scene

    self._cleared_label = rt.Label(cleared_prefix .. translation.cleared_label .. cleared_postfix, rt.FontSize.HUGE, _font)
    self._hundred_percent_label = rt.Label(hundred_prefix .. translation.hundred_percent_label .. hundred_postfix, rt.FontSize.HUGE, _font)

    self._state = mn.StageClearedState.NOT_CLEARED
    self._cleared_x, self._cleared_y, self._cleared_angle = 0, 0, 0
    self._hundred_percent_x, self._hundred_percent_y, self._hundred_percent_angle = 0, 0, 0
end

--- @brief
function mn.StageClearedLabel:set_state(stage_cleared_state)
    meta.assert_enum_value(stage_cleared_state, mn.StageClearedState)
    self._state = stage_cleared_state
end

--- @brief
function mn.StageClearedLabel:realize()
    for widget in range(
        self._cleared_label,
        self._hundred_percent_label
    ) do
        widget:realize()
    end
end

--- @brief
function mn.StageClearedLabel:update(delta)
    if self._state == mn.StageClearedState.HUNDRED_PERCENTED then
        self._hundred_percent_label:update(delta)
    elseif self._state == mn.StageClearedState.CLEARED then
        self._cleared_label:update(delta)
    end
end

--- @brief
function mn.StageClearedLabel:size_allocate(x, y, width, height)
    local cleared_w, cleared_h = self._cleared_label:measure()
    self._cleared_label:reformat(-0.5 * cleared_w, -0.5 * cleared_h, math.huge, math.huge)
    self._cleared_x, self._cleared_y = x + 0.5 * width, y + 0.5 * height
    self._cleared_angle = math.degrees_to_radians(45)

    local hundred_percent_w, hundred_percent_h = self._hundred_percent_label:measure()
    self._hundred_percent_label:reformat(-0.5 * hundred_percent_w, -0.5 * hundred_percent_h, math.huge, math.huge)
    self._hundred_percent_x, self._hundred_percent_y = x + 0.5 * width, y + 0.5 * height
    self._hundred_percent_angle = math.degrees_to_radians(45)
end

--- @brief
function mn.StageClearedLabel:draw()
    if self._state == mn.StageClearedState.HUNDRED_PERCENTED then
        love.graphics.push()
        love.graphics.translate(self._hundred_percent_x, self._hundred_percent_y)
        love.graphics.rotate(self._hundred_percent_angle)
        self._hundred_percent_label:draw()
        love.graphics.translate(-self._hundred_percent_x, -self._hundred_percent_y)
        love.graphics.pop()
    elseif self._state == mn.StageClearedState.CLEARED then
        love.graphics.push()
        love.graphics.translate(self._cleared_x, self._cleared_y)
        love.graphics.rotate(self._cleared_angle)
        self._cleared_label:draw()
        love.graphics.translate(-self._cleared_x, -self._cleared_y)
        love.graphics.pop()
    end
end