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
    self._to_update = {} -- return from self._query
end

--- @brief
function ow.ShadowCast:initialize(contour_objects, ...)
    if select("#", ...) > 0 then
        contour_objects = { contour_objects, ... }
    end

    for i, object in ipairs(contour_objects) do
        rt.assert(meta.is_function(object.get_contour), "In ow.ShadowCast.initialize: contour body `", meta.typeof(object), "` at position `", i, "` does not have a `get_contour` function")
        rt.assert(meta.is_function(object.get_is_visible), "In ow.ShadowCast.initialize: contour body `", meta.typeof(object), "` at position `", i, "` does not have a `get_is_visible` function")
    end

    local contours = {}
    for object in values(contour_objects) do
        local contour, is_dynamic = object:get_contour()
        rt.assert(#contour % 2 == 0, "In ow.ShadowCast.initialize: object `", meta.typeof(object), "`.get_contour does not return a table whos size is a multiple of 2")
        for i, x in ipairs(contour) do
            if not meta.is_number(x) then
                rt.assert(#contour % 2 == 0, "In ow.ShadowCast.initialize: object `", meta.typeof(object), "`.get_contour returns table who does not have a number at position `", i, "`")
            end
        end

        if is_dynamic ~= nil then
            rt.assert(meta.is_boolean(is_dynamic), "In ow.ShadowCast.initialize: object `", meta.typeof(object), "`.get_contour does not return a boolean as the third return value")
            if is_dynamic == true then
                rt.assert(meta.is_function(object.get_offset), "In ow.ShadowCast.initialize: object `", meta.typeof(object), "` returns a dynamic contour using `get_contour`, but `get_offset` is undefined")
            end
        else
            is_dynamic = false
        end

        table.insert(contours, {
            contour = contour,
            object = object,
            is_dynamic = is_dynamic
        })
    end

    meta.assert(contour_objects, mt.Table)
    local userdatas = self._query:initialize(contours)
    self._dynamic_userdatas = {}
    for data in values(userdatas) do
        if data.is_dynamic then
            table.insert(self._dynamic_userdatas, data)
        end
    end
end

--- @brief
function ow.ShadowCast:update(delta)
    if rt.GameState:get_are_dynamic_shadows_enabled() == false then return end

    for data in values(self._dynamic_userdatas) do
        local object = data.entry.object
        if object:get_is_visible() then
            data:set_offset(data.entry.object:get_offset())
        end
    end

    local camera = self._scene:get_camera()
    local bounds = camera:get_world_bounds()
    bounds.x = bounds.x
    bounds.y = bounds.y

    local px, py = self._scene:get_player():get_position()


    self._entries, self._tris = self._query:get_visible_subsegments(
        px, py,
        bounds,
        true -- compute visibility polygon
    )
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
    for entry in values(self._entries) do
        local ax, ay, bx, by = table.unpack(entry.subsegment)
        callback(
            ax, ay ,
            bx, by,
            r, g, b, 0
        )
    end
end

