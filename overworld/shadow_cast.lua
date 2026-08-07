require "overworld.visibility_query"

rt.settings.overworld.shadow_cast = {

}

--- @class ow.ShadowCast
ow.ShadowCast = meta.class("ShadowCast")

--- @brief
function ow.ShadowCast:instantiate(scene)
    meta.assert(scene, ow.OverworldScene)

    self._scene = scene
    self._query = ow.VisibilityQuery()
    self._candidates = {}

    self._offset_x = 0
    self._offset_y = 0
end

--- @brief
function ow.ShadowCast:initialize(non_reflective_contours, reflective_contours)
    meta.assert(reflective_contours, mt.Table, non_reflective_contours, mt.Table)
    self._query:initialize(
        non_reflective_contours,
        reflective_contours
    )
end

--- @brief
function ow.ShadowCast:update(delta)
    if rt.GameState:get_are_dynamic_shadows_enabled() == false then return end

    local camera = self._scene:get_camera()
    local bounds = camera:get_world_bounds()
    bounds.x = bounds.x - self._offset_x
    bounds.y = bounds.y - self._offset_y

    local all = {}
    for data in values(self._query:get_segments_in_area(bounds)) do
        table.insert(all, data.segment)
    end

    self._todo = all
end

--- @brief
function ow.ShadowCast:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end

--- @brief
function ow.ShadowCast:get_offset()
    return self._offset_x, self._offset_y
end

--- @brief
function ow.ShadowCast:draw()
    if rt.GameState:get_are_dynamic_shadows_enabled() == false then return end
end

--- @brief
function ow.ShadowCast:draw_bloom()
    if rt.GameState:get_are_dynamic_shadows_enabled() == false then return end

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)
    love.graphics.setColor(self._scene:get_player():get_color():unpack())
    for line in values(self._todo) do
        love.graphics.line(line)
    end
    love.graphics.pop()
end

