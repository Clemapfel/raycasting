require "overworld.movable_object"

rt.settings.overworld.one_way_platform = {
    mesh_thickness = 40,
    update_range = 100,
    bloom_intensity = 0.5, -- fraction
    direction_light_intensity = 0.5, -- fraction
    line_width = 5,
    outline_width_increase = 4,
    allow_fallthrough = false,

    segment_thickness = 1 -- px
}

--- @class ow.OneWayPlatform
--- @types Rectangle
ow.OneWayPlatform = meta.class("OneWayPlatform", ow.MovableObject)

--- @class ow.OneWayPlatformNode
ow.OneWayPlatformNode = meta.class("OneWayPlatformNode")

local _shader = rt.Shader("overworld/objects/one_way_platform.glsl")
local _n_hue_steps = 13

-- which side of infinite line a point is one
local function _get_side(px, py, x1, y1, x2, y2)
    return math.sign(math.cross(
        x2 - x1,
        y2 - y1,
        px - x1,
        py - y1
    ))
end

--- @brief
function ow.OneWayPlatform:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    if stage.one_way_platform_current_hue_step == nil then
        stage.one_way_platform_current_hue_step = 1
    end

    local other = object:get_object("other", true)
    for x in range(object, other) do
        if not x:get_type() == ow.ObjectType.POINT then
            rt.error("In ow.OneWayPlatform: object `", x:get_id(), "` is not a point")
        end
    end

    local x1, y1 = object.x, object.y
    local x2, y2 = other.x, other.y
    local centroid_x, centroid_y = math.mix2(x1, y1, x2, y2, 0.5)

    x1 = x1 - centroid_x
    y1 = y1 - centroid_y
    x2 = x2 - centroid_x
    y2 = y2 - centroid_y

    self._x1, self._y1, self._x2, self._y2 = x1, y1, x2, y2

    local dx, dy = math.normalize(x2 - x1, y2 - y1)
    local left_dx, left_dy = math.turn_left(dx, dy)
    local right_dx, right_dy = math.turn_right(dx, dy)

    local line_angle = math.angle(dx, dy)
    self._arc_angle_left_start = line_angle + math.pi / 2
    self._arc_angle_left_end = line_angle + 3 * math.pi / 2
    self._arc_angle_right_start = line_angle - math.pi / 2
    self._arc_angle_right_end = line_angle + math.pi / 2

    self._original_x, self._original_y = x1, y1
    local body_type = object:get_physics_body_type()

    local world = stage:get_physics_world()

    local segment_r = 3 --rt.settings.overworld.one_way_platform.segment_thickness
    local body_shape = b2.Polygon(
        x1 + left_dx  * segment_r,
        y1 + left_dy  * segment_r,
        x2 - right_dx * segment_r,
        y2 - right_dy * segment_r,
        x2 - left_dx  * segment_r,
        y2 - left_dy  * segment_r,
        x1 + right_dx * segment_r,
        y1 + right_dy * segment_r
    )

    body_shape = b2.Segment(x1, y1, x2, y2)
    body_shape:set_is_one_sided(true)

    self._body = b2.Body(world, body_type, centroid_x, centroid_y, body_shape)
    self._body:add_tag("stencil", "hitbox")
    self._body:add_tag("segment_light_source")
    self._body:set_user_data(self)
    self._body:set_use_continuous_collision(true)

    self._body:set_collides_with(rt.settings.player.player_outer_body_collision_group)
    -- sic, not center body

    -- detect point order by using point offset by normal
    self._sidedness = _get_side(
        math.mix(x1, x2, 0.5) + left_dx * 1,
        math.mix(y1, y2, 0.5) + left_dy * 1,
        x1, y1, x2, y2
    )

    local settings = rt.settings.overworld.one_way_platform
    local thickness = settings.mesh_thickness

    local stencil_r = (settings.line_width + settings.outline_width_increase) * 0.5
    self._stencil_body = b2.Body(world, body_type, centroid_x, centroid_y, b2.Polygon(
        x1 + left_dx * stencil_r,
        y1 + left_dy * stencil_r,
        x2 - right_dx * stencil_r,
        y2 - right_dy * stencil_r,
        x2 - left_dx * stencil_r,
        y2 - left_dy * stencil_r,
        x1 + right_dx * stencil_r,
        y1 + right_dy * stencil_r
    ))

    self._stencil_body:set_collides_with(0x0)
    self._stencil_body:set_collision_group(0x0)
    self._stencil_body:add_tag("stencil")

    local protection_r = 100
    local protection_shape
    if self._sidedness == 1 then
        protection_shape = b2.Polygon(
            x1, y1,
            x2, y2,
            x2 + left_dx * protection_r, y2 + left_dy * protection_r,
            x1 + left_dx * protection_r, y1 + left_dy * protection_r
        )
    else
        protection_shape = b2.Polygon(
            x1, y1,
            x2, y2,
            x2 + right_dx * protection_r, y2 + right_dy * protection_r,
            x1 + right_dx * protection_r, y1 + right_dy * protection_r
        )
    end

    self._velocity_protection_body = b2.Body(world, body_type, centroid_x, centroid_y, protection_shape)
    self._velocity_protection_body:set_is_sensor(true)

    do -- precompute args for velocity body query in update
        local center_x = (x1 + x2) * 0.5
        local center_y = (y1 + y2) * 0.5

        local edge_x = x2 - x1
        local edge_y = y2 - y1

        local width = math.magnitude(edge_x, edge_y)
        local height = protection_r

        local cos_a = edge_x / width
        local sin_a = edge_y / width

        if self._sidedness == 1 then
            center_x = center_x + left_dx * protection_r * 0.5
            center_y = center_y + left_dy * protection_r * 0.5
        else
            center_x = center_x + right_dx * protection_r * 0.5
            center_y = center_y + right_dy * protection_r * 0.5
        end

        self._velocity_protection_bounds = { center_x, center_y, width, height, cos_a, sin_a }
    end

    -- graphics
    self._line_draw_vertices = {
        x1, y1,
        x2, y2,
    }

    local line_width = rt.settings.overworld.one_way_platform.line_width
    local highlight_offset = 0.5 * line_width - 2
    local highlight_shorten = 2 -- px
    local highlight_dx, highlight_dy = 0, -1
    self._highlight_draw_vertices = {
        x1 + highlight_dx * highlight_offset + dx * highlight_shorten,
        y1 + highlight_dy * highlight_offset + dy * highlight_shorten,
        x2 + highlight_dx * highlight_offset - dx * highlight_shorten,
        y2 + highlight_dy * highlight_offset - dy * highlight_shorten,
    }

    do -- direction mesh, center quad with two quarter circles on both sides
        local width = 1 * thickness
        local down_x, down_y = math.turn_right(math.normalize(dx, dy))
        down_x = down_x * width
        down_y = down_y * width

        dx, dy = math.normalize(dx, dy)

        local overshoot = 10
        local left_x, left_y = -dx * overshoot, -dy * overshoot
        local right_x, right_y = dx * overshoot, dy * overshoot

        x1 = x1 + right_x / 2
        y1 = y1 + right_y / 2
        x2 = x2 + left_x / 2
        y2 = y2 + left_y / 2

        local r, alpha = 1, rt.settings.overworld.one_way_platform.direction_light_intensity
        local segments = 8

        local vertices = {}

        table.insert(vertices, { x1, y1, 0, 0, r, r, r, alpha })
        table.insert(vertices, { x2, y2, 0, 0, r, r, r, alpha })

        -- left quarter circle
        for i = 0, segments do
            local t = i / segments
            local angle = t * math.pi / 2

            local offset_x = left_x * math.cos(angle) + down_x * math.sin(angle)
            local offset_y = left_y * math.cos(angle) + down_y * math.sin(angle)

            table.insert(vertices, {
                x1 + offset_x,
                y1 + offset_y,
                math.cos(angle), math.sin(angle),
                r, r, r, 0
            })
        end

        -- right quarter circle
        for i = 0, segments do
            local t = i / segments
            local angle = t * math.pi / 2

            local offset_x = right_x * math.cos(angle) + down_x * math.sin(angle)
            local offset_y = right_y * math.cos(angle) + down_y * math.sin(angle)

            table.insert(vertices, {
                x2 + offset_x,
                y2 + offset_y,
                math.cos(angle), math.sin(angle),
                r, r, r, 0
            })
        end

        self._direction_mesh = rt.Mesh(vertices, rt.MeshDrawMode.TRIANGLES)

        -- triangulate
        local indices = {}
        local left_start = 3
        local left_end = left_start + segments

        local right_start = left_end + 1
        local right_end = right_start + segments

        for i = left_start, left_end - 1 do
            table.insert(indices, 1)
            table.insert(indices, i)
            table.insert(indices, i + 1)
        end

        table.insert(indices, 1)
        table.insert(indices, left_end)
        table.insert(indices, 2)

        table.insert(indices, left_end)
        table.insert(indices, right_end)
        table.insert(indices, 2)

        table.insert(indices, left_end)
        table.insert(indices, right_start)
        table.insert(indices, right_end)

        for i = right_start, right_end - 1 do
            table.insert(indices, 2)
            table.insert(indices, i)
            table.insert(indices, i + 1)
        end

        self._direction_mesh:set_vertex_map(indices)
    end

    self._hue = object:get_number("hue")
    if self._hue == nil then
        self._hue = math.fract(stage.one_way_platform_current_hue_step / _n_hue_steps)
    end

    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    stage.one_way_platform_current_hue_step = stage.one_way_platform_current_hue_step % _n_hue_steps + 1
