--- @class ow.PlayerEye
ow.PlayerEye = meta.class("PlayerEye")

function ow.PlayerEye:instantiate(radius)
    meta.assert(radius, "Number")

    self._offset_x, self._offset_y = 0, 0
    self._radius = radius

    self._pupil_x, self._pupil_y = 0, 0
    self._pupil_radius = 0.5 * radius
    self._pupil_color = rt.Palette.BLACK

    self._iris_x, self._iris_y = 0, 0
    self._iris_radius = 0.8 * radius
    self._iris_mesh = rt.MeshCircle(0, 0, self._iris_radius)
    self._iris_value_offset = 0.4
    for i = 2, self._iris_mesh:get_n_vertices() do
        self._iris_mesh:set_vertex_color(i, 1 - self._iris_value_offset, 1 - self._iris_value_offset, 1 - self._iris_value_offset, 1)
    end

    self._sclera_x, self._sclera_y = 0, 0
    self._sclera_radius = radius
    self._sclera_color = rt.RGBA(1, 1, 1, 1)
    self._sclera_mesh = rt.MeshCircle(0, 0, self._sclera_radius)
    local shadow = 0.7
    for i = 2, self._sclera_mesh:get_n_vertices() do
        self._sclera_mesh:set_vertex_color(i, shadow, shadow, shadow, 1)
    end

    self._highlight_x, self._highlight_y = 0, 0
    self._highlight_radius = 0.4 * radius
    self._highlight_color = rt.Palette.WHITE:clone()
    self._highlight_color.a = 0.7

    self._deformation = 1
    self._rotation = 0
end

function ow.PlayerEye:set_offset(offset_x, offset_y)
    local magnitude = math.magnitude(offset_x, offset_y) / (10 * self._radius)
    local norm_x, norm_y = math.normalize(offset_x, offset_y)
    local factor = magnitude <= 1 and magnitude or 1

    -- 3D deformation: squash ellipses based on how far from center
    -- At center: deformation = 1 (circle), at edge: deformation = min_deformation (ellipse)
    local max_deformation = 1.0
    local min_deformation = 0.8 -- how "flat" the ellipse gets at max offset
    self._deformation = max_deformation - (max_deformation - min_deformation) * factor

    local radius = (self._radius - self._pupil_radius * self._deformation)
    self._offset_x = norm_x * radius * factor
    self._offset_y = norm_y * radius * factor

    -- Rotation: angle of the gaze direction
    self._rotation = math.atan2(norm_y, norm_x) + math.pi / 2
end

local function draw_rotated_ellipse(mode, cx, cy, rx, ry, angle)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(angle)
    love.graphics.ellipse(mode, 0, 0, rx, ry)
    love.graphics.pop()
end

function ow.PlayerEye:draw(x, y, scale)

    local r, g, b, a = love.graphics.getColor()
    love.graphics.push()
    love.graphics.translate(x, y)
    love.graphics.scale(scale, scale)
    self._sclera_color:bind()
    love.graphics.draw(self._sclera_mesh:get_native(), self._sclera_x, self._sclera_y)

    local value = rt.graphics.get_stencil_value()
    rt.graphics.stencil(value, function()
        love.graphics.circle("fill", self._sclera_x, self._sclera_y, self._sclera_radius)
    end)
    rt.graphics.set_stencil_test(rt.StencilCompareMode.NOT_EQUAL)

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)

    love.graphics.setColor(r + self._iris_value_offset, g + self._iris_value_offset, b + self._iris_value_offset, a)

    -- Draw iris as a deformed, rotated mesh
    love.graphics.push()
    love.graphics.translate(self._iris_x, self._iris_y)
    love.graphics.rotate(self._rotation)
    love.graphics.scale(1, self._deformation)
    love.graphics.draw(self._iris_mesh:get_native(), 0, 0)
    love.graphics.pop()

    -- Draw pupil as a rotated, squashed ellipse
    self._pupil_color:bind()
    draw_rotated_ellipse(
        "fill",
        self._pupil_x, self._pupil_y,
        self._pupil_radius,
        self._pupil_radius * self._deformation,
        self._rotation
    )

    -- Draw highlight as a deformed, rotated ellipse, positioned toward top-left
    self._highlight_color:bind()
    -- highlight offset direction (top-left, normalized)
    local hl_dir_x, hl_dir_y = -1, -1
    local hl_dir_norm_x, hl_dir_norm_y = math.normalize(hl_dir_x, hl_dir_y)
    -- highlight distance from center (as a fraction of iris radius)
    local hl_dist = self._iris_radius * 0.6
    -- highlight position (relative to iris center, not affected by gaze offset)
    local hl_x = self._iris_x + hl_dir_norm_x * hl_dist
    local hl_y = self._iris_y + hl_dir_norm_y * hl_dist

    -- deform and rotate highlight to match iris
    draw_rotated_ellipse(
        "fill",
        hl_x, hl_y,
        self._highlight_radius,
        self._highlight_radius * self._deformation,
        self._rotation
    )

    love.graphics.pop()

    rt.graphics.set_stencil_test(nil)
    love.graphics.pop()


    love.graphics.setColor(r, g, b, a)
end