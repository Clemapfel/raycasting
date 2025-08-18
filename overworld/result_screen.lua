require "common.timed_animation_sequence"
require "menu.stage_grade_label"
require "common.translation"
require "common.label"
require "overworld.result_screen_frame"

rt.settings.overworld.result_screen = {
    flow_step = 1 / 100, -- fraction
    time_step = 1, -- seconds
    coins_step = 1, -- count
}


--- @class ow.ResultScreen
ow.ResultScreen = meta.class("ResultScreen", rt.Widget)

--- @brief
function ow.ResultScreen:instantiate()
    self._frame = ow.ResultScreenFrame()
end

--- @brief
function ow.ResultScreen:present(x, y)
    self._frame:present(x, y)
end

--- @brief
function ow.ResultScreen:realize()
    self._frame:realize()
end

function ow.ResultScreen:size_allocate(x, y, width, height)
    self._frame:reformat(x, y, width, height)
end

--- @brief
function ow.ResultScreen:update(delta)
    self._frame:update(delta)
end

--- @brief
function ow.ResultScreen:draw()
    self._frame:draw()
end
