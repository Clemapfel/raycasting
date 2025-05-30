require "common.shader"
require "common.mesh"

--- @class ow.Hitbox
ow.Hitbox = meta.class("Hitbox")

local _slippery = {}
local _sticky = {}

--- @brief
function ow.Hitbox:instantiate(object, stage, scene)
    self._mesh, self._tris = object:create_mesh()
    for tri in values(self._tris) do -- close for line loop
        table.insert(tri, tri[1])
        table.insert(tri, tri[2])
    end

    self._body = object:create_physics_body(stage:get_physics_world())
    for property in range(
        "slippery",
        "sticky"
    ) do
        if object:get_boolean(property) then
            self._body:add_tag(property)
        end
    end

    if self._body:has_tag("slippery") then
        self._render_priority = 1
        self._color_r, self._color_g, self._color_b, self._color_a = rt.Palette.SLIPPERY:unpack()
        self._outline_color_r, self._outline_color_g, self._outline_color_b, self._outline_color_a = rt.Palette.SLIPPERY_OUTLINE:unpack()
        self._line_width = 4
        table.insert(_slippery, self)
    else
        self._render_priority = 2
        self._color_r, self._color_g, self._color_b, self._color_a = rt.Palette.STICKY:unpack()
        self._outline_color_r, self._outline_color_g, self._outline_color_b, self._outline_color_a = rt.Palette.STICKY_OUTLINE:unpack()
        self._line_width = 2.5
        table.insert(_sticky, self)
    end

    self._body:set_friction(object:get_number("friction") or 0)
end

--- @brief
function ow.Hitbox:draw_all()
    love.graphics.setLineJoin("bevel")

    for instances_line_width in range(
        {_slippery, 4},
        {_sticky, 2.5}
    ) do
        local instances, line_width = table.unpack(instances_line_width)

        local stencil_value = rt.graphics.get_stencil_value()
        for self in values(instances) do
            love.graphics.push()
            love.graphics.translate(self._body:get_position())
            love.graphics.rotate(self._body:get_rotation())
            love.graphics.draw(self._mesh:get_native())

            love.graphics.setColor(1, 1, 1, 1)
            rt.graphics.stencil(stencil_value, self._mesh)

            love.graphics.pop()
        end

        rt.graphics.set_stencil_compare_mode(rt.StencilCompareMode.NOT_EQUAL, stencil_value)

        --love.graphics.setLineWidth(line_width + 1)
        love.graphics.setColor(0, 0, 0, 1)
        for self in values(instances) do
            love.graphics.push()
            love.graphics.translate(self._body:get_position())
            love.graphics.rotate(self._body:get_rotation())

            for tri in values(self._tris) do
                love.graphics.line(tri)
            end

            love.graphics.pop()
        end

        --love.graphics.setLineWidth(line_width)

        for self in values(instances) do
            love.graphics.setColor(self._outline_color_r, self._outline_color_g, self._outline_color_b, self._outline_color_a)

            love.graphics.push()
            love.graphics.translate(self._body:get_position())
            love.graphics.rotate(self._body:get_rotation())
            for tri in values(self._tris) do
                love.graphics.line(tri)
            end

            love.graphics.pop()
        end

        rt.graphics.set_stencil_compare_mode(nil)
    end
end

--- @brief
function ow.Hitbox:_draw()
    love.graphics.setColor(self._color_r, self._color_g, self._color_b, self._color_a)

    love.graphics.push()
    love.graphics.translate(self._body:get_position())
    love.graphics.rotate(self._body:get_rotation())
    love.graphics.draw(self._mesh:get_native())

    local stencil_value = rt.graphics.get_stencil_value()
    love.graphics.setColor(1, 1, 1, 1)
    rt.graphics.stencil(stencil_value, self._mesh)
    rt.graphics.set_stencil_compare_mode(rt.StencilCompareMode.NOT_EQUAL, stencil_value)

    love.graphics.setLineJoin("bevel")
    love.graphics.setLineWidth(self._line_width + 1)
    love.graphics.setColor(0, 0, 0, 1)
    for tri in values(self._tris) do
        love.graphics.line(tri)
    end

    love.graphics.setLineWidth(self._line_width)
    love.graphics.setColor(self._outline_color_r, self._outline_color_g, self._outline_color_b, self._outline_color_a)
    for tri in values(self._tris) do
        love.graphics.line(tri)
    end

    rt.graphics.set_stencil_compare_mode(nil)

    love.graphics.pop()
end

--- @brief
function ow.Hitbox:get_render_priority()
    return self._render_priority
end