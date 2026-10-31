--- @class ow.NOOP
ow.NOOP = meta.class("NOOP", ow.MovableObject)

--- @brief
function ow.NOOP:instantiate(object, stage, scene)
    self._contour = object:create_contour()
    self._fill = object:create_mesh()
end

--- @brief
function ow.NOOP:draw()
    local r, g, b, a = rt.Palette.TRUE_MAGENTA:unpack()

    love.graphics.setColor(r, g, b, a)
    love.graphics.line(self._contour)

    love.graphics.setColor(r, g, b, 0.5 * a)
    self._fill:draw()
end