end

local function _closest_point_on_segment(px, py, ax, ay, bx, by)
    local abx = bx - ax
    local aby = by - ay
    local t = math.dot(px - ax, py - ay, abx, aby) / math.dot(abx, aby, abx, aby)
    t = math.clamp(t, 0.0, 1.0)
    return ax + t * abx, ay + t * aby
end

-- Corrected: returns world-space closest point on oriented rectangle
-- Arguments should be precomputed once in instantiate and passed as a tuple:
--   (rect_center_x, rect_center_y, rect_w, rect_h, cos_a, sin_a)
local function _closest_point_on_rectangle(px, py, rect_center_x, rect_center_y, rect_w, rect_h, cos_a, sin_a)
    local dx = px - rect_center_x
    local dy = py - rect_center_y

    local local_x = dx * cos_a + dy * sin_a
    local local_y = -dx * sin_a + dy * cos_a

    local half_w = rect_w * 0.5
    local half_h = rect_h * 0.5

    local clamped_x = math.clamp(local_x, -half_w, half_w)
    local clamped_y = math.clamp(local_y, -half_h, half_h)

    local world_x = rect_center_x + clamped_x * cos_a - clamped_y * sin_a
    local world_y = rect_center_y + clamped_x * sin_a + clamped_y * cos_a

    return world_x, world_y
