require "overworld.movable_object"
require "overworld.decelerator_surface_body"
require "common.contour"

rt.settings.overworld.decelerator_surface = {
    bubble_force = 1000,
    non_bubble_force = 0,

    bubble_damping = 0.8,
    non_bubble_damping = 0.7
}

--- @class ow.DeceleratorSurface
ow.DeceleratorSurface = meta.class("DeceleratorSurface", ow.MovableObject)

local padding = 20
local _shader = rt.Shader("overworld/objects/decelerator_surface.glsl")

local first, scale = true, 0

--- @brief
function ow.DeceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    local world = stage:get_physics_world()
    self._body = object:create_physics_body(world)
    self._body:add_tag("stencil", "unjumpable", "unwalkable")
    self._body:set_is_sensor(false)

    local contour = rt.contour.close(object:create_contour())
    local mesh = object:create_mesh()
    self._graphics_body = ow.DeceleratorSurfaceBody(scene, contour, mesh)
    self._centroid_x, self._centroid_y = object:get_centroid()
end

--- @brief
function ow.DeceleratorSurface:update(delta)
    local player = self._scene:get_player()

    if not self._stage:get_is_body_visible(self._body) then
        --player:request_force(self, 0, 0)
        return
    end

    local px, py = player:get_position()
    local pr = player:get_radius()

    local offset_x, offset_y = 0, 0 --TODO self._body:get_position()

    self._graphics_body:set_target(px - offset_x, py - offset_y, rt.settings.player.radius)
    self._graphics_body:update(delta)

    local settings = rt.settings.overworld.decelerator_surface
    local max_force = ternary(player:get_is_bubble(), settings.bubble_force, settings.non_bubble_force)
    local max_damping = ternary(player:get_is_bubble(), settings.bubble_damping, settings.non_bubble_damping)

    local penetration, normal_x, normal_y = self._graphics_body:get_penetration()
    if penetration ~= nil and penetration > 0 then
        local damping = max_damping
        player:request_damping(self, damping, damping, damping, damping)

        local force = 2000 * penetration
        local input_direction_x, input_direction_y = player:get_input_direction()
        local force_x, force_y = input_direction_x * force, input_direction_y * force
        --player:request_force(self, force_x, force_y)
    else
        player:request_damping(self, nil, nil, nil, nil)
        --player:request_force(self, nil, nil)
    end

    if player:get_is_colliding_with(self._body) then
        player:request_is_jump_allowed_override(self, true)
    else
        player:request_is_jump_allowed_override(self, nil)
    end

    if penetration > 0 then
        player:request_gravity_multiplier(self, rt.InterpolationFunctions.GAUSSIAN_LOWPASS(penetration))
    else
        player:request_gravity_multiplier(self, nil)
    end
end

--- @brief
function ow.DeceleratorSurface:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    self._graphics_body:set_offset(self._body:get_position())
    self._graphics_body:draw()
end

--- @brief
function ow.DeceleratorSurface:get_render_priority()
    return math.huge
end
