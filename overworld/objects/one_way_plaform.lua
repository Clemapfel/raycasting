require "overworld.movable_object"

rt.settings.overworld.one_way_platform = {
    thickness = 40,
    bloom_intensity = 0.5, -- fraction
    direction_light_intensity = 0.5, -- fraction
    line_width = 5,
    allow_fallthrough = false
}

--- @class ow.OneWayPlatform
--- @types Rectangle
ow.OneWayPlatform = meta.class("OneWayPlatform", ow.MovableObject)

--- @class ow.OneWayPlatformNode
ow.OneWayPlatformNode = meta.class("OneWayPlatformNode")

local _shader = rt.Shader("overworld/objects/one_way_platform.glsl")

local _current_hue_step = 1
local _hue_steps, _n_hue_steps = {}, 8
do
    for i = 0, _n_hue_steps - 1 do
        table.insert(_hue_steps, i / _n_hue_steps)
    end
    rt.random.shuffle(_hue_steps)
end

--- @brief
function ow.OneWayPlatform:instantiate(object, stage, scene)
    self._scene = scene
    self._stage = stage

    local other = object:get_object("target", true)
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

    local thickness = rt.settings.overworld.one_way_platform.thickness

    local sensor_r = 2 * rt.settings.player.radius * rt.settings.player.bubble_radius_factor
    local ldx, ldy = math.turn_left(math.normalize(dx, dy))
    local rdx, rdy = math.turn_right(math.normalize(dx, dy))

    self._sensor = b2.Body(world, body_type, centroid_x, centroid_y, b2.Polygon(
        x1 + ldx * sensor_r,
        y1 + ldy * sensor_r,
        x1,
        y1,
        x2,
        y2,
        x2 + ldx * sensor_r,
        y2 + ldy * sensor_r
    ))
    self._sensor:set_is_sensor(true)
    self._sensor:set_collides_with(rt.settings.player.bounce_collision_group)
    self._sensor:set_collision_group(rt.settings.player.bounce_collision_group)

    dx, dy = math.normalize(dx, dy)

    do -- bodies purely to stencil
        self._stencil_body = b2.Body(world, body_type, centroid_x, centroid_y, b2.Polygon(
            x1 - ldx * sensor_r,
            y1 - ldy * sensor_r,
            x1,
            y1,
            x2,
            y2,
            x2 - ldx * sensor_r,
            y2 - ldy * sensor_r
        ))

        for body in range(self._stencil_body) do
            body:set_collides_with(0x0)
        end

        self._sensor_test_active = false
        self._sensor:signal_connect("collision_start", function(_)
            self._sensor_test_active = true
            -- continuously check, since if set immediately on
            -- player entry, part of the player tail can be cut off
        end)

        self._sensor:signal_connect("collision_end", function(_)
            self._stencil_body:remove_tag("stencil")
            self._sensor_test_active = false
        end)
    end

    if rt.settings.overworld.one_way_platform.allow_fallthrough == true then
        self._sensor:signal_connect("collision_start", function(_)
            local player =  self._scene:get_player()

            -- buffered fallthrough
            if player._down_button_is_down then
                self._body:set_is_sensor(true)
            else
                player:signal_connect("duck", function(_)
                    self._body:set_is_sensor(true)
                    return meta.DISCONNECT_SIGNAL
                end)
            end
        end)

        self._sensor:signal_connect("collision_end", function(_)
            self._body:set_is_sensor(false)
        end)
    end

    self._line_draw_vertices = {
        x1, y1,
        x2, y2,
    }

    local line_width = rt.settings.overworld.one_way_platform.line_width
    local highlight_offset = 0.5 * line_width - 2
    local highlight_shorten = 2 -- px
    self._highlight_draw_vertices = {
        x1 + ldx * highlight_offset + dx * highlight_shorten,
        y1 + ldy * highlight_offset + dy * highlight_shorten,
        x2 + ldx * highlight_offset - dx * highlight_shorten,
        y2 + ldy * highlight_offset - dy * highlight_shorten,
    }

    do -- direction mesh
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
        local segments = 8 -- Number of segments per quarter circle

        -- Create vertices array
        local vertices = {}

        -- Top vertices (center line)
        table.insert(vertices, { x1, y1, 0, 0, r, r, r, alpha }) -- 1: top-left center
        table.insert(vertices, { x2, y2, 0, 0, r, r, r, alpha }) -- 2: top-right center

        -- Left quarter circle (from top-left to bottom-left)
        for i = 0, segments do
            local t = i / segments
            local angle = t * math.pi / 2 -- 0 to 90 degrees

            -- Interpolate between left_x/y (forward) and down_x/y (perpendicular)
            local offset_x = left_x * math.cos(angle) + down_x * math.sin(angle)
            local offset_y = left_y * math.cos(angle) + down_y * math.sin(angle)

            table.insert(vertices, {
                x1 + offset_x,
                y1 + offset_y,
                math.cos(angle), math.sin(angle),
                r, r, r, 0
            })
        end

        -- Right quarter circle (from top-right to bottom-right)
        for i = 0, segments do
            local t = i / segments
            local angle = t * math.pi / 2 -- 0 to 90 degrees

            -- Interpolate between right_x/y (backward) and down_x/y (perpendicular)
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

        -- Generate triangulation
        local indices = {}

        -- Fan triangulation from top-left center (vertex 1)
        local left_start = 3 -- First vertex of left quarter circle
        local left_end = left_start + segments -- Last vertex of left quarter circle

        for i = left_start, left_end - 1 do
            table.insert(indices, 1) -- top-left center
            table.insert(indices, i)
            table.insert(indices, i + 1)
        end

        -- Connect the two arcs at the bottom
        local right_start = left_end + 1 -- First vertex of right quarter circle
        local right_end = right_start + segments -- Last vertex of right quarter circle

        -- Center quad (two triangles)
        table.insert(indices, 1) -- top-left center
        table.insert(indices, left_end) -- end of left arc
        table.insert(indices, 2) -- top-right center

        table.insert(indices, left_end) -- end of left arc
        table.insert(indices, right_end) -- end of right arc
        table.insert(indices, 2) -- top-right center

        -- Bottom connection
        table.insert(indices, left_end) -- end of left arc
        table.insert(indices, right_start) -- start of right arc
        table.insert(indices, right_end) -- end of right arc

        -- Fan triangulation from top-right center (vertex 2)
        for i = right_start, right_end - 1 do
            table.insert(indices, 2) -- top-right center
            table.insert(indices, i)
            table.insert(indices, i + 1)
        end

        self._direction_mesh:set_vertex_map(indices)
    end

    self._hue = _hue_steps[_current_hue_step]
    self._color = rt.RGBA(rt.lcha_to_rgba(0.8, 1, self._hue, 1))
    _current_hue_step = _current_hue_step % _n_hue_steps + 1
