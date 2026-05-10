require "overworld.movable_object"
require "overworld.decelerator_surface_body"
require "common.contour"

rt.settings.overworld.decelerator_surface = {
    bubble_damping = 0.8,
    non_bubble_damping = 0.2
}

--- @class ow.DeceleratorSurface
ow.DeceleratorSurface = meta.class("DeceleratorSurface") -- not movable: , ow.MovableObject)

local padding = 20
local _shader = rt.Shader("overworld/objects/decelerator_surface.glsl")

local first, scale = true, 0

--- @brief
function ow.DeceleratorSurface:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    local world = stage:get_physics_world()
    self._body = object:create_physics_body(world)
    self._body:add_tag("stencil", "unjumpable", "unwalkable", "segment_light_source")
    self._body:set_user_data(self)
    self._body:set_is_sensor(true)

    local contour = rt.contour.close(object:create_contour())
    self._graphics_body = ow.DeceleratorSurfaceBody(scene, contour)
    self._centroid_x, self._centroid_y = object:get_centroid()

    self._segment_lights = {}
    for i = 1, #contour - 2, 2 do
        local x1, y1 = contour[i+0], contour[i+1]
        local x2, y2 = contour[math.wrap(i+2, #contour)], contour[math.wrap(i+3, #contour)]
        table.insert(self._segment_lights, { x1, y1, x2, y2 })
    end
end

--- @brief
function ow.DeceleratorSurface:update(delta)
    local player = self._scene:get_player()

    if not self._stage:get_is_body_visible(self._body) then
        player:request_damping(self, nil, nil, nil, nil)
        return
    end

    local px, py = player:get_position()

    self._graphics_body:set_target(px, py, rt.settings.player.radius) -- always attach to core
    self._graphics_body:update(delta)

    local settings = rt.settings.overworld.decelerator_surface
    local max_damping = ternary(player:get_is_bubble(), settings.bubble_damping, settings.non_bubble_damping)

    local penetration = self._graphics_body:get_penetration()
    if penetration ~= nil and penetration > 0 then
        local damping = math.mix(1, max_damping, penetration)
        player:request_damping(self, damping, damping, damping, damping)
        player:request_is_omnidirectional_movement_allowed(self, true)
        player:request_is_jump_allowed_override(self, true)
    else
        player:request_damping(self, nil, nil, nil, nil)
        player:request_is_omnidirectional_movement_allowed(self, nil)
        player:request_is_jump_allowed_override(self, nil)
    end
end

--- @brief
function ow.DeceleratorSurface:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local body_x, body_y = self._body:get_position()
    self._graphics_body:set_offset(self._centroid_x - body_x, self._centroid_y - body_y)
    self._graphics_body:draw()

    -- bloom handles outline on top, if player fully behind body draw manually
    if rt.GameState:get_is_bloom_enabled() == false then
        love.graphics.push("all")

        local value = rt.graphics.get_stencil_value()
        rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)
        self._graphics_body:draw()
        rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST)
        rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.ADD)
        self._scene:get_player():draw_bloom()
        rt.graphics.set_blend_mode(nil)
        rt.graphics.set_stencil_mode(nil)

        love.graphics.pop()
    end
end

--- @brief
function ow.DeceleratorSurface:get_render_priority()
    return 2 -- above player, below bloom
end

--- @brief
function ow.DeceleratorSurface:collect_segment_lights(callback)
    local body_x, body_y = self._body:get_position()
    for segment in values(self._segment_lights) do
        local x1, y1, x2, y2 = table.unpack(segment)
        callback(
            x1,
            y1,
            x2,
            y2,
            rt.Palette.DECELERATOR_SURFACE_BODY:unpack()
        )
    end
end

--- @brief
function ow.DeceleratorSurface:reset()
    local player = self._scene:get_player()
    player:request_damping(self, nil)
    player:request_gravity_multiplier(self, nil)
end