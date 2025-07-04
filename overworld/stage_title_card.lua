require "common.color"
require "common.palette"
require "common.shader"

rt.settings.overworld.stage_title_card = {
    font_path = "assets/fonts/Baloo2/Baloo2-Bold.ttf"
}

--- @class ow.StageTitleCard
ow.StageTitleCard = meta.class("Fade", rt.Widget)
meta.add_signal(ow.StageTitleCard, "done")

local _STATE_IDLE = 0
local _STATE_ATTACK = 1
local _STATE_SUSTAIN = 2
local _STATE_DECAY = 3

--- @brief
function ow.StageTitleCard:instantiate(title, duration)
    duration = duration or rt.settings.fade.default_duration

    local font = rt.Font(rt.settings.overworld.stage_title_card.font_path)
    font:set_line_spacing(0.75)

    meta.install(self, {
        _elapsed = math.huge,
        _fade_in_duration = duration / 4,
        _fade_out_duration = duration / 2,
        _fade_in_elapsed = 0,
        _fade_out_elapsed = 0,

        _state = _STATE_IDLE,

        _title = title,
        _signal_emitted = true,
        _label = rt.Label(
            "<b><outline_color=TRUE_BLACK>" .. title .. "</outline_color></b>",
            rt.FontSize.HUGE, font
        )
    })
end

local function gaussian(x, center)
    return math.exp(-4.4 * math.pi / 3 * ((x - center)^2))
end

local function _attack(fraction)
    return gaussian(fraction, 1)
end

local function _decay(fraction)
    return gaussian(fraction, 0)
end

--- @brief
function ow.StageTitleCard:set_title(title)
    self._title = title
    self._label:set_text(title)
    if self:get_is_realized() then self:reformat() end
end

--- @brief
function ow.StageTitleCard:realize()
    if self:already_realized() then return end
    self._label:realize()
end

--- @brief
function ow.StageTitleCard:size_allocate(x, y, width, height)
    local outer_margin = 4 * rt.settings.margin_unit
    self._label:reformat(0, 0, width, height)
    local label_w, label_h = self._label:measure()
    self._label:reformat(
        outer_margin,
        y + height - outer_margin - label_h,
        width, height
    )
end

function ow.StageTitleCard:fade_in()
    self._state = _STATE_ATTACK
    self._fade_in_elapsed = 0
    self._label:set_opacity(0)
end

function ow.StageTitleCard:fade_out()
    self._state = _STATE_DECAY
    self._fade_out_elapsed = 0
    self._label:set_opacity(0)
end

--- @brief
function ow.StageTitleCard:update(delta)
    local value
    if self._state == _STATE_IDLE then
        value = 0
    elseif self._state == _STATE_ATTACK then
        value = _attack(self._fade_in_elapsed / self._fade_in_duration)
        self._fade_in_elapsed = self._fade_in_elapsed + delta
        if self._fade_in_elapsed >= self._fade_in_duration then self._state = _STATE_SUSTAIN end
    elseif self._state == _STATE_DECAY then
        value = _decay(self._fade_out_elapsed / self._fade_out_duration)
        self._fade_out_elapsed = self._fade_out_elapsed + delta
        if self._fade_out_elapsed >= self._fade_out_duration then self._state = _STATE_IDLE end
    elseif self._state == _STATE_SUSTAIN then
        value = 1
    end

    self._label:update(delta)
    self._label:set_opacity(value)
end

--- @brief
function ow.StageTitleCard:draw()
    self._label:draw()
end
