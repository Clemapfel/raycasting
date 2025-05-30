require "common.label"
require "common.translation"

--- @class mn.TextSpeedVisualizationWidget
mn.TextSpeedVisualizationWidget = meta.class("TextSpeedVisualizationWidget", rt.Widget)

--- @brief
function mn.TextSpeedVisualizationWidget:instantiate()
    self._label = rt.Label("<o>" .. rt.Translation.verbose_info.text_speed_visualization_text .. "</o>")
    self._label:set_justify_mode(rt.JustifyMode.LEFT)
    self._elapsed = 0
    self._direction = 1
    self._last_text_speed = rt.GameState:get_text_speed()
end

--- @brief
function mn.TextSpeedVisualizationWidget:realize()
    self._label:realize()
end

--- @brief
function mn.TextSpeedVisualizationWidget:size_allocate(x, y, width, height)
    local m = 2 * rt.settings.margin_unit
    self._label:reformat(0, 0, width, height)
    local w, h = self._label:measure()
    self._label:reformat(x, y, width, height)
    self._elapsed = 0
    self._label:update_n_visible_characters_from_elapsed(self._elapsed)
end

--- @brief
function mn.TextSpeedVisualizationWidget:update(delta)
    if self._last_text_speed ~= rt.GameState:get_text_speed() then
        self._elapsed = 0
        self._last_text_speed = rt.GameState:get_text_speed()
    end

    self._elapsed = math.max(self._elapsed + self._direction * delta, 0)
    local is_done = self._label:update_n_visible_characters_from_elapsed(self._elapsed) -- uses states scroll speed
    if self._direction == 1 and is_done then self._direction = -1 end
    if self._direction == -1 and self._elapsed == 0 then self._direction = 1 end
end

--- @brief
function mn.TextSpeedVisualizationWidget:draw()
    self._label:draw()
end

--- @brief
function mn.TextSpeedVisualizationWidget:measure()
    return self._label:measure()
end