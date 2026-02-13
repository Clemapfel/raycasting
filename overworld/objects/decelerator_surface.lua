require "overworld.movable_object"
require "overworld.decelerator_surface_body"
require "common.contour"

rt.settings.overworld.decelerator_surface = {
    bubble_force = 1000,
    non_bubble_force = 0,

    bubble_damping = 0.4,
    non_bubble_damping = 0.5
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
    self._body:add_tag("stencil")
    self._body:set_is_sensor(true)

    local contour = rt.contour.close(object:create_contour())
    local mesh = object:create_mesh()
    self._graphics_body = ow.DeceleratorSurfaceBody(scene, contour, mesh)

    self._force_source_id = nil
    self._damping_source_id = nil

    self._retract_motion = rt.SmoothedMotion1D(0)
    self._input = rt.InputSubscriber()
    self._input:signal_connect("pressed", function(_, which)
        local penetration = self._graphics_body:get_penetration()
        if penetration ~= nil and penetration > 0 and which == rt.InputAction.JUMP then
            self._retract_motion:set_value(1)
        end
    end)
end

--- @brief
function ow.DeceleratorSurface:update(delta)
    local player = self._scene:get_player()

    if not self._stage:get_is_body_visible(self._body) then
        if self._force_source_id ~= nil then
            player:update_force_source(self._force_source_id, 0, 0)
        end
        return
    end

    self._retract_motion:update(delta)

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
        local damping = math.mix(
            max_damping,
            1,
            1 - penetration
        )

        damping = math.min(1, damping) -- + self._retract_motion:get_value())

        local left, right
        if normal_x > 0 then
            right = math.abs(normal_x) * damping
            left = 0
        else
            left = math.abs(normal_x) * damping
            right = 0
        end

        local up, down
        if normal_y < 0 then
            up = math.abs(normal_y) * damping
            down = 0
        else
            down = math.abs(normal_y) * damping
            up = 0
        end

        up, down, left, right = damping, damping, damping, damping

        local eps = 0.05
        local force = 2000 * penetration
        local input_direction_x, input_direction_y = player:get_input_direction()
        local force_x, force_y = input_direction_x * force, input_direction_y * force

        self._damping_source_id = player:update_damping_source(self._damping_source_id, up, right, down, left)
        self._force_source_id = player:update_force_source(self._force_source_id, force_x, force_y)
    elseif self._damping_source_id then
        self._damping_source_id = player:update_damping_source(self._damping_source_id, 1, 1, 1, 1)
        self._force_source_id = player:update_force_source(self._force_source_id, 0, 0)
    end

    if penetration > 0 then
        self._jump_allowed_source_id = player:update_jump_allowed_source(self._jump_allowed_source_id, true)
        self._gravity_multiplier_id = player:request_gravity_multiplier(self._gravity_multiplier_id, 0)
    else
        self._jump_allowed_source_id = player:update_jump_allowed_source(self._jump_allowed_source_id, false)
        self._gravity_multiplier_id = player:request_gravity_multiplier(self._gravity_multiplier_id, 1)
    end

    self._scene:push_camera_mode(ow.CameraMode.CUTSCENE)
    local camera = self._scene:get_camera()
    camera:set_position(self._body:get_position())
end

--- @brief
function ow.DeceleratorSurface:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    self._graphics_body:draw()
end

--- @brief
function ow.DeceleratorSurface:get_render_priority()
    return math.huge
end
