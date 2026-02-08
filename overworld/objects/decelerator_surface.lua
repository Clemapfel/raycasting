require "overworld.movable_object"
require "overworld.decelerator_body"
require "common.contour"

rt.settings.overworld.decelerator_surface = {
    max_damping = 0.8
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

    self._body = object:create_physics_body(stage:get_physics_world())

    self._body:add_tag("stencil", "slippery")
    local contour = object:create_contour()
    local mesh = object:create_mesh()
    self._graphics_body = ow.DeceleratorBody(contour, mesh)

    if first then
        DEBUG_INPUT:signal_connect("keyboard_key_pressed", function(_, which)
            if which == "+" then
                scale = scale + 0.5
                self._scene:get_camera():set_scale(1 + scale)
            elseif which == "-" then
                scale = scale - 1
                self._scene:get_camera():set_scale(1 / math.abs(scale))
            end
        end)
        first = false
    end
end

--- @brief
function ow.DeceleratorSurface:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    local player = self._scene:get_player()
    local px, py = player:get_position()
    local pr = player:get_radius()

    local offset_x, offset_y = 0, 0 --TODO self._body:get_position()

    self._graphics_body:set_target(px - offset_x, py - offset_y, player:get_radius())
    self._graphics_body:update(delta)

    local damping_t = self._graphics_body:get_player_damping()
    local damping = 1 - math.mix(0, rt.settings.overworld.decelerator_surface.max_damping, damping_t)

    dbg(damping)
    player:set_damping(
        damping
    )

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
    return 2 -- above player
end
