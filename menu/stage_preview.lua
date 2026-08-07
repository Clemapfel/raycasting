require "common.widget"
require "common.matrix"

rt.settings.menu.stage_preview = {
    spatial_hash_cell_size = 16,
    outer_margin = 0,
    default_thumbnail_margin_factor = 0.05,
    line_width = 2
}

--- @class mn.StagePreview
mn.StagePreview = meta.class("StagePreview", rt.Widget)

--- @brief
function mn.StagePreview:instantiate(stage_id)
    self._config = rt.GameState:stage_get_config(stage_id)
    self._contours = {}
    self._color = rt.RGBA(1, 1, 1, 1)
end

--- @brief
function mn.StagePreview:realize()
    local whitelist = {}
    for type in range(
        "Hitbox",
        "SlipperyHitbox",
        "AcceleratorSurface",
        "BoostField",
        "BubbleField",
        "BouncePad",
        "Bubble",
        "DeceleratorSurface",
        "AirDashNode",
        "Hook",
        "MovableHitbox",
        "OneWayPlatform"
    ) do
        whitelist[type] = true
    end

    local thumbnail = nil
    local thumbnail_was_set = false -- thumbnail manually specified using `StageThumbnail`

    local candidates = {}
    for layer_i = 1, self._config:get_n_layers() do
        for wrapper in values(self._config:get_layer_object_wrappers(layer_i)) do
            local class = wrapper:get_class()
            if class == "StageThumbnail" then
                if wrapper:get_type() == ow.ObjectType.RECTANGLE and wrapper.rotation == 0 then
                    thumbnail = rt.AABB(
                        wrapper.x, wrapper.y,
                        wrapper.width, wrapper.height
                    )
                    thumbnail_was_set = true
                end
            elseif whitelist[class] == true then
                table.insert(candidates, wrapper)
            end
        end
    end

    if thumbnail == nil then
        local min_x, min_y = math.huge, math.huge
        local max_x, max_y = -math.huge, -math.huge
        local has_points = false

        for candidate in values(candidates) do
            local success, contour = pcall(candidate.create_contour, candidate)
            if success then
                for i = 1, #contour, 2 do
                    local x = contour[i+0]
                    local y = contour[i+1]

                    has_points = true
                    min_x = math.min(min_x, x)
                    max_x = math.max(max_x, x)
                    min_y = math.min(min_y, y)
                    max_y = math.max(max_y, y)
                end
            end
        end

        if not has_points then
            min_x, min_y, max_x, max_y = 0, 0, 0, 0
        end

        thumbnail = rt.AABB(min_x, min_y, max_x - min_x, max_y - min_y)
        thumbnail_was_set = false
    else
        local to_remove = {}
        for candidate_i = 1, #candidates do
            local success, contour = pcall(candidates[candidate_i].create_contour, candidates[candidate_i])
            if success then
                local is_inside = false
                for i = 1, #contour, 2 do
                    local x = contour[i+0]
                    local y = contour[i+1]

                    if thumbnail:contains(x, y) then
                        is_inside = true
                        break
                    end
                end

                if not is_inside then
                    table.insert(to_remove, 1, candidate_i)
                end
            end
        end

        for _, candidate_i in ipairs(to_remove) do
            table.remove(candidates, candidate_i)
        end
    end

    if not thumbnail_was_set then
        local padding = thumbnail.width * rt.settings.menu.stage_preview.default_thumbnail_margin_factor
        thumbnail.x = thumbnail.x - padding
        thumbnail.y = thumbnail.y - padding
        thumbnail.width = thumbnail.width + 2 * padding
        thumbnail.height = thumbnail.height + 2 * padding
    end

    self._thumbnail = thumbnail
    self._contours = {}

    local project = function(x, y)
        x, y = x - thumbnail.x, y - thumbnail.y
        return x, y
    end

    local mesh_data = {}
    for candidate in values(candidates) do
        local success, candidate_tris = pcall(candidate.triangulate, candidate)
        if success then
            for tri in values(candidate_tris) do
                local res = {}
                for i = 1, #tri, 2 do
                    local x, y = project(tri[i+0],  tri[i+1])

                    table.insert(mesh_data, {
                        x, y, 0, 0, 1, 1, 1, 1
                    })
                end
            end
        end

        local success, contour = pcall(candidate.create_contour, candidate)
        if success and #contour > 2 then
            local to_push = {}
            for i = 1, #contour, 2 do
                local x, y = project(contour[i+0], contour[i+1])
                table.insert(to_push, x)
                table.insert(to_push, y)
            end

            if #to_push > 4 then
                table.insert(self._contours, rt.contour.close(to_push))
            end
        end
    end

    self._mesh = rt.Mesh(mesh_data, rt.MeshDrawMode.TRIANGLES)

    if self._canvas == nil then
        self:reformat() -- update canvas
    end
