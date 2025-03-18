require "common.random"
require "common.sprite"

--- @class ow.Background
ow.Background = meta.class("OverworldBackground", rt.Widget)

--- @brief
function ow.Background:size_allocate(x, y, width, height)
    self._sprites = {}
    for i = 1, 100 do
        local cx = rt.random.number(x, x + width)
        local cy = rt.random.number(y, y + height)
        local sprite = nil
    end
end
