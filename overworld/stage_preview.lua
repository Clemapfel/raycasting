--- @class ow.StagePreview
ow.StagePreview = meta.class("StagePreview", rt.Widget)

--- @brief
function ow.StagePreview:instantiate(...)
    self._min_x, self._min_y = math.huge, math.huge
    self._max_x, self._max_y = -math.huge, -math.huge
    self:create_from(...)
end

--- @brief
function ow.StagePreview:create_from(stage_config)

end

--- @brief
function ow.StagePreview:size_allocate(x, y, width, height)

end

--- @brief
function ow.StagePreview:draw()

end