end

--- @brief
function ow.OneWayPlatform:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    local cx1, cy1 = math.add(self._x1, self._y1, offset_x, offset_y)
    local cx2, cy2 = math.add(self._x2, self._y2, offset_x, offset_y)
    local player = self._scene:get_player()
    local player_r = player:get_radius()

    local player_side, segment_distance

    do -- check if segment should be sensor
        -- early check: segment in range
        local px, py = player:get_position()
        local closest_x, closest_y = _closest_point_on_segment(px, py, cx1, cy1, cx2, cy2)

        -- use closets point on player circle instead of center
        local dx, dy = math.normalize(closest_x - px, closest_y - py)
        px, py = px + dx * player_r, py + dy * player_r

        segment_distance = math.distance(closest_x, closest_y, px, py)
        if segment_distance < rt.settings.overworld.one_way_platform.update_range then
            -- compute more exact position as average of all player bodies
            px, py = self._scene:get_player():get_centroid()
            player_side = _get_side(px, py, cx1, cy1, cx2, cy2)
            self._body:set_is_sensor(player_side ~= self._sidedness)
        end
    end

    do -- check if velocity protection should be enabled
        local px, py = player:get_position()
        if player_side == nil then
            player_side = _get_side(px, py, cx1, cy1, cx2, cy2)
        end

        local should_be_enabled = player_side == self._sidedness and segment_distance > 2 * player_r
        if false then --should_be_enabled then
            -- get closest point
            local center_x, center_y, w, h, cos_a, sin_a = table.unpack(self._velocity_protection_bounds)
            center_x = center_x + offset_x
            center_y = center_y + offset_y

            local closest_x, closest_y = _closest_point_on_rectangle(
                px, py, center_x, center_y, w, h, cos_a, sin_a
            )

            -- use distance between player circle, not center of player
            local vx, vy = closest_x - px, closest_y - py
            local dx, dy = math.normalize(vx, vy)
            px, py = px + dx * player_r, py + dy * player_r

            -- if too close, disable
            should_be_enabled = math.distance(px, py, closest_x, closest_y) > 2 * player_r -- 4r insted of 2 to be safe
        end

        self._velocity_protection_body:set_is_sensor(not should_be_enabled)
    end
