require "overworld.visibility_query"

rt.settings.overworld.shadow_cast = {}

--- @class ow.ShadowCast
ow.ShadowCast = meta.class("ShadowCast")

local _shader = rt.Shader("overworld/shadow_cast.glsl")

--- @brief
function ow.ShadowCast:instantiate(scene)
    meta.assert(scene, ow.OverworldScene)

    self._scene = scene
    self._query = ow.VisibilityQuery()
    self._intensity = 1

    self._entries = {}
    self._polygons = {}
    self._points = {}

    self._offset_x = 0
    self._offset_y = 0
end

--- @brief
function ow.ShadowCast:initialize(non_reflective_contours, reflective_contours, additional_contour_bodies)
    meta.assert(reflective_contours, mt.Table, non_reflective_contours, mt.Table)
    self._query:initialize(
        non_reflective_contours,
        reflective_contours
    )

    self._additional_contour_bodies = additional_contour_bodies
    for i, body in ipairs(additional_contour_bodies) do
        rt.assert(meta.is_function(body.get_contour), "In ow.ShadowCast.initialize: contour body at position `", i, "` does not have a `get_contour` function")
    end
end

--- @brief
function ow.ShadowCast:update(delta)
    if rt.GameState:get_are_dynamic_shadows_enabled() == false then return end

    local camera = self._scene:get_camera()
    local bounds = camera:get_world_bounds()
    bounds.x = bounds.x - self._offset_x
    bounds.y = bounds.y - self._offset_y

    local px, py = self._scene:get_player():get_position()
    px = px - self._offset_x
    py = py - self._offset_y

    local additional_segments = {}
    for body in values(self._additional_contour_bodies) do
        local contour = body:get_contour()
        rt.assert(meta.is_table(contour) and (#contour == 0 or #contour % 2 == 0),
            "In ow.ShadowCast.update: additional contour body `", meta.typeof(body), ".get_contour` does not return a flat table of numbers"
        )

        for i = 1, #contour - 2, 2 do
            local ax, ay, bx, by = contour[i], contour[i+1], contour[i+2], contour[i+3]
            table.insert(additional_segments, {
                segment = { ax, ay, bx, by }
            })
        end
    end

    self._entries, self._tris = self._query:get_visible_subsegments(
        px, py,
        bounds,
        true, -- compute visibility polygon
        additional_segments
    )
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
function ow.ShadowCast:set_intensity(t)
    self._intensity = t
end

--- @brief
function ow.ShadowCast:draw()
    if rt.GameState:get_are_dynamic_shadows_enabled() == false then return end
end

--- @brief
function ow.ShadowCast:draw_bloom()
    if rt.GameState:get_are_dynamic_shadows_enabled() == false then return end
    local r, g, b, a = self._scene:get_player():get_color():unpack()
    local t = self._intensity

    local px, py = self._scene:get_player():get_position()
    px, py = self._scene:get_camera():world_xy_to_screen_xy(px, py)

    love.graphics.push("all")

    _shader:bind()
    _shader:send("player_position", { px, py })
    _shader:send("mask", rt.SceneManager:get_light_map():get_mask())

    love.graphics.push()
    love.graphics.translate(self._offset_x, self._offset_y)
    love.graphics.setLineWidth(4)
    love.graphics.setColor(t * r, t * g, t * b, t * a)
    for entry in values(self._entries) do
        local ax, ay, bx, by = table.unpack(entry.subsegment)
        love.graphics.line(ax, ay, bx, by)
    end
    love.graphics.pop()

    local value = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(value, rt.StencilMode.DRAW)
    ow.Hitbox:draw_mask(true, true)
    rt.graphics.set_stencil_mode(value, rt.StencilMode.TEST, rt.StencilCompareMode.NOT_EQUAL)

    rt.graphics.set_blend_mode(rt.BlendMode.ADD, rt.BlendMode.ADD)
    t = 0.25 * t
    love.graphics.setColor(t * r, t * g, t * b, t)
    for polygon in values(self._tris) do
        love.graphics.polygon("fill", polygon)
    end

    _shader:unbind()

    rt.graphics.set_stencil_mode(nil)

    love.graphics.pop()
end

--- @brief
function ow.ShadowCast:collect_segment_lights(callback)
    local r, g, b, a = self._scene:get_player():get_color():unpack()
    local t = self._intensity

    love.graphics.setColor(r, g, b, a)
    local ox, oy = self._offset_x, self._offset_y
    for entry in values(self._entries) do
        local ax, ay, bx, by = table.unpack(entry.subsegment)
        callback(
            ax + ox, ay + oy,
            bx + ox, by + oy,
            r, g, b, 0
        )
    end
end

