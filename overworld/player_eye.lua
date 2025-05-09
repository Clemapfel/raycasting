--- @class ow.PlayerEye
ow.PlayerEye = meta.class("PlayerEye")

function ow.PlayerEye:instantiate(radius)
    meta.assert(radius, "Number")

    self._pupil_x, self._pupil_y = 0, 0
    self._pupil_radius = 0.2 * radius
    self._pupil_color = rt.Palette.BLACK

    self._iris_x, self._iris_y = 0, 0
    self._iris_radius = 0.4 * radius
    self._iris_color = rt.Palette.GREEN

    self._sclera_x, self._sclera_y = 0, 0
    self._sclera_radius = radius
    self._sclera_color = rt.Palette.WHITE

    self._highlight_x, self._highlight_y = 0, 0
    self._highlight_radius_x, self._highlight_y = 0.2 * radius, 0.1 * radius
    self._highlight_color = rt.RGBA(rt.Palette.WHITE:unpack())
    self._highlight_color.a = 0.3
end

function ow.PlayerEye:draw()
    self._sclera_color:bind()
    love.graphics.circle("fill", self._sclera_x, self._sclera_y, self._sclera_radius)

    self._iris_color:bind()
    love.graphics.circle("fill", self._iris_x, self._iris_y, self._iris_radius)

    self._pupil_color:bind()
    love.graphics.circle("fill", self._pupil_x, self._pupil_y, self._pupil_radius)

    self._highlight_color:bind()
    love.graphics.circle("fill", self._highlight_x, self._highlight_y, self._highlight_radius)
end