end

--- @brief
function ow.OneWayPlatform:draw()
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)

    local x1, y1, x2, y2 = table.unpack(self._line_draw_vertices)

    local base_line_width = rt.settings.overworld.one_way_platform.line_width
    local line_width = base_line_width + rt.settings.overworld.one_way_platform.outline_width_increase
    love.graphics.setLineWidth(line_width)
    rt.Palette.BLACK:bind()
    love.graphics.line(self._line_draw_vertices)
    love.graphics.circle("fill", x1, y1, line_width * 0.5)
    love.graphics.circle("fill", x2, y2, line_width * 0.5)

    line_width = base_line_width
    love.graphics.setLineWidth(line_width)
    self._color:bind()

    _shader:bind()
    self._direction_mesh:draw()
    _shader:unbind()

    love.graphics.line(self._line_draw_vertices)
    love.graphics.arc("fill", x1, y1, line_width * 0.5, self._arc_angle_left_start, self._arc_angle_left_end)
    love.graphics.arc("fill", x2, y2, line_width * 0.5, self._arc_angle_right_start, self._arc_angle_right_end)

    local highlight_line_width = 2
    local highlight_x1, highlight_y1, highlight_x2, highlight_y2 = table.unpack(self._highlight_draw_vertices)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(highlight_line_width)
    love.graphics.line(highlight_x1, highlight_y1, highlight_x2, highlight_y2)
    love.graphics.arc("fill", highlight_x1, highlight_y1, 0.5 * highlight_line_width, self._arc_angle_left_start, self._arc_angle_left_end)
    love.graphics.arc("fill", highlight_x2, highlight_y2, 0.5 * highlight_line_width, self._arc_angle_right_start, self._arc_angle_right_end)

    love.graphics.pop()

    if self._velocity_protection_body:get_is_sensor() ~= true then
        self._velocity_protection_body:draw()
    end

    if self._dbg ~= nil then
        love.graphics.circle("fill", self._dbg[1], self._dbg[2], 10)
    end
end

--- @brief
function ow.OneWayPlatform:draw_bloom()
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)

    self._color:bind()
    _shader:bind()
    self._direction_mesh:draw()
    _shader:unbind()

    love.graphics.pop()
end

--- @brief
function ow.OneWayPlatform:get_segment_light_sources()
    local vertices = table.deepcopy(self._line_draw_vertices)
    local offset_x, offset_y = self._body:get_position()
    for i = 1, #vertices, 2 do
        vertices[i+0] = vertices[i+0] + offset_x
        vertices[i+1] = vertices[i+1] + offset_y
    end
    return { vertices }, { self._color }
end

--- @brief
function ow.OneWayPlatform:set_position(x, y)
    self._body:set_position(x, y)
    self._stencil_body:set_position(x, y)
end

--- @brief
function ow.OneWayPlatform:set_velocity(vx, vy)
    self._body:set_velocity(vx, vy)
    self._stencil_body:set_velocity(vx, vy)
end