end

--- @brief
function ow.OneWayPlatform:update(delta)
    if not self._sensor_test_active or not self._stage:get_is_body_visible(self._sensor) then return end

    local should_stencil = false

    -- check which side of the line the player is on
    local player =  self._scene:get_player()
    local px, py = player:get_position()
    local x1, y1, x2, y2 = table.unpack(self._line_draw_vertices)
    local side = math.cross(
        x2 - x1, y2 - y1,
        px - x1, py - y1
    )

    -- check distance to line segment
    if side >= 0 then
        local vx, vy = x2 - x1, y2 - y1

        local len = math.magnitude(vx, vy)
        local nx, ny = math.normalize(vx, vy)
        local wx, wy = px - x1, py - y1

        local t = math.dot(wx, wy, nx, ny)

        if t < 0 then t = 0 end
        if t > len then t = len end

        local cx = x1 + nx * t
        local cy = y1 + ny * t
        should_stencil = math.distance(px, py, cx, cy) > player:get_radius()
    end

    if should_stencil then
        self._stencil_body:add_tag("stencil")
    else
        self._stencil_body:remove_tag("stencil")
    end
end

--- @brief
function ow.OneWayPlatform:draw()
    if not self._stage:get_is_body_visible(self._sensor) then return end

    local offset_x, offset_y = self._body:get_position()
    love.graphics.push()
    love.graphics.translate(offset_x, offset_y)

    local x1, y1, x2, y2 = table.unpack(self._line_draw_vertices)

    local base_line_width = rt.settings.overworld.one_way_platform.line_width
    local line_width = base_line_width + 4
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
    love.graphics.circle("fill", x1, y1, line_width * 0.5)
    love.graphics.circle("fill", x2, y2, line_width * 0.5)

    love.graphics.setColor(1, 1, 1, 0.5)
    love.graphics.setLineWidth(2)
    love.graphics.line(self._highlight_draw_vertices)

    love.graphics.pop()
end

--- @brief
function ow.OneWayPlatform:draw_bloom()
    if not self._stage:get_is_body_visible(self._sensor) then return end


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
    self._sensor:set_position(x, y)
    self._stencil_body:set_position(x, y)
end

--- @brief
function ow.OneWayPlatform:set_velocity(vx, vy)
    self._body:set_velocity(vx, vy)
    self._sensor:set_velocity(vx, vy)
    self._stencil_body:set_velocity(vx, vy)
end