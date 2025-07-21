--- @class mn.StageClearedLabel
mn.StageClearedLabel = meta.class("StageClearedlabel", rt.Widget)

local _STATE_HUNDRED_PERCENTED = 0
local _STATE_CLEARED = 1
local _STATE_NOT_CLEARED = 2

local _font = rt.Font("assets/fonts/RubikSprayPaint/RubikSprayPaint-Regular.ttf")

--- @brief
function mn.StageClearedLabel:instantiate(stage_id)
    meta.assert(stage_id, "String")
    self._stage_id = stage_id

    local cleared_prefix, cleared_postfix = "<o><color=GRAY_3>", "</color></o>"
    local hundred_prefix, hundred_postfix = "<b><o><wave><rainbow>", "</wave></rainbow></o></b>"
    local translation = rt.Translation.menu_scene

    self._cleared_label = rt.Label(cleared_prefix .. translation.cleared_label .. cleared_postfix, rt.FontSize.HUGE, _font)
    self._hundred_percent_label = rt.Label(hundred_prefix .. translation.hundred_percent_label .. hundred_postfix, rt.FontSize.HUGE, _font)

    if rt.GameState:get_stage_is_hundred_percented(stage_id) then
        self._state = _STATE_HUNDRED_PERCENTED
    elseif rt.GameState:get_stage_was_cleared(stage_id) then
        self._state = _STATE_CLEARED
    else
        self._state = _STATE_NOT_CLEARED
    end
    
    self._cleared_x, self._cleared_y, self._cleared_angle = 0, 0, 0
    self._hundred_percent_x, self._hundred_percent_y, self._hundred_percent_angle = 0, 0, 0
end

--- @brief
function mn.StageClearedLabel:create_from_state()
    if rt.GameState:get_stage_is_hundred_percented(self._stage_id) then
        self._state = _STATE_HUNDRED_PERCENTED
    elseif rt.GameState:get_stage_was_cleared(self._stage_id) then
        self._state = _STATE_CLEARED
    else
        self._state = _STATE_NOT_CLEARED
    end
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
    if self._state == _STATE_HUNDRED_PERCENTED then
        self._hundred_percent_label:update(delta)
    elseif self._state == _STATE_CLEARED then
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
    if self._state == _STATE_HUNDRED_PERCENTED then
        love.graphics.push()
        love.graphics.translate(self._hundred_percent_x, self._hundred_percent_y)
        love.graphics.rotate(self._hundred_percent_angle)
        self._hundred_percent_label:draw()
        love.graphics.translate(-self._hundred_percent_x, -self._hundred_percent_y)
        love.graphics.pop()
    elseif self._state == _STATE_CLEARED then
        love.graphics.push()
        love.graphics.translate(self._cleared_x, self._cleared_y)
        love.graphics.rotate(self._cleared_angle)
        self._cleared_label:draw()
        love.graphics.translate(-self._cleared_x, -self._cleared_y)
        love.graphics.pop()
    end
end