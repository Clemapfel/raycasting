require "common.random"
require "common.smoothed_motion_2d"

rt.settings.overworld.eye = {
    detection_radius = 500
}

--- @class ow.Eye
ow.Eye = meta.class("OverworldEye")

function ow.Eye:instantiate(object, stage, scene)
    assert(object:get_type() == ow.ObjectType.POINT, "In ow.Eye.instantiate: object is not a point")

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:set_is_sensor(true)

    self._stage = stage
    self._scene = scene
    self._x = object.x
    self._y = object.y

    local radius = rt.settings.overworld.player.radius * rt.random.number(0.7, 1)
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

    self._highlight_directionx, self._highlight_directiony = math.normalize(-1, -1)
    self._highlight_dist = self._iris_radius * 0.6
    self._highlight_draw_x = self._iris_x + self._highlight_directionx * self._highlight_dist
    self._highlight_draw_y = self._iris_y + self._highlight_directiony * self._highlight_dist

    self._motion = rt.SmoothedMotion2D(0, 0, 100 * rt.random.number(0.8, 1))

    self._hue_offset = rt.random.number(0, 1)
    self._color = { 1, 1, 1, 1 }

    self._origin_x, self._origin_y = 0, 0
    self._angle = 0
end

function ow.Eye:_set_offset(offset_x, offset_y)
    local magnitude = math.magnitude(offset_x, offset_y) / rt.settings.overworld.eye.detection_radius
    local norm_x, norm_y = math.normalize(offset_x, offset_y)
    local factor = magnitude <= 1 and magnitude or 1
    
    local max_deformation = 1.0
    local min_deformation = 0.7 -- how "flat" the ellipse gets at max offset
    self._deformation = max_deformation - (max_deformation - min_deformation) * factor

    local radius = (self._radius - self._pupil_radius * self._deformation)
    self._offset_x = norm_x * radius * factor
    self._offset_y = norm_y * radius * factor
    self._rotation = math.atan2(norm_y, norm_x) + math.pi / 2

    self._highlight_draw_x = self._iris_x + self._highlight_directionx * self._highlight_dist
    self._highlight_draw_y = self._iris_y + self._highlight_directiony * self._highlight_dist
end

local function draw_rotated_ellipse(mode, cx, cy, rx, ry, angle)
    love.graphics.push()
    love.graphics.translate(cx, cy)
    love.graphics.rotate(angle)
    love.graphics.ellipse(mode, 0, 0, rx, ry)
    love.graphics.pop()
end

function ow.Eye:update(delta)
    if not self._scene:get_is_body_visible(self._body) then return end

    local player = self._scene:get_player()

    local px, py
    if true then --self._scene:get_is_cursor_active() then
        px, py = self._scene:get_camera():screen_xy_to_world_xy(love.mouse.getPosition())
    else
        px, py = player:get_position()
    end
    local sx, sy = self._x, self._y

    self._origin_x, self._origin_y = sx, sy
    self._angle = self._angle + delta * 0.2

    self._motion:set_target_position(px - sx, py - sy)
    self._motion:update(delta)

    self:_set_offset(self._motion:get_position())

    self._color = { rt.lcha_to_rgba(0.8, 1, math.fract(player:get_hue() + self._hue_offset), 1)}
end

function ow.Eye:draw()
    if not self._scene:get_is_body_visible(self._body) then return end

    local r, g, b, a = table.unpack(self._color)

    love.graphics.push()
    love.graphics.translate(self._x, self._y)
    self._sclera_color:bind()
    love.graphics.draw(self._sclera_mesh:get_native(), self._sclera_x, self._sclera_y)

    local value = rt.graphics.get_stencil_value()
    rt.graphics.stencil(value, function()
        love.graphics.draw(self._sclera_mesh:get_native(), self._sclera_x + self._x, self._sclera_y + self._y)
    end)
    rt.graphics.set_stencil_test(rt.StencilCompareMode.NOT_EQUAL)

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)

    love.graphics.setColor(r + self._iris_value_offset, g + self._iris_value_offset, b + self._iris_value_offset, a)

    love.graphics.push()
    love.graphics.translate(self._iris_x, self._iris_y)
    love.graphics.rotate(self._rotation)
    love.graphics.scale(1, self._deformation)
    love.graphics.draw(self._iris_mesh:get_native(), 0, 0)
    love.graphics.pop()

    self._pupil_color:bind()
    draw_rotated_ellipse(
        "fill",
        self._pupil_x, self._pupil_y,
        self._pupil_radius,
        self._pupil_radius * self._deformation,
        self._rotation
    )

    self._highlight_color:bind()
    draw_rotated_ellipse(
        "fill",
        self._highlight_draw_x, self._highlight_draw_y,
        self._highlight_radius,
        self._highlight_radius * self._deformation,
        self._rotation
    )

    love.graphics.pop()

    rt.graphics.set_stencil_test(nil)
    love.graphics.pop()

    love.graphics.setColor(r, g, b, a)
end