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
        scene, ow.OverworldScene,
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
function ow.Mirror:initialize(mirror_contours)
    meta.assert(mirror_contours, mt.Table)

    local entries = {}
    for _, contour in ipairs(mirror_contours) do
        table.insert(entries, {
            contour = contour,
            is_dynamic = false
        })
    end

    self._query:initialize(entries)
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

    local angle = math.angle(dx, dy)
    local distance = math.abs(projection)

    return reflected_x, reflected_y, angle, distance
end

--- @brief
function ow.Mirror:update(_)
    if rt.GameState:get_are_reflections_enabled() == false then return end

    local camera = self._scene:get_camera()
    local bounds = camera:get_world_bounds()

    -- find segments near player
    local px, py = self._scene:get_player():get_physics_body():get_position()
    local search_r = math.max(400, 4 * rt.settings.player.radius * rt.settings.player.bottom_wall_ray_length_factor)

    px = px - self._offset_x
    py = py - self._offset_y

    self._visible = {}
    for data in values(self._query:get_visible_subsegments(
        px, py,
        rt.AABB(
            px - search_r,
            py - search_r,
            2 * search_r
        ),
        false -- not visibility polygon
    )) do
        table.insert(self._visible, data.subsegment)
    end

    self._mirror_images = {}
    for segment in values(self._visible) do
        local rx, ry, angle, distance = _reflect(
            px, py, table.unpack(segment)
        )

        table.insert(self._mirror_images, {
            segment = segment,
            x = rx,
            y = ry,
            angle = angle,
            distance = distance
        })
    end

    table.sort(self._mirror_images, function(a, b)
        return a.distance < b.distance
    end)
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
    love.graphics.translate(self._offset_x, self._offset_y)

    -- stencil mirror areas
    rt.graphics.set_stencil_mode(stencil_value, rt.StencilMode.DRAW)
    self._draw_mirror_mask_callback()

    if self._draw_occluding_mask_callback ~= nil then
        love.graphics.setStencilState("replace", "always", 0)
        love.graphics.setColorMask(false)

        -- exclude occluding that overlap mirror mask
        self._draw_occluding_mask_callback()
    end

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
            image.x,
            image.y,
            2 * image.angle, -- double rotation = flip
            1 / scale_x,
            -1 / scale_y, -- flip y
            0.5 * canvas_w,
            0.5 * canvas_h
        )

        n_drawn = n_drawn + 1
        if n_drawn >= rt.settings.overworld.mirror.max_n_mirror_segments then
            break
        end
    end
    _shader:unbind()

    rt.graphics.set_stencil_mode(nil)
    love.graphics.pop()
end

--- @brief
function ow.Mirror:set_offset(x, y)
    self._offset_x, self._offset_y = x, y
end

--- @brief
function ow.Mirror:get_offset()
    return self._offset_x, self._offset_y
end
