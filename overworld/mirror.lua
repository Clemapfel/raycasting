require "overworld.visibility_query"

rt.settings.overworld.mirror = {
    distance_threshold = math.huge,
    player_attenuation_radius = 0.25, -- fraction of screen size
    segment_detection_radius_factor = 3, -- time player radius
    max_n_mirror_segments = 8
}

--- @class ow.Mirror
ow.Mirror = meta.class("Mirror")

local _shader = rt.Shader("overworld/mirror.glsl")
local _noop = function() end

--- @brief
function ow.Mirror:instantiate(
    scene,
    draw_mirror_mask_callback,
    draw_occluding_mask_callback -- optional
)
    meta.assert(
        scene, "OverworldScene",
        draw_mirror_mask_callback, mt.Function
    )

    if draw_occluding_mask_callback == nil then draw_occluding_mask_callback = _noop end

    meta.install(self, {
        _scene = scene,
        _query = ow.VisibilityQuery(),
        _draw_mirror_mask_callback = draw_mirror_mask_callback,
        _draw_occluding_mask_callback = draw_occluding_mask_callback,
        _offset_x = 0,
        _offset_y = 0
    })
end

--- @brief
function ow.Mirror:draw()
    if rt.GameState:get_are_reflections_enabled() == false then return end

    if self._mirror_images == nil
        or #self._mirror_images == 0
        or self._scene:get_player():get_is_ghost()
    then return end

    local canvas, scale_x, scale_y = self._scene:get_player_canvas()

    local stencil_value = rt.graphics.get_stencil_value()

    love.graphics.push("all")

    -- stencil mirror areas
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)

    love.graphics.push("all")
    love.graphics.translate(self._offset_x, self._offset_y)

    self._draw_mirror_mask_callback()

    if self._draw_occluding_mask_callback ~= nil then
        love.graphics.setStencilState("replace", "always", 0)
        love.graphics.setColorMask(false)

        -- exclude occluding
        self._draw_occluding_mask_callback()
    end

    love.graphics.pop()

    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.TEST, rt.StencilCompareMode.EQUAL)

    -- draw canvases
    if scale_x == nil then scale_x = 1 end
    if scale_y == nil then scale_y = 1 end

    local canvas_w, canvas_h = canvas:get_size()

    local camera = self._scene:get_camera()
    local player = self._scene:get_player()
    local player_opacity = ternary(player:get_is_visible(), 1, 0)

    _shader:bind()
    _shader:send("player_color", { player:get_color():unpack() })
    _shader:send("player_position", { camera:world_xy_to_screen_xy(player:get_position()) })
    _shader:send("camera_scale", camera:get_final_scale())

    local n_drawn = 0

    for image in values(self._mirror_images) do
        local flip_x, flip_y
        if image.flip_x == true then flip_x = -1 else flip_x = 1 end
        if image.flip_y == true then flip_y = -1 else flip_y = 1 end

        local x1, y1, x2, y2 = table.unpack(image.segment)
        x1 = x1 + self._offset_x
        y1 = y1 + self._offset_y
        x2 = x2 + self._offset_x
        y2 = y2 + self._offset_y

        local lx1, ly1 = camera:world_xy_to_screen_xy(x1, y1)
        local lx2, ly2 = camera:world_xy_to_screen_xy(x2, y2)

        _shader:send("axis_of_reflection", { lx1, ly1, lx2, ly2 })

        love.graphics.setColor(1, 1, 1, 1)
        love.graphics.draw(
            canvas:get_native(),
            image.x + self._offset_x, image.y + self._offset_y,
            image.angle,
            flip_x / scale_x,
            flip_y / scale_y,
            0.5 * canvas_w, 0.5 * canvas_h
        )

        n_drawn = n_drawn + 1
        if n_drawn >= rt.settings.overworld.mirror.max_n_mirror_segments then
            -- safety check for degenerate geometry
            -- segment priority is distance to player
            break
        end
    end
    _shader:unbind()

    love.graphics.pop()
end

--- @brief
function ow.Mirror:initialize(mirror_contours, occluding_contours)
    meta.assert(mirror_contours, mt.Table, occluding_contours, mt.Table)
    self._query:initialize(
        occluding_contours, -- sic, swapped, non-reflective
        mirror_contours    -- reflective
    )
end

-- flip across line defined by line segment
local function _reflect(px, py, x1, y1, x2, y2)
    local dx = x2 - x1
    local dy = y2 - y1
    local ux, uy = math.normalize(dx, dy)
    local normal_x, normal_y = math.turn_left(ux, uy)

    local to_point_x, to_point_y = px - x1, py - y1

    local projection = math.dot(to_point_x, to_point_y, normal_x, normal_y)

    local reflected_x = px - 2 * projection * normal_x
    local reflected_y = py - 2 * projection * normal_y

    local flip_x = math.abs(math.dot(ux, uy, 1, 0)) < math.abs(math.dot(ux, uy, 0, 1))
    local flip_y = not flip_x

    local distance = math.abs(projection)

    return reflected_x, reflected_y, flip_x, flip_y, distance
end

--- @brief
function ow.Mirror:update(delta)
    if rt.GameState:get_are_reflections_enabled() == false then return end

    local camera = self._scene:get_camera()
    local bounds = camera:get_world_bounds()

    -- find segments near player
    local px, py = self._scene:get_player():get_physics_body():get_position()
    local r = 8 * rt.settings.overworld.mirror.segment_detection_radius_factor * rt.settings.player.radius

    self._visible = {}
    for data in values(self._query:get_visible_subsegments(
        px - self._offset_x,
        py - self._offset_y,
        rt.AABB(
            px - self._offset_x - r,
            py - self._offset_y - r,
            2 * r
        )
    )) do
        if data.type == ow.ContourType.REFLECTIVE then
            table.insert(self._visible, data.segment)
        end
    end

    self._mirror_images = {}
    for segment in values(self._visible) do
        local rx, ry, flip_x, flip_y, distance = _reflect(px - self._offset_x, py - self._offset_y, table.unpack(segment))
        table.insert(self._mirror_images, {
            segment = segment,
            x = rx,
            y = ry,
            flip_x = flip_x,
            flip_y = flip_y,
            distance = distance
        })
    end

    table.sort(self._mirror_images, function(a, b)
        return a.distance < b.distance
    end)
end

--- @brief
function ow.Mirror:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end

--- @brief
function ow.Mirror:get_offset()
    return self._offset_x, self._offset_y
end
