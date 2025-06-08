require "common.sdf"
require "common.camera"
require "overworld.objects.hitbox"

--- @class ow.NormalMap
ow.NormalMap = meta.class("NormalMap")

local _shader

--- @brief
function ow.NormalMap:instantiate(scene)
    self._scene = scene
    self._is_realized = false
    if _shader == nil then _shader = rt.Shader("overworld/normal_map.glsl") end
end

--- @brief
function ow.NormalMap:reformat(x, y, width, height)
    self._is_realized = true
    local r = math.max(width, height) / 1.5
    self._sdf_width, self._sdf_height = r, r
    self._sdf = rt.SDF(self._sdf_width, self._sdf_height)
    self._sdf:set_wall_mode(rt.SDFWallMode.INSIDE)
end

--- @brief
function ow.NormalMap:update(delta)
    love.graphics.push()
    love.graphics.origin()
    self._sdf:bind()
    love.graphics.clear(0, 0, 0, 0)

    self._scene:get_camera():bind()
    local x, y = self._scene:get_camera():world_xy_to_screen_xy(self._scene:get_player():get_position())
    love.graphics.translate(-1 * (x - 0.5 * self._sdf_width), -1 * (y - 0.5 * self._sdf_height))
    ow.Hitbox:draw_mask(true) -- sticky
    self._scene:get_camera():unbind()

    self._sdf:unbind()
    love.graphics.pop()

    self._sdf:compute(true)
end

--- @brief
function ow.NormalMap:draw()
    rt.graphics.set_blend_mode(rt.BlendMode.ADD)
    love.graphics.push()
    love.graphics.origin()

    local x, y = self._scene:get_camera():world_xy_to_screen_xy(self._scene:get_player():get_position())
    love.graphics.translate(x - 0.5 * self._sdf_width, y - 0.5 * self._sdf_height)

    _shader:send("player_position", { 0.5, 0.5 })
    _shader:bind()
    love.graphics.draw(self._sdf:get_sdf_texture())
    _shader:unbind()
    love.graphics.pop()
    rt.graphics.set_blend_mode(nil)
end