require "overworld.movable_object"
require "overworld.decelerator_body"
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

local first, scale = true, 0

--- @brief
function ow.DeceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    self._body = object:create_physics_body(stage:get_physics_world())

    self._body:add_tag("stencil", "slippery")
    self._graphics_body = ow.DeceleratorBody(object:create_contour())

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

    px, py = self._scene:get_camera():screen_xy_to_world_xy(love.mouse.getPosition())
    self._graphics_body:set_target(px - offset_x, py - offset_y, pr)
    self._graphics_body:update(delta)

    player:set_damping(self._graphics_body:get_player_damping())

    self._scene:push_camera_mode(ow.CameraMode.CUTSCENE)
    local camera = self._scene:get_camera()
    camera:set_position(self._body:get_position())

end

--- @brief
function ow.DeceleratorSurface:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    self._graphics_body:draw()

    love.graphics.setColor(1, 1, 1, 0.5)
    local px, py = self._scene:get_camera():screen_xy_to_world_xy(love.mouse.getPosition())
    love.graphics.circle("line", px, py, self._scene:get_player():get_radius())
    self._scene:set_player_is_visible(false)
end

--- @brief
function ow.DeceleratorSurface:get_render_priority()
    return 2 -- above player
end
