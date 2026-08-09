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

    local px, py = self._scene:get_player():get_position()
    local subsegments = {}
    for data in values(self._query:get_visible_subsegments(px, py, bounds)) do
        table.insert(subsegments, data.segment)
    end

    self._todo = subsegments
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
end

