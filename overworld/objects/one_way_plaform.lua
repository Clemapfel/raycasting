require "overworld.movable_object"

rt.settings.overworld.one_way_platform = {
    mesh_thickness = 40,
    bloom_intensity = 0.5, -- fraction
    direction_light_intensity = 0.5, -- fraction
    line_width = 3,
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

    self._has_end_cap = object:get_boolean("has_end_cap", false)
    if self._has_end_cap == nil then self._has_end_cap = true end

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

    -- add wide solid body on opposite site to prevent tunneling at high velocities
    self._update_range = rt.settings.player.max_velocity * rt.SceneManager:get_timestep() * 4

    local protection_r = self._update_range
    local protection_offset = stencil_r -- so raycasting still hits segment instead of protection body

    local protection_shape
    if self._sidedness == 1 then
        protection_shape = b2.Polygon(
            x1 + left_dx * protection_offset, y1 + left_dy * protection_offset,
            x2 + left_dx * protection_offset, y2 + left_dy * protection_offset,
            x2 + left_dx * protection_r, y2 + left_dy * protection_r,
            x1 + left_dx * protection_r, y1 + left_dy * protection_r
        )
    else
        protection_shape = b2.Polygon(
            x1 + right_dx * protection_offset, y1 + right_dy * protection_offset,
            x2 + right_dx * protection_offset, y2 + right_dy * protection_offset,
            x2 + right_dx * protection_r, y2 + right_dy * protection_r,
            x1 + right_dx * protection_r, y1 + right_dy * protection_r
        )
    end

    self._velocity_protection_body = b2.Body(world, body_type, centroid_x, centroid_y, protection_shape)
    self._velocity_protection_body:set_is_sensor(true)

    -- graphic

    self._line_draw_vertices = {
        x1, y1,
        x2, y2,
    }

    local line_angle = math.angle(dx, dy)
    self._arc_angle_left_start = line_angle + math.pi / 2
    self._arc_angle_left_end = line_angle + 3 * math.pi / 2
    self._arc_angle_right_start = line_angle - math.pi / 2
    self._arc_angle_right_end = line_angle + math.pi / 2

    local line_width = rt.settings.overworld.one_way_platform.line_width
    local highlight_offset = 0.5 * line_width - 2
    local highlight_shorten = 2 -- px
    local highlight_dx, highlight_dy = math.turn_left(dx, dy)

    if self._has_end_cap then
        self._highlight_draw_vertices = {
            x1 + highlight_dx * highlight_offset + dx * highlight_shorten,
            y1 + highlight_dy * highlight_offset + dy * highlight_shorten,
            x2 + highlight_dx * highlight_offset - dx * highlight_shorten,
            y2 + highlight_dy * highlight_offset - dy * highlight_shorten,
        }
    else
        self._highlight_draw_vertices = {
            x1, y1, x2, y2
        }
    end

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

    self._hue = object:get_number("hue", false)
    if self._hue == nil then
        self._hue = math.fract(meta.hash(self) % _n_hue_steps / _n_hue_steps)
    end

    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    stage.one_way_platform_current_hue_step = stage.one_way_platform_current_hue_step % _n_hue_steps + 1
end

--- @param r Number buffer to add to the end of each line, only affects is_on_segment
--- @return Number, Number, Boolean
local function _closest_point_on_segment(px, py, ax, ay, bx, by, r)
    local abx = bx - ax
    local aby = by - ay
    local apx = px - ax
    local apy = py - ay
    local ab_length_sq = math.dot(abx, aby, abx, aby)
    local t = math.dot(apx, apy, abx, aby) / ab_length_sq

    local ab_length = math.sqrt(ab_length_sq)
    local t_buffer = r / ab_length

    local is_on_segment = t >= -t_buffer and t <= 1.0 + t_buffer
    t = math.clamp(t, 0.0, 1.0)
    return ax + t * abx, ay + t * aby, is_on_segment
end

--- @brief
function ow.OneWayPlatform:update(delta)
    if not self._stage:get_is_body_visible(self._body) then return end

    local offset_x, offset_y = self._body:get_position()
    local cx1, cy1 = math.add(self._x1, self._y1, offset_x, offset_y)
    local cx2, cy2 = math.add(self._x2, self._y2, offset_x, offset_y)
    local player = self._scene:get_player()
    local player_r = player:get_radius()

    -- early check: segment in rangec
    local px, py = player:get_position()
    local closest_x, closest_y, is_on_segment = _closest_point_on_segment(px, py, cx1, cy1, cx2, cy2, -0.5 * player_r)

    -- use closets point on player circle instead of center
    local dx, dy = math.normalize(closest_x - px, closest_y - py)
    px, py = px + dx * player_r, py + dy * player_r

    local segment_distance = math.distance(closest_x, closest_y, px, py)
    if segment_distance < self._update_range then
        px, py = player:get_centroid() -- compute more exact position as average of all player bodies
        local player_side = _get_side(px, py, cx1, cy1, cx2, cy2)

        self._body:set_is_sensor(not (player_side == self._sidedness))
        self._velocity_protection_body:set_is_sensor(not (player_side == self._sidedness and is_on_segment))
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

    if self._has_end_cap == true then
        love.graphics.circle("fill", x1, y1, line_width * 0.5)
        love.graphics.circle("fill", x2, y2, line_width * 0.5)
    end

    line_width = base_line_width
    love.graphics.setLineWidth(line_width)
    self._color:bind()

    _shader:bind()
    self._direction_mesh:draw()
    _shader:unbind()

    love.graphics.line(self._line_draw_vertices)

    if self._has_end_cap == true then
        love.graphics.arc("fill", x1, y1, line_width * 0.5, self._arc_angle_left_start, self._arc_angle_left_end)
        love.graphics.arc("fill", x2, y2, line_width * 0.5, self._arc_angle_right_start, self._arc_angle_right_end)
    end

    local highlight_line_width = 2
    local highlight_x1, highlight_y1, highlight_x2, highlight_y2 = table.unpack(self._highlight_draw_vertices)
    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(highlight_line_width)
    love.graphics.line(highlight_x1, highlight_y1, highlight_x2, highlight_y2)

    if self._has_end_cap == true then
        love.graphics.arc("fill", highlight_x1, highlight_y1, 0.5 * highlight_line_width, self._arc_angle_left_start, self._arc_angle_left_end)
        love.graphics.arc("fill", highlight_x2, highlight_y2, 0.5 * highlight_line_width, self._arc_angle_right_start, self._arc_angle_right_end)
    end

    love.graphics.pop()
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
    for body in range(
        self._body,
        self._velocity_protection_body,
        self._stencil_body
    ) do
        body:set_position(x, y)
    end
end

--- @brief
function ow.OneWayPlatform:set_velocity(vx, vy)
    for body in range(
        self._body,
        self._velocity_protection_body,
        self._stencil_body
    ) do
        body:set_velocity(vx, vy)
    end
end