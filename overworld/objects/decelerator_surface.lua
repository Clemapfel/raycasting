require "overworld.deformable_mesh"

rt.settings.overworld.objects.decelerator_surface = {
    friction = 2,
    subdivision_length = 4,

    max_penetration = rt.settings.player.radius * 0.25
}

--- @class ow.DeceleratorSurface
ow.DeceleratorSurface = meta.class("DeceleratorSurface")

--- @brief
function ow.DeceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    self._body = object:create_physics_body(stage:get_physics_world(), b2.BodyType.STATIC)
    self._body:add_tag("use_friction", "hitbox")
    self._body:set_friction(2)

    local contour = rt.close_contour(object:create_contour())
    self._contour = rt.subdivide_contour(
        contour,
        rt.settings.overworld.objects.decelerator_surface.subdivision_length
    )

    self._fill = {}
    if rt.is_contour_convex(contour) then
        self._fill = { contour }
    else
        self._fill = table.deepcopy(object:triangulate())
    end

    self._player_stencil = {} -- love.Circle
    self._player_stencil_active = false
end

--- @brief
function ow.DeceleratorSurface:update(delta)
    if not self._stage:get_is_body_visible(self._body) then
        self._player_stencil_active = false
        return
    end

    self._player_stencil_active = true
    local player = self._scene:get_player()
    local px, py = player:get_position()
    local radius = player:get_radius()

    self._player_stencil[1], self._player_stencil[2], self._player_stencil[3] = px, py, radius * 1.25
end

--- @brief
function ow.DeceleratorSurface:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    if self._player_stencil_active then
        love.graphics.push("all")
        local value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)
        love.graphics.circle("fill", table.unpack(self._player_stencil))
        rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)
    end

    rt.Palette.DECELERATOR_SURFACE:bind()
    for tri in values(self._fill) do
        love.graphics.polygon("fill", tri)
    end

    if self._player_stencil_active then
        rt.graphics.set_stencil_mode(nil)
        love.graphics.pop()
    end

    local line_width = 2
    rt.Palette.BLACK:bind()
    love.graphics.setLineWidth(line_width + 1.5)
    love.graphics.line(self._contour)

    rt.Palette.DECELERATOR_SURFACE_OUTLINE:bind()
    love.graphics.setLineWidth(line_width + 1.5)
    love.graphics.line(self._contour)
end


--- @brief
function ow.DeceleratorSurface:get_render_priority()
    return 1
end
