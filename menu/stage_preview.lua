require "common.widget"
require "common.matrix"

rt.settings.menu.stage_preview = {
    spatial_hash_cell_size = 16,
    outer_margin = 0
}

--- @class mn.StagePreview
mn.StagePreview = meta.class("StagePreview", rt.Widget)

--- @brief
function mn.StagePreview:instantiate(stage_id)
    self._config = rt.GameState:stage_get_config(stage_id)
    self._contours = {}
    self._contour_bounds = rt.AABB()
end

--- @brief
function mn.StagePreview:realize()
    -- spatial hash for all vertices
    local spatial_hash = rt.Matrix()
    local r = rt.settings.menu.stage_preview.spatial_hash_cell_size

    local function add(contour, i)
        local x, y = contour[i+0], contour[i+1]
        local hash_x, hash_y = math.floor(x / r), math.floor(y / r)

        local contour_to_indices = spatial_hash:get(hash_x, hash_y)
        if contour_to_indices == nil then
            contour_to_indices = {}
            spatial_hash:set(hash_x, hash_y, contour_to_indices)
        end

        local entry = contour_to_indices[contour]
        if entry == nil then
            entry = {}
            contour_to_indices[contour] = entry
        end

        table.insert(entry, i)
    end

    local whitelist = {}
    for type in range(
        "Hitbox",
        "SlipperyHitbox",
        "AcceleratorSurface",
        "BoostField",
        "BubbleField",
        "Wall",
        "BouncePad",
        "Bubble",
        "DeceleratorSurface",
        "Hook",
        "MovableHitbox",
        "OneWayPlatform",
        "StageThumbnail"
    ) do
        whitelist[type] = true
    end

    local before_n = 0

    local thumbnail = nil

    -- collect contours and vertices
    local candidates = {}
    for layer_i = 1, self._config:get_n_layers() do
        for wrapper in values(self._config:get_layer_object_wrappers(layer_i)) do
            local class = wrapper:get_class()
            if whitelist[wrapper:get_class()] == true then
                local contour
                if class == "StageThumbnail" then
                    if wrapper:get_type() == ow.ObjectType.RECTANGLE and wrapper.rotation == 0 then
                        thumbnail = rt.AABB(
                            wrapper.x, wrapper.y,
                            wrapper.width, wrapper.height
                        )
                    else
                        -- else, assertion raised in ow.Stage initialization
                    end
                elseif class == "OneWayPlatform" then
                    local other = wrapper:get_object("other")
                    if other ~= nil then
                        contour = {
                            wrapper.x, wrapper.y,
                            other.x, other.y
                        }
                    end
                else
                    contour = wrapper:create_contour()
                end

                if contour ~= nil then
                    for i = 1, #contour, 2 do
                        add(contour, i)
                        before_n = before_n + 2
                    end
                    table.insert(candidates, contour)
                end
            end
        end
    end

    -- get all contours overlapping thumbnail
    if thumbnail == nil then
        self._contours = candidates
    else
        self._contours = {}
        for contour in values(candidates) do
            for i = 1, #contour - 2, 2 do
                if thumbnail:intersects(
                    contour[i+0], contour[i+1],
                    contour[i+2], contour[i+3]
                ) then
                    table.insert(self._contours, contour)
                    break
                end
            end
        end
    end

    local n_removed = 0

    -- align all vertices towards center of cell, mark duplicates for removal
    local min_xi, min_yi, max_xi, max_yi = spatial_hash:get_index_range()
    local offset_x, offset_y = (min_xi + 0.5) * r, (min_yi + 0.5) * r

    do -- dedupe by proximity
        local to_remove = {}
        for xi = min_xi, max_xi do
            for yi = min_yi, max_yi do
                local contour_to_indices = spatial_hash:get(xi, yi)
                if contour_to_indices ~= nil then
                    local center_x, center_y = (xi + 0.5) * r, (yi + 0.5) * r
                    for contour, indices in pairs(contour_to_indices) do
                        table.sort(indices)

                        for index in values(indices) do
                            contour[index+0] = math.floor(contour[index+0] - offset_x)
                            contour[index+1] = math.floor(contour[index+1] - offset_y)
                        end

                        if #indices > 1 then
                            if to_remove[contour] == nil then
                                to_remove[contour] = {}
                            end

                            for i = 2, #indices do
                                local current = indices[i]
                                local previous = indices[i-1]

                                if current - previous == 2 then
                                    to_remove[contour][current] = true
                                end
                            end
                        end
                    end
                end
            end
        end

        for contour, remove_set in pairs(to_remove) do
            if #contour > 4 then
                local remove_list = {}
                for index in pairs(remove_set) do
                    table.insert(remove_list, 1, index)
                end

                for index in values(remove_list) do
                    table.remove(contour, index + 1) -- y
                    table.remove(contour, index)     -- x
                    n_removed = n_removed + 2
                end
            end
        end
    end

    do -- dedupe by collinearity
        local eps = r / 2
        local function is_collinear(x1, y1, x2, y2, x3, y3)
            local dx1 = x2 - x1
            local dy1 = y2 - y1
            local dx2 = x3 - x1
            local dy2 = y3 - y1

            local cross = math.abs(dx1 * dy2 - dy1 * dx2)
            local dist_a_sq = dx1 * dx1 + dy1 * dy1

            if dist_a_sq < eps * eps then
                local dist_b_sq = dx2 * dx2 + dy2 * dy2
                return dist_b_sq < eps * eps
            end

            return cross * cross <= eps * eps * dist_a_sq
        end

        for contour in values(self._contours) do
            if #contour > 4 then
                local removed_any = true
                while removed_any do
                    removed_any = false
                    local i = 1

                    while i <= #contour - 4 do
                        local ax, ay = contour[i+0], contour[i+1]
                        local bx, by = contour[i+2], contour[i+3]
                        local cx, cy = contour[i+4], contour[i+5]

                        if is_collinear(ax, ay, bx, by, cx, cy) then
                            table.remove(contour, i+3) -- by
                            table.remove(contour, i+2) -- bx
                            n_removed = n_removed + 2
                            removed_any = true
                        else
                            i = i + 2
                        end
                    end
                end
            end
        end
    end

    do -- remove empty contours
        local empty_contour_is = {}
        for contour_i, contour in ipairs(self._contours) do
            if #contour < 4 then
                table.insert(empty_contour_is, 1, contour_i)
            else
                rt.close_contour(contour)
            end
        end

        for contour_i in values(empty_contour_is) do
            table.remove(self._contours, contour_i)
        end
    end

    local contour_w = (max_xi - min_xi + 1) * r
    local contour_h = (max_yi - min_yi + 1) * r

    if thumbnail ~= nil then
        -- translate contours so the thumbnail's top-left corner becomes the origin
        local tx = thumbnail.x - offset_x
        local ty = thumbnail.y - offset_y

        for contour in values(self._contours) do
            for i = 1, #contour, 2 do
                contour[i+0] = contour[i+0] - tx
                contour[i+1] = contour[i+1] - ty
            end
        end

        -- clip polylines to the thumbnail rectangle [0, width] x [0, height]
        local xmin, ymin = 0, 0
        local xmax, ymax = thumbnail.width, thumbnail.height
        local eps = math.eps or 1e-6

        local function liang_barsky(x1, y1, x2, y2)
            local dx, dy = x2 - x1, y2 - y1
            local p = { -dx,  dx, -dy,  dy }
            local q = { x1 - xmin, xmax - x1, y1 - ymin, ymax - y1 }
            local u1, u2 = 0, 1

            for i = 1, 4 do
                local pi, qi = p[i], q[i]
                if pi == 0 then
                    if qi < 0 then return nil end -- parallel and outside
                else
                    local r = qi / pi
                    if pi < 0 then
                        if r > u2 then return nil end
                        if r > u1 then u1 = r end
                    else
                        if r < u1 then return nil end
                        if r < u2 then u2 = r end
                    end
                end
            end

            local cx1 = x1 + u1 * dx
            local cy1 = y1 + u1 * dy
            local cx2 = x1 + u2 * dx
            local cy2 = y1 + u2 * dy
            return cx1, cy1, cx2, cy2
        end

        local function same_point(x1, y1, x2, y2)
            return math.abs(x1 - x2) <= eps and math.abs(y1 - y2) <= eps
        end

        local clipped = {}
        for contour in values(self._contours) do
            local current = nil
            for i = 1, #contour - 2, 2 do
                local x1, y1 = contour[i+0], contour[i+1]
                local x2, y2 = contour[i+2], contour[i+3]
                local cx1, cy1, cx2, cy2 = liang_barsky(x1, y1, x2, y2)

                if cx1 ~= nil then
                    if current == nil then
                        current = { cx1, cy1, cx2, cy2 }
                    else
                        local px, py = current[#current-1], current[#current]
                        if same_point(px, py, cx1, cy1) then
                            table.insert(current, cx2)
                            table.insert(current, cy2)
                        else
                            if #current >= 4 then
                                table.insert(clipped, current)
                            end
                            current = { cx1, cy1, cx2, cy2 }
                        end
                    end
                end
            end

            if current ~= nil and #current >= 4 then
                table.insert(clipped, current)
            end
        end

        -- remove degenerate results
        local out = {}
        for contour in values(clipped) do
            if #contour >= 4 then
                table.insert(out, contour)
            end
        end

        self._contours = out
        self._contour_bounds = rt.AABB(0, 0, thumbnail.width, thumbnail.height)
    else
        self._contour_bounds = rt.AABB(
            0, 0,
            contour_w, contour_h
        )
    end
end

--- @brief
function mn.StagePreview:draw()
    love.graphics.setColor(1, 1, 1, 1)
    love.graphics.push("all")

    local m = rt.settings.menu.stage_preview.outer_margin

    local bounds_x = self._bounds.x + m
    local bounds_y = self._bounds.y + m
    local bounds_w = self._bounds.width - 2 * m
    local bounds_h = self._bounds.height - 2 * m
    local contour_w = self._contour_bounds.width
    local contour_h = self._contour_bounds.height

    local scale = math.min(bounds_w / contour_w, bounds_h / contour_h)
    local scaled_w, scaled_h = contour_w * scale, contour_h * scale

    love.graphics.translate(
        bounds_x + (bounds_w - scaled_w) * 0.5,
        bounds_y + (bounds_h - scaled_h) * 0.5
    )
    love.graphics.scale(scale, scale)

    love.graphics.setLineWidth(1)
    love.graphics.setLineJoin("none")
    love.graphics.setLineStyle("smooth")

    love.graphics.rectangle("line", self._bounds:unpack())

    for contour in values(self._contours) do
        love.graphics.line(contour)
    end

    love.graphics.pop()

    self:draw_bounds()
end

--- @brief
function mn.StagePreview:measure()
    return self._bounds.width, self._bounds.height
end