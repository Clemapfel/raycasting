--- @class ow.NOOP
ow.NOOP = meta.class("NOOP", ow.MovableObject)

--- @brief
function ow.NOOP:instantiate(object, stage, scene)
    if object:get_type() == ow.ObjectType.POINT then
        local x, y = object:get_position()

        self._contour = {}
        local n_vertices = 8
        local radius = 2
        for i = 1, n_vertices do
            local angle = (i - 1) / n_vertices * math.tau
            table.insert(self._contour, x + math.cos(angle) * radius)
            table.insert(self._contour, y + math.sin(angle) * radius)
        end

        self._fill = rt.MeshCircle(x, y, radius)
    else
        self._contour = object:create_contour()
        self._fill = object:create_mesh()
    end
end

--- @brief
function ow.NOOP:draw()
    local r, g, b, a = rt.Palette.TRUE_MAGENTA:unpack()

    love.graphics.setColor(r, g, b, a)
    love.graphics.line(self._contour)

    love.graphics.setColor(r, g, b, 0.5 * a)
    self._fill:draw()
end