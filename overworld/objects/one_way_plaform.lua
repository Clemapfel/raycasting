require "overworld.movable_object"

rt.settings.overworld.one_way_platform = {
    thickness = 40,
    bloom_intensity = 0.5, -- fraction
    direction_light_intensity = 0.5, -- fraction
    line_width = 5,
    outline_width_increase = 4,
    allow_fallthrough = false
}

--- @class ow.OneWayPlatform
--- @types Rectangle
ow.OneWayPlatform = meta.class("OneWayPlatform", ow.MovableObject)

--- @class ow.OneWayPlatformNode
ow.OneWayPlatformNode = meta.class("OneWayPlatformNode")

local _shader = rt.Shader("overworld/objects/one_way_platform.glsl")
local _n_hue_steps = 13

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

    local dx, dy = x2 - x1, y2 - y1

    local line_angle = math.angle(dx, dy)
    self._arc_angle_left_start = line_angle + math.pi / 2
    self._arc_angle_left_end = line_angle + 3 * math.pi / 2
    self._arc_angle_right_start = line_angle - math.pi / 2
    self._arc_angle_right_end = line_angle + math.pi / 2

    local segment_thickness = 2
    local shape = b2.Segment(x1, y1, x2, y2)
    shape:set_is_one_sided(true)

    self._original_x, self._original_y = x1, y1
    local body_type = object:get_physics_body_type()

    local world = stage:get_physics_world()
    self._body = b2.Body(world, body_type, centroid_x, centroid_y, shape)
    self._body:add_tag("stencil", "hitbox")
    self._body:add_tag("segment_light_source")
    self._body:set_user_data(self)
    self._body:set_use_continuous_collision(true)
    self._body:set_collides_with(rt.settings.player.player_outer_body_collision_group)

    local settings = rt.settings.overworld.one_way_platform
    local thickness = settings.thickness

    local stencil_r = (settings.line_width + settings.outline_width_increase) * 0.5
    local ldx, ldy = math.turn_left(math.normalize(dx, dy))
    local rdx, rdy = math.turn_right(math.normalize(dx, dy))

    dx, dy = math.normalize(dx, dy)
    self._stencil_body = b2.Body(world, body_type, centroid_x, centroid_y, b2.Polygon(
        x1 + ldx * stencil_r,
        y1 + ldy * stencil_r,
        x2 - rdx * stencil_r,
        y2 - rdy * stencil_r,
        x2 - ldx * stencil_r,
        y2 - ldy * stencil_r,
        x1 + rdx * stencil_r,
        y1 + rdy * stencil_r
    ))

    self._stencil_body:set_collides_with(0x0)
    self._stencil_body:set_collision_group(0x0)

    self._stencil_body:add_tag("stencil")

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
    return { vertices }, { { self._color:unpack() } }
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