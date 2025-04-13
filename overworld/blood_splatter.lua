--- @class ow.BloodSplatter
ow.BloodSplatter = meta.class("BloodSplatter")

--- @brief
function ow.BloodSplatter:instantiate(stage)
    meta.install(self, {
        _stage = stage,
        _segments = {},
        _segmentSet = {}
    })
end

--- @brief
function ow.BloodSplatter:add(x1, y1, x2, y2)
    local key = string.format("%d,%d,%d,%d", x1, y1, x2, y2)
    if not self._segmentSet[key] then
        table.insert(self._segments, x1)
        table.insert(self._segments, y1)
        table.insert(self._segments, x2)
        table.insert(self._segments, y2)
        self._segmentSet[key] = true
    end
end

--- @brief
function ow.BloodSplatter:draw()
    local n = #self._segments
    if n == 0 then return end
    rt.Palette.PLAYER_BLOOD:bind()
    love.graphics.setLineWidth(2)
    for i = 1, n, 4 do
        love.graphics.line(
            self._segments[i+0],
            self._segments[i+1],
            self._segments[i+2],
            self._segments[i+3]
        )
    end
end