end

--- @brief
function mn.StagePreview:size_allocate(x, y, width, height)

    local m = rt.settings.menu.stage_preview.outer_margin

    local bounds_x = self._bounds.x
    local bounds_y = self._bounds.y
    local bounds_w = self._bounds.width
    local bounds_h = self._bounds.height

    local thumbnail_w = self._thumbnail.width
    local thumbnail_h = self._thumbnail.height

    local scale = math.min(bounds_w / thumbnail_w, bounds_h / thumbnail_h)
    local scaled_w, scaled_h = thumbnail_w * scale, thumbnail_h * scale

    local line_width = rt.settings.menu.stage_preview.line_width
    local padding = 4 * line_width
    local canvas_w, canvas_h = width + 2 * padding, height + 2 * padding
    self._padding = padding

    if self._canvas == nil
        or self._canvas:get_width() ~= canvas_w
        or self._canvas:get_height() ~= canvas_h
    then
        self._canvas = rt.Blur(canvas_w, canvas_h, {
            msaa = 8,
            has_stencil = true
        })
        self._canvas:set_blur_strength(1)
        self._canvas:set_flush_manually(true)
    end

    love.graphics.push("all")
    self._canvas:bind()
    love.graphics.clear(0, 0, 0,  0)

    local stencil = rt.graphics.get_stencil_value()
    rt.graphics.set_stencil_mode(stencil, rt.StencilMode.DRAW)
    love.graphics.rectangle("fill", padding, padding, canvas_w - 2 * padding, canvas_h - 2 * padding)
    rt.graphics.set_stencil_mode(stencil, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

    love.graphics.setColor(1, 1, 1, 1)

    love.graphics.setLineJoin("none")
    love.graphics.setLineStyle("smooth")

    local bind_outline = function()
        love.graphics.setLineWidth((line_width + 0.5) / scale)
        love.graphics.setLineStyle("smooth")
        rt.Palette.BLACK:bind()
    end

    local bind_inside = function()
        love.graphics.setLineWidth(line_width / scale)
        love.graphics.setLineStyle("rough")
        rt.Palette.FOREGROUND:bind()
    end

    -- offset everything by padding so the canvas has room to blur into
    love.graphics.translate(padding, padding)

    love.graphics.translate(
        bounds_x + (bounds_w - scaled_w) * 0.5 - bounds_x,
        bounds_y + (bounds_h - scaled_h) * 0.5 - bounds_y
    )

    love.graphics.scale(scale, scale)

    self._color:bind()
    self._mesh:draw()

    bind_outline()
    for contour in values(self._contours) do
        love.graphics.line(contour)
    end

    bind_inside()
    for contour in values(self._contours) do
        love.graphics.line(contour)
    end

    -- frame rect expressed in the same (scaled, centered) local space as the contours
    local fw, fh = bounds_w / scale, bounds_h / scale
    local fx, fy = -(fw - thumbnail_w) * 0.5, -(fh - thumbnail_h) * 0.5

    line_width = 2.5 * rt.settings.menu.stage_preview.line_width

    bind_outline()
    love.graphics.line(
        fx, fy,
        fx + fw, fy,
        fx + fw, fy + fh,
        fx, fy + fh,
        fx, fy
    )

    bind_inside()
    love.graphics.line(
        fx, fy,
        fx + fw, fy,
        fx + fw, fy + fh,
        fx, fy + fh,
        fx, fy
    )

    self._canvas:unbind()
    love.graphics.pop()
end

--- @brief
function mn.StagePreview:draw()
    love.graphics.push("all")
    love.graphics.setBlendMode("alpha", "premultiplied")
    love.graphics.setColor(1, 1, 1, 1)
    local bounds = self:get_bounds()
    love.graphics.translate(bounds.x - self._padding, bounds.y - self._padding)
    self._canvas:draw()
    love.graphics.pop()
end

--- @brief
function mn.StagePreview:measure()
    return self._bounds.width, self._bounds.height
end

--- @brief
function mn.StagePreview:set_color(color)
    meta.assert(color, rt.RGBA)
    self._color = color
    self:reformat() -- update canvas
end