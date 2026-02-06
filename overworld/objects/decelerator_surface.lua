require "overworld.movable_object"
require "common.fluid_simulation"
require "common.contour"

rt.settings.overworld.decelerator_surface = {
    friction = 1.15,
    subdivision_length = 4,

    max_penetration = rt.settings.player.radius * 0.25
}

--- @class ow.DeceleratorSurface
ow.DeceleratorSurface = meta.class("DeceleratorSurface", ow.MovableObject)

local padding = 20
local _shader = rt.Shader("overworld/objects/decelerator_surface.glsl")

--- @brief
function ow.DeceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    self._body = object:create_physics_body(stage:get_physics_world())
    self._body:add_tag("stencil", "slippery")

    self._mesh, self._tris = object:create_mesh()
    self._fluid = rt.FluidSimulation()

    local x, y = object:get_centroid()
    local area = object:get_area()

    local batch_id = self._fluid:add(x, y, area / math.pi)
    self._fluid:set_target_shape(batch_id, self._tris)
end

--- @brief
function ow.DeceleratorSurface:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    local player = self._scene:get_player()
    local px, py = player:get_position()
    local pr = player:get_radius()

    local offset_x, offset_y = 0, 0 --TODO self._body:get_position()

    self._fluid:update(delta)
end

--- @brief
function ow.DeceleratorSurface:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()

    self._mesh:draw()
    self._fluid:draw()
end

--- @brief
function ow.DeceleratorSurface:get_render_priority()
    return 2 -- above player
end
